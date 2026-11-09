; util.s
; Lab 2 - Jogo da Memoria (LCD 16x2 + Teclado matricial 4x3)
; Rotinas utilitarias de temporizacao usando o SysTick (sem interrupcao).
; Clock assumido: 16 MHz (clock padrao pos-reset).

        THUMB

NVIC_ST_CTRL_R      EQU 0xE000E010
NVIC_ST_RELOAD_R    EQU 0xE000E014
NVIC_ST_CURRENT_R   EQU 0xE000E018

SYSTICK_RELOAD_1MS  EQU 15999       ; 16 MHz: (15999 + 1) x 62,5 ns = 1 ms
SYSTICK_COUNT       EQU 0x00010000  ; bit COUNT (16) do registrador CTRL

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  SysTick_Init
        EXPORT  Delay_1ms
        EXPORT  Delay_ms

; -----------------------------------------------------------------------------
; SysTick_Init - habilita o SysTick (fonte do core, sem interrupcao), base 1 ms
; -----------------------------------------------------------------------------
SysTick_Init
    LDR     R1, =NVIC_ST_CTRL_R
    MOV     R0, #0
    STR     R0, [R1]                ; desliga durante a configuracao
    LDR     R1, =NVIC_ST_RELOAD_R
    LDR     R0, =SYSTICK_RELOAD_1MS
    STR     R0, [R1]
    LDR     R1, =NVIC_ST_CURRENT_R
    MOV     R0, #0
    STR     R0, [R1]                ; qualquer escrita limpa o contador
    LDR     R1, =NVIC_ST_CTRL_R
    MOV     R0, #5                  ; CLK_SRC (bit2) + ENABLE (bit0)
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Delay_1ms - espera ~1 ms. Usa R0-R3.
; -----------------------------------------------------------------------------
Delay_1ms
    LDR     R1, =NVIC_ST_CURRENT_R
    MOV     R0, #0
    STR     R0, [R1]                ; reinicia contagem e flag COUNT
    LDR     R1, =NVIC_ST_CTRL_R
    LDR     R3, =SYSTICK_COUNT
D1ms_wait
    LDR     R2, [R1]
    AND     R2, R2, R3
    CMP     R2, #0
    BEQ     D1ms_wait
    BX      LR

; -----------------------------------------------------------------------------
; Delay_ms - espera R0 milissegundos. Preserva R4.
; -----------------------------------------------------------------------------
Delay_ms
    PUSH    {R4, LR}
    MOV     R4, R0
Dms_loop
    CMP     R4, #0
    BEQ     Dms_done
    BL      Delay_1ms
    SUB     R4, R4, #1
    B       Dms_loop
Dms_done
    POP     {R4, LR}
    BX      LR

    ALIGN
    END
