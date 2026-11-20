; motor.s
; Lab 3 - Bobinador com motor de passo
; Motor de passo UNIPOLAR (28BYJ-48, reducao ~64:1) acionado pelo ULN2003A da PAT.
;
; Ligacao na PAT DAELN (Sch_PATDAELN, folha 1 "Driver de Potencia e Motor de Passo Unipolar"):
;   ULN2003A  IN1..IN4  <-  PH0, PH1, PH2, PH3   (saidas L1..L4 no conector do motor)
;
; Passos por volta do eixo de SAIDA do motor (28BYJ-48):
;   passo completo (2 bobinas por passo) = 2048 passos por volta
;   meio passo                           = 4096 passos por volta
;
; Este arquivo tambem contem o SysTick_Handler (interrupcao de 1 ms), que
;   1. incrementa Ticks (base de tempo do Delay_ms);
;   2. enquanto Estado = GIRANDO, a cada STEP_MS dá um passo, conta passos
;      restantes, avanca o "LED de 45 graus" e detecta o fim do movimento.
; O LCD, os LEDs e o teclado ficam no laco principal (main.s): a ISR e curta.

ST_INIT             EQU 0
ST_VOLTAS           EQU 1
ST_VELOC            EQU 2
ST_SENTIDO          EQU 3
ST_GIRANDO          EQU 4
ST_FIM              EQU 5
ST_CANCEL           EQU 6

STEP_MS             EQU 2           ; periodo entre passos (ms) -> 500 passos/s

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08

GPIO_PORTH_BASE     EQU 0x4005F000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC

RCGC_H_MASK         EQU 0x00000080  ; Port H (bit 7)
MOTOR_MASK          EQU 0x0000000F  ; PH0..PH3

        THUMB

; -----------------------------------------------------------------------------
; Sequencia de meio passo (bits 0..3 = PH0..PH3 = bobinas L1..L4).
; Indices pares  = uma bobina;  indices impares = duas bobinas.
;   meio passo     : percorre todos os 8 indices (avanco de 1)
;   passo completo : percorre so os impares  (avanco de 2) -> 2 bobinas, mais torque
; -----------------------------------------------------------------------------
        AREA    TabMotor, DATA, READONLY, ALIGN=2
TabPassos
        DCB     0x01, 0x03, 0x02, 0x06, 0x04, 0x0C, 0x08, 0x09

; -----------------------------------------------------------------------------
; Variaveis (RAM) - sem inicializacao automatica: Motor_Init as zera
; -----------------------------------------------------------------------------
        AREA    DadosMotor, DATA, READWRITE, ALIGN=2
Estado          SPACE   4           ; estado atual da maquina de estados (ST_*)
StepsRest       SPACE   4           ; passos que faltam para terminar
StepsPorVolta   SPACE   4           ; 2048 (completo) ou 4096 (meio)
StepsPor45      SPACE   4           ; passos em 45 graus: 256 ou 512
Cnt45           SPACE   4           ; passos ate a proxima mudanca de LED
StepDelta       SPACE   4           ; avanco do indice da tabela: +2/-2/+1/-1
LedDelta        SPACE   4           ; +1 (horario) ou -1 (anti-horario)
LedIdx          SPACE   4           ; posicao do LED aceso (0..7)
SeqIdx          SPACE   4           ; indice atual em TabPassos (0..7)
Countdown       SPACE   4           ; ms ate o proximo passo

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Estado
        EXPORT  StepsRest
        EXPORT  StepsPorVolta
        EXPORT  LedIdx
        EXPORT  Motor_Init
        EXPORT  Motor_Zera
        EXPORT  Motor_Inicia
        EXPORT  SysTick_Handler

        IMPORT  Ticks

; -----------------------------------------------------------------------------
; Motor_Init - habilita Port H (PH0..PH3 saida), bobinas desligadas, zera variaveis
; -----------------------------------------------------------------------------
Motor_Init
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    ORR     R0, R0, #RCGC_H_MASK
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
MI_wclk
    LDR     R0, [R1]
    TST     R0, #RCGC_H_MASK
    BEQ     MI_wclk
    LDR     R1, =(GPIO_PORTH_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #MOTOR_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTH_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #MOTOR_MASK
    STR     R0, [R1]
    MOV     R0, #0
    LDR     R1, =(GPIO_PORTH_BASE + GPIO_O_DATA)
    STR     R0, [R1]                ; todas as bobinas desligadas
    ; variaveis
    LDR     R1, =StepsRest
    STR     R0, [R1]
    LDR     R1, =SeqIdx
    STR     R0, [R1]
    LDR     R1, =StepsPorVolta
    MOV     R2, #2048
    STR     R2, [R1]                ; nunca zero (evita divisao por zero no main)
    LDR     R1, =Countdown
    MOV     R2, #STEP_MS
    STR     R2, [R1]
    LDR     R1, =Estado
    MOV     R2, #ST_INIT
    STR     R2, [R1]                ; por ultimo: a ISR ja pode rodar
    BX      LR

; -----------------------------------------------------------------------------
; Motor_Zera - posicao atual = 0 graus e 0 voltas; bobinas desligadas
; (so chamar fora do estado GIRANDO)
; -----------------------------------------------------------------------------
Motor_Zera
    MOV     R0, #0
    LDR     R1, =StepsRest
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTH_BASE + GPIO_O_DATA)
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Motor_Inicia - configura e dispara o movimento (Estado = GIRANDO)
;   R0 = numero de voltas (1..10)
;   R1 = modo     (0 = passo completo, 1 = meio passo)
;   R2 = sentido  (0 = horario, 1 = anti-horario)
; Estado e escrito por ultimo, entao a ISR so passa a mexer no motor com tudo pronto.
; -----------------------------------------------------------------------------
Motor_Inicia
    PUSH    {R4}
    CMP     R1, #0
    BNE     MIn_meio
    MOV     R3, #2048               ; passos por volta
    MOV     R4, #256                ; passos em 45 graus (2048 / 8)
    MOV     R1, #2                  ; avanco na tabela = 2 (so indices impares)
    B       MIn_comum
