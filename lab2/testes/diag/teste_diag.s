; teste_diag.s
; Diagnostico em 2 fases usando os LEDs onboard D1(PN1)/D2(PN0) como sinal.
; Descobre EXATAMENTE onde o programa trava, sem precisar de debugger.
;
; Como usar no Keil:
;   - Deixe no build APENAS: teste_diag.s, util.s, lcd.s, startup.s.
;   - Exclua do build: main.s, teste_lcd.s, teste_blink.s (so pode haver 1 'Start').
;   - Build + Download.
;
; LEITURA DO RESULTADO (observe os LEDs D1/D2):
;   (a) NAO pisca nada e ficam apagados
;         -> travou no 1o Delay_ms = SysTick NAO conta. Problema no SysTick/clock.
;   (b) Pisca 3x, pausa ~1 s, e PARA (fica apagado)
;         -> SysTick OK, mas travou DENTRO do LCD_Init (ex.: espera do clock da
;            porta K/M que nao fica pronto). Problema de init/porta.
;   (c) Pisca 3x, pausa, pisca mais 3x e fica ACESO no fim
;         -> SysTick e LCD_Init completaram OK. Se mesmo assim o LCD nao mostra
;            "DIAG OK", o problema e de SINAL/FIACAO (RS/E/D0-D7) ou nivel logico.

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08
GPIO_PORTN_BASE     EQU 0x40064000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC
RCGC_PORTN          EQU 0x00001000

        THUMB

        AREA    TextosDiag, DATA, READONLY, ALIGN=2
TD_msg      DCB "DIAG OK", 0
        ALIGN

        AREA    |.text|, CODE, READONLY, ALIGN=2
        EXPORT  Start
        IMPORT  SysTick_Init
        IMPORT  Delay_ms
        IMPORT  LCD_Init
        IMPORT  LCD_Clear
        IMPORT  LCD_SetCursor
        IMPORT  LCD_WriteString

Start
    ; configura LEDs PN0/PN1 como saida
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    ORR     R0, R0, #RCGC_PORTN
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
TD_wclk
    LDR     R0, [R1]
    AND     R0, R0, #RCGC_PORTN
    CMP     R0, #RCGC_PORTN
    BNE     TD_wclk
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #0x03
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #0x03
    STR     R0, [R1]

    BL      SysTick_Init

    ; ---- FASE 1: pisca 3x com Delay_ms (prova que o SysTick conta) ----
    MOV     R4, #3
TD_f1
    BL      TD_ledon
    MOV     R0, #200
    BL      Delay_ms
    BL      TD_ledoff
    MOV     R0, #200
    BL      Delay_ms
    SUBS    R4, R4, #1
    BNE     TD_f1

    ; pausa ~1 s para separar as fases
    MOV     R0, #250
    BL      Delay_ms
    MOV     R0, #250
    BL      Delay_ms
    MOV     R0, #250
    BL      Delay_ms
    MOV     R0, #250
    BL      Delay_ms

    ; ---- chama o init do LCD (se travar aqui, a FASE 2 nunca acontece) ----
    BL      LCD_Init

    ; ---- FASE 2: pisca 3x (prova que LCD_Init retornou) ----
    MOV     R4, #3
TD_f2
    BL      TD_ledon
    MOV     R0, #200
    BL      Delay_ms
    BL      TD_ledoff
    MOV     R0, #200
    BL      Delay_ms
    SUBS    R4, R4, #1
    BNE     TD_f2

    ; ---- tenta escrever no LCD ----
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =TD_msg
    BL      LCD_WriteString

    BL      TD_ledon                ; LEDs acesos = chegou ate o fim
TD_fim
    B       TD_fim

TD_ledon
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DATA)
    MOV     R0, #0x03
    STR     R0, [R1]
    BX      LR
TD_ledoff
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DATA)
    MOV     R0, #0x00
    STR     R0, [R1]
    BX      LR

    ALIGN
    END
