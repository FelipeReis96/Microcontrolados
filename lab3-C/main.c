
//
// MAQUINA DE ESTADOS (mesma do Lab 3 / DET):
//   INIT   --(auto)-->  VOLTAS    zera posicao, pede o numero de voltas
//   VOLTAS --'#'(1..10)-> VELOC   digitos 0-9 montam o valor; '#' confirma
//   VELOC  --'1'/'2'--->  SENTIDO 1 = passo completo, 2 = meio passo
//   SENTIDO--'1'/'2'--->  GIRANDO 1 = horario, 2 = anti-horario (dispara motor)
//   GIRANDO--passos=0-->  FIM        (Timer0A_Task)
//   GIRANDO--USR_SW1-->   CANCELADO  (GPIOPortJ_Handler)
//   */FIM/CANCELADO/VOLTAS/VELOC/SENTIDO --'*'--> INIT

#include <stdint.h>
#include "tm4c1294ncpdt.h"
#include "gpio.h"
#include "timer.h"


enum {
    ST_INIT = 0,
    ST_VOLTAS,
    ST_VELOC,
    ST_SENTIDO,
    ST_GIRANDO,
    ST_FIM,
    ST_CANCEL
};

#define TECLA_NENHUMA   0xFFu
#define STEP_MS         2u          // periodo entre passos -> 500 passos/s


extern void     SysTick_Init(void);         // base de 1 ms + CPSIE I
extern void     Delay_ms(uint32_t ms);

extern void     LCD_Init(void);
extern void     LCD_Clear(void);
extern void     LCD_SetCursor(uint32_t linha, uint32_t coluna);
extern void     LCD_WriteString(const char *s);
extern void     LCD_WriteNum(uint32_t n);

extern void     Teclado_Init(void);
extern uint32_t Teclado_Varredura(void);    // R0 = ASCII ou TECLA_NENHUMA
extern uint32_t Teclado_LeTecla(void);      // bloqueante, com debounce

extern void     LEDs_Init(void);
extern void     LEDs_Escreve(uint32_t padrao);
extern void     LEDs_Apaga(void);


static volatile int      estado;
static volatile uint32_t stepsRest;         // eventos de passo que faltam
static volatile uint32_t stepsPorVolta;     // 2048 (completo) ou 4096 (meio)
static volatile uint32_t stepsPor45;        // passos em 45 graus (256 ou 512)
static volatile uint32_t cnt45;             // conta ate a proxima troca de LED
static volatile int      stepDelta;         // +2/-2 (completo) ou +1/-1 (meio)
static volatile int      ledDelta;          // +1 (horario) ou -1 (anti-horario)
static volatile uint32_t ledIdx;            // posicao do LED aceso (0..7)

static uint32_t voltas;                     // 1..10
static int      modo;                       // 0 = passo completo, 1 = meio passo
static int      dir;                        // 0 = horario, 1 = anti-horario

static const char *const MsgGiro[4] = {
    "Horario  P.Comp.",   // dir 0, modo 0
    "Horario  Meio-P.",   // dir 0, modo 1
    "Anti-h.  P.Comp.",   // dir 1, modo 0
    "Anti-h.  Meio-P."    // dir 1, modo 1
};


static inline void IRQ_Off(void) { __asm volatile ("cpsid i" ::: "memory"); }
static inline void IRQ_On(void)  { __asm volatile ("cpsie i" ::: "memory"); }


void Timer0A_Task(void) {
    if (estado != ST_GIRANDO) {
        return;                              
    }
    Motor_Passo(stepDelta);                  

    if (--cnt45 == 0) {                      // a cada 45 graus o LED anda 1 posicao
        ledIdx = (ledIdx + (uint32_t)ledDelta) & 7u;
        cnt45  = stepsPor45;
    }

    if (--stepsRest == 0) {                  // terminou o movimento?
        Motor_Parado();
        Timer0A_Stop();
        estado = ST_FIM;
    }
}


