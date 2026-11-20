; util.s
; Lab 3 - Bobinador com motor de passo
; Base de tempo do sistema: SysTick com INTERRUPCAO a cada 1 ms.
;   - SysTick_Handler (em motor.s) incrementa Ticks e gera os passos do motor;
;   - Delay_ms espera usando Ticks (sem mexer no SysTick).
; Clock assumido: 16 MHz (clock padrao pos-reset).

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
        EXPORT  Delay_ms

; -----------------------------------------------------------------------------
; SysTick_Init - zera Ticks e habilita o SysTick com interrupcao (1 ms)
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
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Delay_ms - espera R0 milissegundos (precisa do SysTick_Init e de CPSIE I).
; Usa R0, R1; preserva R4 e R5. Funciona mesmo com o overflow de Ticks.
; -----------------------------------------------------------------------------
Delay_ms
    PUSH    {R4, R5}
    LDR     R1, =Ticks
    LDR     R4, [R1]                ; instante inicial
    MOV     R5, R0                  ; duracao
Dms_wait
    LDR     R0, [R1]
    SUB     R0, R0, R4              ; decorrido (aritmetica modular)
    CMP     R0, R5
    BLO     Dms_wait                ; decorrido < duracao -> continua
    POP     {R4, R5}
    BX      LR

    ALIGN
    END
