; botao.s
; Lab 3 - Bobinador com motor de passo
; USR_SW1 (PJ0, ativo em nivel baixo, pull-up interno) com INTERRUPCAO EXTERNA
; (Port J, IRQ 51) por borda de descida. Serve para CANCELAR o movimento.
;
; Roteiro dos slides (GPIO interrupt): GPIOIM=0 -> GPIOIS (borda) -> GPIOIBE (borda unica)
; -> GPIOIEV (descida) -> ACK em GPIOICR -> GPIOIM=1 -> NVIC (EN1 bit 19) + prioridade (PRI12).
;
; Bounce: a ISR e idempotente (so age se Estado = GIRANDO e o primeiro disparo ja muda o
; estado), entao rebotes seguintes do mesmo aperto nao causam efeito.

ST_GIRANDO          EQU 4
ST_CANCEL           EQU 6

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08

GPIO_PORTJ_BASE     EQU 0x40060000
GPIO_PORTH_BASE     EQU 0x4005F000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_IS           EQU 0x00000404
GPIO_O_IBE          EQU 0x00000408
GPIO_O_IEV          EQU 0x0000040C
GPIO_O_IM           EQU 0x00000410
GPIO_O_RIS          EQU 0x00000414
GPIO_O_ICR          EQU 0x0000041C
GPIO_O_PUR          EQU 0x00000510
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC

RCGC_J_MASK         EQU 0x00000100  ; Port J (bit 8)
SW1_MASK            EQU 0x00000001  ; PJ0

NVIC_EN1_R          EQU 0xE000E104  ; IRQ 32..63
NVIC_PRI12_R        EQU 0xE000E430  ; IRQ 48..51 (IRQ 51 = bits 31:29)
NVIC_EN1_PORTJ      EQU 0x00080000  ; IRQ 51 -> bit 19
PRI_PORTJ_MASK      EQU 0xE0000000
PRI_PORTJ_5         EQU 0xA0000000  ; prioridade 5 (menor que a do SysTick = 0)

        THUMB

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Botao_Init
        EXPORT  GPIOPortJ_Handler

        IMPORT  Estado

; -----------------------------------------------------------------------------
; Botao_Init
; -----------------------------------------------------------------------------
Botao_Init
    ; clock do Port J
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    ORR     R0, R0, #RCGC_J_MASK
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
BI_wclk
    LDR     R0, [R1]
    TST     R0, #RCGC_J_MASK
    BEQ     BI_wclk
    ; PJ0 entrada digital com pull-up
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    BIC     R0, R0, #SW1_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_PUR)
    LDR     R0, [R1]
    ORR     R0, R0, #SW1_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #SW1_MASK
    STR     R0, [R1]
    ; 1) desabilita a interrupcao de PJ0 enquanto configura
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_IM)
    LDR     R0, [R1]
    BIC     R0, R0, #SW1_MASK
    STR     R0, [R1]
    ; 2) sensivel a borda (GPIOIS = 0)
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_IS)
    LDR     R0, [R1]
    BIC     R0, R0, #SW1_MASK
    STR     R0, [R1]
    ; 3a) borda unica (GPIOIBE = 0)
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_IBE)
    LDR     R0, [R1]
    BIC     R0, R0, #SW1_MASK
    STR     R0, [R1]
    ; 3b) borda de descida = aperto da tecla (GPIOIEV = 0)
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_IEV)
    LDR     R0, [R1]
    BIC     R0, R0, #SW1_MASK
    STR     R0, [R1]
    ; 4) ACK: limpa pendencias antigas (GPIOICR)
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_ICR)
    MOV     R0, #SW1_MASK
    STR     R0, [R1]
    ; 5) habilita a interrupcao de PJ0 (GPIOIM)
    LDR     R1, =(GPIO_PORTJ_BASE + GPIO_O_IM)
    LDR     R0, [R1]
    ORR     R0, R0, #SW1_MASK
    STR     R0, [R1]
    ; 6) NVIC: prioridade 5 e habilita IRQ 51
    LDR     R1, =NVIC_PRI12_R
    LDR     R0, [R1]
    BIC     R0, R0, #PRI_PORTJ_MASK
    LDR     R2, =PRI_PORTJ_5
    ORR     R0, R0, R2
    STR     R0, [R1]
    LDR     R1, =NVIC_EN1_R
    LDR     R0, =NVIC_EN1_PORTJ
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; GPIOPortJ_Handler - USR_SW1 pressionada
;   Se estiver girando: Estado = CANCELADO e bobinas desligadas.
;   A ordem importa: primeiro o Estado (a ISR do SysTick para de dar passos),
;   depois as bobinas.
; -----------------------------------------------------------------------------
GPIOPortJ_Handler
    LDR     R0, =(GPIO_PORTJ_BASE + GPIO_O_RIS)
    LDR     R1, [R0]
    TST     R1, #SW1_MASK
    BEQ     GJ_fim                  ; nao foi PJ0
    LDR     R0, =(GPIO_PORTJ_BASE + GPIO_O_ICR)
    MOV     R1, #SW1_MASK
    STR     R1, [R0]                ; ACK
    ; teste + escrita de Estado sem ser interrompido pelo SysTick (que tem prioridade
    ; maior): senao ele poderia gravar FIM entre o CMP e o STR e este sobrescrever.
    CPSID   I
    LDR     R0, =Estado
    LDR     R1, [R0]
    CMP     R1, #ST_GIRANDO
    BNE     GJ_livre                ; fora do giro a tecla e ignorada
    MOV     R1, #ST_CANCEL
    STR     R1, [R0]
    MOV     R1, #0
    LDR     R0, =(GPIO_PORTH_BASE + GPIO_O_DATA)
    STR     R1, [R0]                ; bobinas desligadas
GJ_livre
    CPSIE   I
GJ_fim
    BX      LR

    ALIGN
    END
