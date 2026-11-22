; util.s
; Lab 3 - Bobinador com motor de passo
; Base de tempo do sistema: TEMPORIZADOR GPTM Timer2A em modo PERIODICO,
; gerando INTERRUPCAO a cada 1 ms.
;   - Timer2A_Handler (em motor.s) incrementa Ticks e gera os passos do motor;
;   - Delay_ms espera usando Ticks (sem mexer no temporizador).
; Clock assumido: 16 MHz (clock padrao pos-reset).

        THUMB

; --- Habilitacao de clock do periferico Timer (RCGCTIMER / PRTIMER) ----------
SYSCTL_RCGCTIMER_R  EQU 0x400FE604
SYSCTL_PRTIMER_R    EQU 0x400FEA04
RCGC_TIMER2_MASK    EQU 0x00000004  ; Timer2 (bit 2)

; --- Registradores do Timer2 (base 0x40032000) ------------------------------
TIMER2_BASE         EQU 0x40032000
GPTM_O_CFG          EQU 0x00000000  ; GPTMCFG
GPTM_O_TAMR         EQU 0x00000004  ; GPTMTAMR
GPTM_O_CTL          EQU 0x0000000C  ; GPTMCTL
GPTM_O_IMR          EQU 0x00000018  ; GPTMIMR
GPTM_O_ICR          EQU 0x00000024  ; GPTMICR
GPTM_O_TAILR        EQU 0x00000028  ; GPTMTAILR

GPTM_CFG_32BIT      EQU 0x00000000  ; temporizador de 32 bits
GPTM_TAMR_PERIODIC  EQU 0x00000002  ; TAMR = 2 (modo periodico, conta decrescente)
GPTM_CTL_TAEN       EQU 0x00000001  ; habilita o Timer A
GPTM_IMR_TATO       EQU 0x00000001  ; interrupcao de timeout (TATOIM)
GPTM_ICR_TATO       EQU 0x00000001  ; limpa a flag de timeout (TATOCINT)

TIMER2_RELOAD_1MS   EQU 15999       ; 16 MHz: (15999 + 1) x 62,5 ns = 1 ms

; --- NVIC: Timer2A = IRQ 23 (vetor 39) --------------------------------------
NVIC_EN0_R          EQU 0xE000E100  ; Interrupt 0-31 Set Enable
NVIC_EN_TIMER2A     EQU 0x00800000  ; bit 23

        AREA    DadosUtil, DATA, READWRITE, ALIGN=2
Ticks   SPACE   4                   ; contador de milissegundos desde o reset

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Ticks
        EXPORT  Timer2_Init
        EXPORT  Delay_ms

; -----------------------------------------------------------------------------
; Timer2_Init - zera Ticks e configura o Timer2A como temporizador periodico
; de 1 ms com interrupcao (GPTM). Passos conforme o manual do TM4C1294:
;   1) liga o clock do Timer2 e espera ficar pronto;
;   2) desabilita o timer para configurar;
;   3) modo 32 bits, periodico, recarga = 1 ms;
;   4) limpa e habilita a interrupcao de timeout (no periferico e no NVIC);
;   5) habilita o Timer A.
; -----------------------------------------------------------------------------
Timer2_Init
    ; 1) clock do Timer2
    LDR     R1, =SYSCTL_RCGCTIMER_R
    LDR     R0, [R1]
    ORR     R0, R0, #RCGC_TIMER2_MASK
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRTIMER_R
T2_wclk
    LDR     R0, [R1]
    TST     R0, #RCGC_TIMER2_MASK
    BEQ     T2_wclk                 ; espera o periferico ficar pronto
    LDR     R2, =TIMER2_BASE
    ; 2) desabilita o Timer A durante a configuracao
    MOV     R0, #0
    STR     R0, [R2, #GPTM_O_CTL]
    ; Ticks = 0
    LDR     R1, =Ticks
    STR     R0, [R1]
    ; 3) 32 bits, periodico, recarga de 1 ms
    MOV     R0, #GPTM_CFG_32BIT
    STR     R0, [R2, #GPTM_O_CFG]
    MOV     R0, #GPTM_TAMR_PERIODIC
    STR     R0, [R2, #GPTM_O_TAMR]
    LDR     R0, =TIMER2_RELOAD_1MS
    STR     R0, [R2, #GPTM_O_TAILR]
    ; 4) limpa e habilita a interrupcao de timeout
    MOV     R0, #GPTM_ICR_TATO
    STR     R0, [R2, #GPTM_O_ICR]
    MOV     R0, #GPTM_IMR_TATO
    STR     R0, [R2, #GPTM_O_IMR]
    LDR     R1, =NVIC_EN0_R
    LDR     R0, =NVIC_EN_TIMER2A
    STR     R0, [R1]                ; habilita IRQ 23 (Timer2A) no NVIC
    ; 5) habilita o Timer A
    MOV     R0, #GPTM_CTL_TAEN
    STR     R0, [R2, #GPTM_O_CTL]
    BX      LR

; -----------------------------------------------------------------------------
; Delay_ms - espera R0 milissegundos (precisa do Timer2_Init e de CPSIE I).
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
