; lcd.s
; Lab 2 - Driver do modulo LCD 16x2 (controlador compativel HD44780), modo 8 bits
;
; Ligacao na PAT DAELN (Sch_PATDAELN, folha 1 "Display LCD"):
;   Dados  D0..D7  -> PK0..PK7
;   RS              -> PM0   (0 = comando, 1 = dado)
;   R/W             -> PM1   (fixo em 0 = escrita; nao lemos o busy flag)
;   E               -> PM2   (pulso de enable)
;   VO/BL tratados por hardware (contraste no Pot1, backlight fixo)

        THUMB

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08

GPIO_PORTK_BASE     EQU 0x40061000
GPIO_PORTM_BASE     EQU 0x40063000

GPIO_O_DIR          EQU 0x00000400
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC

RCGC_LCD_MASK       EQU 0x00000A00  ; K (bit9) + M (bit11)

LCD_DADOS_MASK      EQU 0x000000FF  ; PK0..PK7
LCD_RS              EQU 0x00000001  ; PM0
LCD_E               EQU 0x00000004  ; PM2
LCD_CTRL_MASK       EQU 0x00000007  ; PM0..PM2 (RS, RW, E)

; Comandos HD44780
LCD_CLEAR           EQU 0x01
LCD_ENTRY_MODE      EQU 0x06        ; incrementa cursor, sem shift
LCD_DISPLAY_OFF     EQU 0x08        ; display off
LCD_DISPLAY_ON      EQU 0x0C        ; display on, cursor off, blink off
LCD_FUNCTION_SET    EQU 0x38        ; 8 bits, 2 linhas, 5x8
LCD_LINHA1          EQU 0x80
LCD_LINHA2          EQU 0xC0

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  LCD_Init
        EXPORT  LCD_Comando
        EXPORT  LCD_Dado
        EXPORT  LCD_Clear
        EXPORT  LCD_SetCursor
        EXPORT  LCD_WriteChar
        EXPORT  LCD_WriteString
        EXPORT  LCD_WriteNum

        IMPORT  Delay_ms