MIn_meio
    MOV     R3, #4096
    MOV     R4, #512                ; 4096 / 8
    MOV     R1, #1                  ; avanco na tabela = 1
MIn_comum
    MUL     R0, R0, R3              ; passos totais = voltas x passos por volta
    LDR     R12, =StepsRest
    STR     R0, [R12]
    LDR     R12, =StepsPorVolta
    STR     R3, [R12]
    LDR     R12, =StepsPor45
    STR     R4, [R12]
    LDR     R12, =Cnt45
    STR     R4, [R12]
    CMP     R2, #0
    BNE     MIn_anti
    MOV     R0, R1                  ; StepDelta = +avanco
    MOV     R3, #1                  ; LedDelta  = +1 (LED anda para a direita)
    MOV     R4, #0                  ; LedIdx    = 0 (LED1, extremo esquerdo)
    B       MIn_dir
MIn_anti
    RSB     R0, R1, #0              ; StepDelta = -avanco
    MVN     R3, #0                  ; LedDelta  = -1 (LED anda para a esquerda)
    MOV     R4, #7                  ; LedIdx    = 7 (LED8, extremo direito)
MIn_dir
    LDR     R12, =StepDelta
    STR     R0, [R12]
    LDR     R12, =LedDelta
    STR     R3, [R12]
    LDR     R12, =LedIdx
    STR     R4, [R12]
    LDR     R12, =SeqIdx            ; passo completo precisa de indice impar
    LDR     R0, [R12]
    CMP     R1, #2
    BNE     MIn_seq
    ORR     R0, R0, #1
MIn_seq
    STR     R0, [R12]
    MOV     R0, #STEP_MS
    LDR     R12, =Countdown
    STR     R0, [R12]
    MOV     R0, #ST_GIRANDO
    LDR     R12, =Estado
    STR     R0, [R12]               ; libera a ISR
    POP     {R4}
    BX      LR

; -----------------------------------------------------------------------------
; SysTick_Handler - interrupcao de 1 ms (so usa R0-R3, salvos pelo hardware)
; Prioridade mais alta que a do botao (Port J): o cancelamento nunca interrompe
; um passo no meio, entao as bobinas nao voltam a ser energizadas apos cancelar.
; -----------------------------------------------------------------------------
SysTick_Handler
    LDR     R0, =Ticks
    LDR     R1, [R0]
    ADD     R1, R1, #1
    STR     R1, [R0]                ; Ticks++
    LDR     R0, =Estado
    LDR     R1, [R0]
    CMP     R1, #ST_GIRANDO
    BNE     SH_fim                  ; fora do giro: nada a fazer
    LDR     R0, =Countdown
    LDR     R1, [R0]
    SUBS    R1, R1, #1
    STR     R1, [R0]
    BNE     SH_fim                  ; ainda nao e hora do proximo passo
    MOV     R1, #STEP_MS
    STR     R1, [R0]                ; recarrega o periodo

    ; --- avanca o indice da sequencia e energiza as bobinas
    LDR     R0, =SeqIdx
    LDR     R1, [R0]
    LDR     R2, =StepDelta
    LDR     R2, [R2]
    ADD     R1, R1, R2
    AND     R1, R1, #7
    STR     R1, [R0]
    LDR     R2, =TabPassos
    LDRB    R2, [R2, R1]
    LDR     R3, =(GPIO_PORTH_BASE + GPIO_O_DATA)
    STR     R2, [R3]

    ; --- a cada 45 graus o LED aceso anda uma posicao
    LDR     R0, =Cnt45
    LDR     R2, [R0]
    SUBS    R2, R2, #1
    BNE     SH_led
    LDR     R3, =LedIdx
    LDR     R1, [R3]
    LDR     R2, =LedDelta
    LDR     R2, [R2]
    ADD     R1, R1, R2
    AND     R1, R1, #7
    STR     R1, [R3]
    LDR     R2, =StepsPor45         ; recarrega o contador de 45 graus
    LDR     R2, [R2]
SH_led
    STR     R2, [R0]

    ; --- um passo a menos; chegou a zero? entao fim do movimento
    LDR     R0, =StepsRest
    LDR     R1, [R0]
    SUBS    R1, R1, #1
    STR     R1, [R0]
    BNE     SH_fim
    MOV     R1, #0
    LDR     R2, =(GPIO_PORTH_BASE + GPIO_O_DATA)
    STR     R1, [R2]                ; desliga as bobinas
    MOV     R1, #ST_FIM
    LDR     R2, =Estado
    STR     R1, [R2]
SH_fim
    BX      LR

    ALIGN
    END
