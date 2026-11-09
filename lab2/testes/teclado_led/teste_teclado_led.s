; teste_teclado_led.s
; Mapeia o teclado usando os 8 LEDs da PAT (NAO usa o LCD).
;
; Mede, para a tecla segurada:
;   - a LINHA  -> acende (indice+1) LEDs no grupo das LINHAS  (PQ0..PQ3)
;   - a COLUNA -> acende (indice+1) LEDs no grupo das COLUNAS (PA4..PA7)
;
; Ou seja: voce CONTA os LEDs de cada grupo.
;   LINHA  = (LEDs acesos no grupo das linhas)  - 1
;   COLUNA = (LEDs acesos no grupo das colunas) - 1
;
; Ex.: segurar '1' -> 1 LED no grupo linha + 1 LED no grupo coluna (linha0, col0)
;      segurar '5' -> 2 + 2 (linha1, col1)
;      segurar '9' -> 3 + 3 (linha2, col2)
;
; Em repouso (nada apertado): todos os LEDs apagados.
;
; Build: so teste_teclado_led.s + leds.s + util.s + startup.s.  (sem LCD!)
;
; Os dois grupos de LEDs: na PAT, LED1..LED4 sao as COLUNAS (PA7..PA4) e
; LED5..LED8 sao as LINHAS (PQ3..PQ0). Me diga, para 1/2/5/0, quantos LEDs
; acendem em cada grupo.

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08
GPIO_PORTL_BASE     EQU 0x40062000
GPIO_PORTM_BASE     EQU 0x40063000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_PUR          EQU 0x00000510
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC
RCGC_LM             EQU 0x00000C00
MASK_PL             EQU 0x0000000F      ; PL0..PL3 (linhas)
MASK_PM             EQU 0x000000F0      ; PM4..PM7 (colunas)

        THUMB
        AREA    |.text|, CODE, READONLY, ALIGN=2
        EXPORT  Start
        IMPORT  SysTick_Init
        IMPORT  Delay_ms
        IMPORT  LEDs_Init
        IMPORT  LEDs_Escreve

Start
    BL      SysTick_Init
    BL      LEDs_Init
    ; clock PL e PM
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    LDR     R2, =RCGC_LM
    ORR     R0, R0, R2
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
TL_wclk
    LDR     R0, [R1]
    AND     R0, R0, R2
    CMP     R0, R2
    BNE     TL_wclk
    ; DEN + PUR em PL0-3 e PM4-7
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

TL_loop
    ; ===== acha a LINHA: PM4-7 saida=0, PL0-3 entrada, le PL =====
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PM
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PM
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PL
    STR     R0, [R1]
    BL      TL_settle
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #MASK_PL        ; bits das linhas (1 = solto, 0 = apertado)
    ; conta -> R8 = padrao no nibble baixo (0,1,3,7,0xF)
    MOV     R8, #0
    TST     R0, #0x01
    BNE     TL_lr1
    MOV     R8, #0x01
    B       TL_ldone
TL_lr1
    TST     R0, #0x02
    BNE     TL_lr2
    MOV     R8, #0x03
    B       TL_ldone
TL_lr2
    TST     R0, #0x04
    BNE     TL_lr3
    MOV     R8, #0x07
    B       TL_ldone
TL_lr3
    TST     R0, #0x08
    BNE     TL_ldone
    MOV     R8, #0x0F
TL_ldone

    ; ===== acha a COLUNA: PL0-3 saida=0, PM4-7 entrada, le PM =====
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PL
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PL
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PM
    STR     R0, [R1]
    BL      TL_settle
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    LSR     R0, R0, #4
    AND     R0, R0, #0x0F           ; bits das colunas
    ; conta -> R9 = padrao no nibble alto (0,0x10,0x30,0x70,0xF0)
    MOV     R9, #0
    TST     R0, #0x01
    BNE     TL_cc1
    MOV     R9, #0x10
    B       TL_cdone
TL_cc1
    TST     R0, #0x02
    BNE     TL_cc2
    MOV     R9, #0x30
    B       TL_cdone
TL_cc2
    TST     R0, #0x04
    BNE     TL_cc3
    MOV     R9, #0x70
    B       TL_cdone
TL_cc3
    TST     R0, #0x08
    BNE     TL_cdone
    MOV     R9, #0xF0
TL_cdone

    ; combina e mostra nos LEDs
    ORR     R0, R8, R9
    BL      LEDs_Escreve

    MOV     R0, #60
    BL      Delay_ms
    B       TL_loop

TL_settle
    LDR     R0, =400
TL_s1
    SUBS    R0, R0, #1
    BNE     TL_s1
    BX      LR

    ALIGN
    END
