; util.s
; Lab 4 - Bobinador com motor de passo
; Base de tempo do sistema: SysTick com INTERRUPCAO a cada 1 ms.
;   - SysTick_Handler incrementa Ticks (contador de milissegundos);
;   - Delay_ms espera usando Ticks (nao bloqueia o motor, que roda no GPTM);
;   - os passos do motor sao gerados pelo GPTM (timer.c), NAO aqui.
; Clock assumido: 16 MHz (clock padrao pos-reset). Se usar PLL, ajustar RELOAD.

        THUMB

NVIC_ST_CTRL_R      EQU 0xE000E010
NVIC_ST_RELOAD_R    EQU 0xE000E014
NVIC_ST_CURRENT_R   EQU 0xE000E018

SYSTICK_RELOAD_1MS  EQU 15999       ; 16 MHz: (15999 + 1) x 62,5 ns = 1 ms
SYSTICK_CTRL_INT    EQU 7           ; CLK_SRC (bit2) + INTEN (bit1) + ENABLE (bit0)

        AREA    DadosUtil, DATA, READWRITE, ALIGN=2
Ticks   SPACE   4                   ; contador de milissegundos desde o reset

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Ticks
        EXPORT  SysTick_Init
        EXPORT  SysTick_Handler
        EXPORT  Delay_ms

; -----------------------------------------------------------------------------
; SysTick_Init - zera Ticks, habilita o SysTick com interrupcao (1 ms)
;                e habilita as interrupcoes globais (CPSIE I).
; -----------------------------------------------------------------------------
SysTick_Init
    LDR     R1, =NVIC_ST_CTRL_R
    MOV     R0, #0
    STR     R0, [R1]                ; desliga durante a configuracao
    LDR     R1, =Ticks
    STR     R0, [R1]                ; Ticks = 0
    LDR     R1, =NVIC_ST_RELOAD_R
    LDR     R0, =SYSTICK_RELOAD_1MS
    STR     R0, [R1]
    LDR     R1, =NVIC_ST_CURRENT_R
    MOV     R0, #0
    STR     R0, [R1]                ; qualquer escrita limpa o contador
    LDR     R1, =NVIC_ST_CTRL_R
    MOV     R0, #SYSTICK_CTRL_INT
    STR     R0, [R1]                ; ENABLE + INTEN + CLK_SRC
    CPSIE   I                       ; habilita interrupcoes globais (PRIMASK = 0)
    BX      LR

; -----------------------------------------------------------------------------
; SysTick_Handler - ISR do SysTick (sobrescreve o vetor [WEAK] do startup.s).
; Dispara a cada 1 ms. So incrementa Ticks (o motor roda no GPTM, nao aqui).
; R0-R3 sao empilhados pelo hardware, entao pode usa-los a vontade.
; -----------------------------------------------------------------------------
SysTick_Handler
    LDR     R1, =Ticks
    LDR     R0, [R1]
    ADD     R0, R0, #1
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Delay_ms - espera R0 milissegundos por LACO (busy-wait), SEM depender de
; interrupcao. Robusto para a inicializacao do LCD, que roda antes de tudo.
; ~16 MHz: o laco interno leva ~3 ciclos/iteracao; DLY_INNER gera >= 1 ms
; (folga proposital: atrasar demais nao prejudica o HD44780).
; Usa R0, R4; preserva R4.
; -----------------------------------------------------------------------------
DLY_INNER   EQU 6000                ; iteracoes por ms (>= 1 ms a 16 MHz, com folga)
Delay_ms
    PUSH    {R4}
    CMP     R0, #0
    BEQ     Dms_done
Dms_outer
    LDR     R4, =DLY_INNER
Dms_inner
    SUBS    R4, R4, #1
    BNE     Dms_inner               ; queima ~1 ms
    SUBS    R0, R0, #1
    BNE     Dms_outer
Dms_done
    POP     {R4}
    BX      LR

    ALIGN
    END
