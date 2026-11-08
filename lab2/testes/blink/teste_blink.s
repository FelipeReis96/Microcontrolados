; teste_blink.s
; Teste minimo de "o codigo esta rodando?": pisca os LEDs onboard da LaunchPad
; D1 (PN1) e D2 (PN0). NAO usa LCD, teclado nem SysTick. O atraso e um loop NOP,
; entao independe de qualquer configuracao de clock/timer.
;
; Como usar no Keil:
;   1. Exclua do build o main.s E o teste_lcd.s (botao direito -> Options for File
;      -> desmarque "Include in Target Build"). So pode haver UM 'Start' no projeto.
;   2. Add Existing File -> adicione este teste_blink.s. Mantenha o startup.s.
;      (lcd.s/util.s/etc podem ficar no build; nao atrapalham.)
;   3. Build + Download.
;
; Resultado:
;   - LEDs piscando  -> o micro esta rodando e o clock esta OK. Entao o problema
;                       do LCD e de fiacao/sinais (RS/E/D0-D7), nao de "nao roda".
;   - LEDs apagados/parados -> o programa NAO esta rodando: build nao gravou, ou
;                       startup/entry errado. Rever Build (0 erros) e Download.

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08
GPIO_PORTN_BASE     EQU 0x40064000      ; D1=PN1, D2=PN0 na EK-TM4C1294XL
GPIO_O_DIR          EQU 0x00000400
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC
RCGC_PORTN          EQU 0x00001000      ; bit 12

        THUMB
        AREA    |.text|, CODE, READONLY, ALIGN=2
        EXPORT  Start

Start
    ; habilita clock da Porta N
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    ORR     R0, R0, #RCGC_PORTN
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
TB_wclk
    LDR     R0, [R1]
    AND     R0, R0, #RCGC_PORTN
    CMP     R0, #RCGC_PORTN
    BNE     TB_wclk
    ; PN0 e PN1 como saida digital
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #0x03
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #0x03
    STR     R0, [R1]
    LDR     R4, =(GPIO_PORTN_BASE + GPIO_O_DATA)
TB_loop
    MOV     R0, #0x03
    STR     R0, [R4]                ; acende os 2 LEDs
    BL      TB_delay
    MOV     R0, #0x00
    STR     R0, [R4]                ; apaga
    BL      TB_delay
    B       TB_loop

TB_delay
    LDR     R2, =800000             ; ~0,1 s @16 MHz (loop burro, sem timer)
TB_d1
    SUBS    R2, R2, #1
    BNE     TB_d1
    BX      LR

    ALIGN
    END