static void SW1_Init(void) {
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R8;            // clock do Port J
    while ((SYSCTL_PRGPIO_R & SYSCTL_PRGPIO_R8) == 0) {
    }
    GPIO_PORTJ_AHB_DIR_R   &= ~0x01;                    // PJ0 entrada
    GPIO_PORTJ_AHB_AFSEL_R &= ~0x01;                    // sem funcao alternativa
    GPIO_PORTJ_AHB_PUR_R   |=  0x01;                    // pull-up (ativo em 0)
    GPIO_PORTJ_AHB_DEN_R   |=  0x01;                    // I/O digital
    // interrupcao: borda unica, de descida (aperto da tecla)
    GPIO_PORTJ_AHB_IM_R  &= ~0x01;                      // desabilita enquanto configura
    GPIO_PORTJ_AHB_IS_R  &= ~0x01;                      // sensivel a borda
    GPIO_PORTJ_AHB_IBE_R &= ~0x01;                      // uma borda so
    GPIO_PORTJ_AHB_IEV_R &= ~0x01;                      // borda de descida
    GPIO_PORTJ_AHB_ICR_R  =  0x01;                      // ACK (limpa pendencias)
    GPIO_PORTJ_AHB_IM_R  |=  0x01;                      // habilita int de PJ0
    // NVIC: IRQ 51 (Port J) -> EN1 bit 19; prioridade 5 (campo 31:29 de PRI12),
    // menor que a do Timer0A, para o cancelamento nunca cortar um passo no meio.
    NVIC_PRI12_R = (NVIC_PRI12_R & ~0xE0000000) | 0xA0000000;
    NVIC_EN1_R = 0x00080000;
}

void GPIOPortJ_Handler(void) {
    if ((GPIO_PORTJ_AHB_RIS_R & 0x01) == 0) {
        return;                              // nao foi PJ0
    }
    GPIO_PORTJ_AHB_ICR_R = 0x01;             // ACK

    // Timer0A tem prioridade maior; mascara tudo para o teste+escrita de estado
    // nao serem cortados por um passo (que poderia gravar FIM no meio).
    IRQ_Off();
    if (estado == ST_GIRANDO) {
        estado = ST_CANCEL;
        Motor_Parado();                      // bobinas desligadas
        Timer0A_Stop();                      // para de gerar passos
    }
    IRQ_On();
}

static void AtualizaValor(void) {
    LCD_SetCursor(1, 0);
    LCD_WriteString("Valor: ");
    LCD_WriteNum(voltas);
    LCD_WriteString("  ");                   
}

static void TelaVoltas(void) {
    LCD_Clear();
    LCD_SetCursor(0, 0);
    LCD_WriteString("Voltas 1-10 [#]");
    AtualizaValor();
}

static void TelaVeloc(void) {
    LCD_Clear();
    LCD_SetCursor(0, 0);
    LCD_WriteString("Velocidade:");
    LCD_SetCursor(1, 0);
    LCD_WriteString("1=Comp  2=Meio");
}

static void TelaSentido(void) {
    LCD_Clear();
    LCD_SetCursor(0, 0);
    LCD_WriteString("Sentido:");
    LCD_SetCursor(1, 0);
    LCD_WriteString("1=Hor 2=Anti-h");
}


static void IniciaGiro(uint32_t v, int m, int d) {
    uint32_t passosVolta, passos45;
    int      avanco;

    if (m == 0) {                            // passo completo (2 bobinas)
        passosVolta = PASSOS_POR_VOLTA_COMPLETO;   // 2048 eventos/volta
        passos45    = PASSOS_POR_VOLTA_COMPLETO / 8u;   // 256
        avanco      = PASSO_COMPLETO;              // +/-2
        Motor_AlinhaCompleto();                    // comeca num indice impar
    } else {                                 // meio passo
        passosVolta = PASSOS_POR_VOLTA_MEIO;       // 4096 eventos/volta
        passos45    = PASSOS_POR_VOLTA_MEIO / 8u;  // 512
        avanco      = PASSO_MEIO;                  // +/-1
    }

    stepsRest     = v * passosVolta;
    stepsPorVolta = passosVolta;
    stepsPor45    = passos45;
    cnt45         = passos45;

    if (d == 0) {                            // horario
        stepDelta = +avanco;
        ledDelta  = +1;                      // LED anda p/ a direita (visao do LCD)
        ledIdx    = 0;
    } else {                                 // anti-horario
        stepDelta = -avanco;
        ledDelta  = -1;                      // LED anda p/ a esquerda
        ledIdx    = 7;
    }

    // estado + start atomicos: o SW1 (prioridade menor) nao entra no meio e
    // deixa um cancelamento "perdido" antes do timer comecar a contar.
    IRQ_Off();
    estado = ST_GIRANDO;                     // libera a ISR
    Timer0A_Start();                         // comeca a gerar passos
    IRQ_On();
}


static void Do_Init(void) {
    Motor_Zera();
    LEDs_Apaga();
    voltas = 0;
    TelaVoltas();
    estado = ST_VOLTAS;
}

