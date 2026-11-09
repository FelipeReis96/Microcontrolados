; teste_teclado_raw.s
; Monitor BRUTO do teclado: mostra ao vivo o estado dos 8 fios (PL0-3 e PM4-7).
; Nao assume quem e linha/coluna - testa os dois sentidos e mostra onde cai o nivel.
;
; Build: deixe no build so teste_teclado_raw.s + lcd.s + util.s + startup.s.
;   (Este teste NAO usa teclado.s - faz o acesso as portas por conta propria.)
;
; TELA:
;   Linha 1:  "PM4567:xxxx"   (estado de PM4,PM5,PM6,PM7 enquanto PL0-3 = 0)
;   Linha 2:  "PL0123:xxxx"   (estado de PL0,PL1,PL2,PL3 enquanto PM4-7 = 0)
;
; EM REPOUSO (nada apertado): tudo "1111" nas duas linhas (pull-up).
; AO SEGURAR UMA TECLA:
;   - um bit de PM4567 vira 0  -> essa e a COLUNA da tecla (lado ligado em PM)
;   - um bit de PL0123 vira 0  -> essa e a LINHA  da tecla (lado ligado em PL)
;   Anote qual tecla apertou e quais bits caem. Com isso eu corrijo o teclado.s.
;
;   Se NENHUM bit mudar em NENHUMA tecla -> o teclado nao esta conectado em
;   PL0-3 / PM4-7 (ou esta em outros pinos / cabo solto).

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08
GPIO_PORTL_BASE     EQU 0x40062000
GPIO_PORTM_BASE     EQU 0x40063000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_PUR          EQU 0x00000510
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC
RCGC_LM             EQU 0x00000C00      ; L (bit10) + M (bit11)
MASK_PL             EQU 0x0000000F      ; PL0..PL3
MASK_PM             EQU 0x000000F0      ; PM4..PM7

        THUMB

        AREA    TextosRaw, DATA, READONLY, ALIGN=2
TR_l1       DCB "PM4567:", 0
TR_l2       DCB "PL0123:", 0
        ALIGN

        AREA    |.text|, CODE, READONLY, ALIGN=2
        EXPORT  Start
        IMPORT  SysTick_Init
        IMPORT  Delay_ms
        IMPORT  LCD_Init
        IMPORT  LCD_Clear
        IMPORT  LCD_SetCursor
        IMPORT  LCD_WriteString
        IMPORT  LCD_WriteChar

Start
    BL      SysTick_Init
    BL      LCD_Init                ; configura LCD (e liga clock de PM, PK)

    ; habilita clock de PortL e PortM
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    LDR     R2, =RCGC_LM
    ORR     R0, R0, R2
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
TR_wclk
    LDR     R0, [R1]
    AND     R0, R0, R2
    CMP     R0, R2
    BNE     TR_wclk

    ; DEN + PUR para PL0-3 e PM4-7 (nao mexe em PM0-2 do LCD)
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PL
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_PUR)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PL
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PM
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_PUR)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PM
    STR     R0, [R1]

    ; rotulos fixos
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =TR_l1
    BL      LCD_WriteString
    MOV     R0, #1
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =TR_l2
    BL      LCD_WriteString

TR_loop
    ; ===== Modo A: PL0-3 = saida em 0, PM4-7 = entrada -> le colunas (PM) =====
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PL            ; PL0-3 saida
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PL            ; PL0-3 = 0
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PM            ; PM4-7 entrada
    STR     R0, [R1]
    BL      TR_settle
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    LSR     R0, R0, #4
    AND     R0, R0, #0x0F              ; R0 = bits PM4..PM7
    MOV     R5, R0                     ; guarda colunas

    ; ===== Modo B: PM4-7 = saida em 0, PL0-3 = entrada -> le linhas (PL) =====
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PM            ; PM4-7 saida
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PM            ; PM4-7 = 0
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PL            ; PL0-3 entrada
    STR     R0, [R1]
    BL      TR_settle
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #0x0F             ; R0 = bits PL0..PL3
    MOV     R6, R0                     ; guarda linhas

    ; ===== mostra no LCD =====
    MOV     R0, #0
    MOV     R1, #7
    BL      LCD_SetCursor
    MOV     R0, R5
    BL      TR_print4                  ; PM4,PM5,PM6,PM7
    MOV     R0, #1
    MOV     R1, #7
    BL      LCD_SetCursor
    MOV     R0, R6
    BL      TR_print4                  ; PL0,PL1,PL2,PL3

    ; refresca ~5x/s
    MOV     R0, #150
    BL      Delay_ms
    B       TR_loop

; imprime 4 bits de R0 (bit0,bit1,bit2,bit3) como '0'/'1'
TR_print4
    PUSH    {R4-R5, LR}
    MOV     R4, R0
    MOV     R5, #0
TR_p4
    MOV     R0, #1
    LSL     R0, R0, R5
    TST     R4, R0
    BEQ     TR_p4z
    MOV     R0, #'1'
    B       TR_p4w
TR_p4z
    MOV     R0, #'0'
TR_p4w
    BL      LCD_WriteChar
    ADD     R5, R5, #1
    CMP     R5, #4
    BLT     TR_p4
    POP     {R4-R5, PC}

; pequeno atraso de estabilizacao (~us)
TR_settle
    LDR     R0, =300
TR_s1
    SUBS    R0, R0, #1
    BNE     TR_s1
    BX      LR

    ALIGN
    END