; -----------------------------------------------------------------------------
; LCD_Init
; -----------------------------------------------------------------------------
LCD_Init
    PUSH    {LR}
    ; clock de PortK e PortM
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    LDR     R2, =RCGC_LCD_MASK
    ORR     R0, R0, R2
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
LCD_wclk
    LDR     R0, [R1]
    AND     R0, R0, R2
    CMP     R0, R2
    BNE     LCD_wclk
    ; PK0..PK7 como saida digital (dados)
    LDR     R1, =(GPIO_PORTK_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #LCD_DADOS_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTK_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #LCD_DADOS_MASK
    STR     R0, [R1]
    ; PM0..PM2 como saida digital (controle) - nao mexe em PM4..PM6 (teclado)
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #LCD_CTRL_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #LCD_CTRL_MASK
    STR     R0, [R1]
    ; linhas de controle em 0
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    BIC     R0, R0, #LCD_CTRL_MASK
    STR     R0, [R1]
    ; sequencia de inicializacao do HD44780 (modo 8 bits, conforme datasheet)
    MOV     R0, #50
    BL      Delay_ms                ; espera o power-up (> 15 ms)
    MOV     R0, #0x30               ; function set "cego" 1
    BL      LCD_Comando
    MOV     R0, #5
    BL      Delay_ms                ; > 4,1 ms
    MOV     R0, #0x30               ; function set "cego" 2
    BL      LCD_Comando
    MOV     R0, #1
    BL      Delay_ms                ; > 100 us
    MOV     R0, #0x30               ; function set "cego" 3
    BL      LCD_Comando
    MOV     R0, #1
    BL      Delay_ms
    MOV     R0, #LCD_FUNCTION_SET   ; 0x38: 8 bits, 2 linhas, 5x8
    BL      LCD_Comando
    MOV     R0, #LCD_DISPLAY_OFF    ; 0x08: display off
    BL      LCD_Comando
    MOV     R0, #LCD_CLEAR          ; 0x01: limpa
    BL      LCD_Comando
    MOV     R0, #2
    BL      Delay_ms                ; clear precisa de ~1,5 ms
    MOV     R0, #LCD_ENTRY_MODE     ; 0x06: incrementa cursor
    BL      LCD_Comando
    MOV     R0, #LCD_DISPLAY_ON     ; 0x0C: liga o display
    BL      LCD_Comando
    POP     {PC}

; -----------------------------------------------------------------------------
; LCD_PulsoEnable - gera o pulso em E (sobe, espera, desce, espera). Usa R0-R2.
; ~250 us por borda: suficiente para o latch e para instrucoes rapidas (40 us).
; -----------------------------------------------------------------------------
LCD_PulsoEnable
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    ORR     R0, R0, #LCD_E          ; E = 1
    STR     R0, [R1]
    LDR     R2, =2000
LCD_pe1
    SUBS    R2, R2, #1
    BNE     LCD_pe1
    LDR     R0, [R1]
    BIC     R0, R0, #LCD_E          ; E = 0
    STR     R0, [R1]
    LDR     R2, =2000
LCD_pe2
    SUBS    R2, R2, #1
    BNE     LCD_pe2
    BX      LR

; -----------------------------------------------------------------------------
; LCD_Comando - R0 = byte de comando (RS = 0)
; -----------------------------------------------------------------------------
LCD_Comando
    PUSH    {LR}
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R2, [R1]
    BIC     R2, R2, #LCD_RS         ; RS = 0 (RW ja e 0)
    STR     R2, [R1]
    AND     R0, R0, #LCD_DADOS_MASK
    LDR     R1, =(GPIO_PORTK_BASE + GPIO_O_DATA)
    STR     R0, [R1]
    BL      LCD_PulsoEnable
    POP     {PC}

; -----------------------------------------------------------------------------
; LCD_Dado - R0 = byte de dado / caractere (RS = 1)
; -----------------------------------------------------------------------------
LCD_Dado
    PUSH    {LR}
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R2, [R1]
    ORR     R2, R2, #LCD_RS         ; RS = 1
    STR     R2, [R1]
    AND     R0, R0, #LCD_DADOS_MASK
    LDR     R1, =(GPIO_PORTK_BASE + GPIO_O_DATA)
    STR     R0, [R1]
    BL      LCD_PulsoEnable
    POP     {PC}

; -----------------------------------------------------------------------------
; LCD_Clear - limpa o display e espera (~2 ms)
; -----------------------------------------------------------------------------
LCD_Clear
    PUSH    {LR}
    MOV     R0, #LCD_CLEAR
    BL      LCD_Comando
    MOV     R0, #2
    BL      Delay_ms
    POP     {PC}

; -----------------------------------------------------------------------------
; LCD_SetCursor - R0 = linha (0/1), R1 = coluna (0..15)
; -----------------------------------------------------------------------------
LCD_SetCursor
    CMP     R0, #0
    BNE     SC_l2
    MOV     R2, #LCD_LINHA1
    B       SC_l3
SC_l2
    MOV     R2, #LCD_LINHA2
SC_l3
    ADD     R0, R2, R1
    B       LCD_Comando             ; tail-call: retorna ao chamador

; -----------------------------------------------------------------------------
; LCD_WriteChar - R0 = caractere ASCII
; -----------------------------------------------------------------------------
LCD_WriteChar
    B       LCD_Dado

; -----------------------------------------------------------------------------
; LCD_WriteString - R0 = ponteiro para string terminada em 0
; -----------------------------------------------------------------------------
LCD_WriteString
    PUSH    {R4, LR}
    MOV     R4, R0
WS_loop
    LDRB    R0, [R4]
    CMP     R0, #0
    BEQ     WS_done
    BL      LCD_Dado
    ADD     R4, R4, #1
    B       WS_loop
WS_done
    POP     {R4, PC}

; -----------------------------------------------------------------------------
; LCD_WriteNum - R0 = numero sem sinal; escreve em decimal (ASCII)
; -----------------------------------------------------------------------------
LCD_WriteNum
    PUSH    {R4-R6, LR}
    MOV     R4, R0                  ; valor
    MOV     R6, #0                  ; quantidade de digitos empilhados
    CMP     R4, #0
    BNE     WN_extrai
    MOV     R0, #'0'                ; caso especial: valor 0
    BL      LCD_Dado
    B       WN_done
WN_extrai
    CMP     R4, #0
    BEQ     WN_imprime
    MOV     R5, #10
    UDIV    R0, R4, R5              ; R0 = quociente
    MLS     R1, R0, R5, R4          ; R1 = resto = R4 - quociente*10
    ADD     R1, R1, #'0'
    PUSH    {R1}
    ADD     R6, R6, #1
    MOV     R4, R0
    B       WN_extrai
WN_imprime
    CMP     R6, #0
    BEQ     WN_done
    POP     {R0}
    BL      LCD_Dado
    SUB     R6, R6, #1
    B       WN_imprime
WN_done
    POP     {R4-R6, PC}

    ALIGN
    END