static void Do_Voltas(void) {
    uint32_t t = Teclado_LeTecla();
    if (t == '*') {
        estado = ST_INIT;
        return;
    }
    if (t == '#') {                          // confirma (so 1..10)
        if (voltas >= 1 && voltas <= 10) {
            TelaVeloc();
            estado = ST_VELOC;
        }
        return;
    }
    if (t >= '0' && t <= '9') {
        uint32_t d    = t - '0';
        uint32_t novo = voltas * 10u + d;
        if (novo <= 10u) {
            voltas = novo;
        } else if (d != 0u) {                // passou de 10: recomeca com o digito
            voltas = d;
        }                                    // (digito 0 nesse caso e ignorado)
        AtualizaValor();
    }
}

static void Do_Veloc(void) {
    uint32_t t = Teclado_LeTecla();
    if (t == '*') {
        estado = ST_INIT;
        return;
    }
    if (t == '1') {
        modo = 0;                            // passo completo
    } else if (t == '2') {
        modo = 1;                            // meio passo
    } else {
        return;
    }
    TelaSentido();
    estado = ST_SENTIDO;
}

static void Do_Sentido(void) {
    uint32_t t = Teclado_LeTecla();
    if (t == '*') {
        estado = ST_INIT;
        return;
    }
    if (t == '1') {
        dir = 0;                             // horario
    } else if (t == '2') {
        dir = 1;                             // anti-horario
    } else {
        return;
    }
    IniciaGiro(voltas, modo, dir);           // dispara o motor (estado = GIRANDO)
}

static void Do_Girando(void) {
    LCD_Clear();
    LCD_SetCursor(0, 0);
    LCD_WriteString(MsgGiro[dir * 2 + modo]);

    uint32_t voltasMostradas = 0xFFFFFFFFu;  // invalido -> forca o 1o desenho
    uint32_t ledMostrado     = 0xFFFFFFFFu;

    while (estado == ST_GIRANDO) {

        uint32_t sr  = stepsRest;
        uint32_t spv = stepsPorVolta;
        uint32_t vr  = (sr + spv - 1u) / spv;
        if (vr != voltasMostradas) {
            voltasMostradas = vr;
            LCD_SetCursor(1, 0);
            LCD_WriteString("Voltas: ");
            LCD_WriteNum(vr);
            LCD_WriteString("  ");
        }
        uint32_t li = ledIdx;
        if (li != ledMostrado) {
            ledMostrado = li;
            LEDs_Escreve(1u << li);          // 1 LED aceso (0x01<<idx: horario->direita)
        }
    }
    // saiu do laco: a ISR mudou o estado para FIM ou CANCELADO
}

static void Do_FimCancel(const char *msg) {
    Timer0A_Stop();                          // garante o timer parado (defensivo)
    Motor_Parado();                          // bobinas desligadas
    LEDs_Apaga();
    LCD_Clear();
    LCD_SetCursor(0, 0);
    LCD_WriteString(msg);
    LCD_SetCursor(1, 0);
    LCD_WriteString("* = novo");

    // descarta a tecla que possa ter ficado apertada durante o giro
    while (Teclado_Varredura() != TECLA_NENHUMA) {
    }
    // so o '*' volta ao inicio
    while (Teclado_LeTecla() != '*') {
    }
    estado = ST_INIT;
}

// =============================================================================
int main(void) {
    estado = ST_INIT;                        // valido antes de qualquer interrupcao
    Motor_Init();                            // bobinas desligadas, indice zerado
    Timer0A_Init(MS_TO_TICKS(STEP_MS));      // configura o GPTM (nao inicia: TAEN=0)
    SysTick_Init();                          // base de 1 ms p/ Delay_ms (+ CPSIE I)
    LCD_Init();                              // usa Delay_ms -> precisa do SysTick antes
    Teclado_Init();
    LEDs_Init();
    SW1_Init();                              // USR_SW1 com interrupcao externa (por ultimo)

    for (;;) {
        switch (estado) {
        case ST_INIT:    Do_Init();    break;
        case ST_VOLTAS:  Do_Voltas();  break;
        case ST_VELOC:   Do_Veloc();   break;
        case ST_SENTIDO: Do_Sentido(); break;
        case ST_GIRANDO: Do_Girando(); break;
        case ST_FIM:     Do_FimCancel("FIM");       break;
        case ST_CANCEL:  Do_FimCancel("CANCELADO"); break;
        default:         estado = ST_INIT;          break;
        }
    }
}
