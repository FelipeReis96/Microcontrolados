; leds.s
; Lab 2 - Sinalizacao nos 8 LEDs da PAT
;
; Ligacao na PAT DAELN (Sch_PATDAELN, folha 2 "LEDs"):
;   LED1..LED8 usam as linhas  PA7 PA6 PA5 PA4  PQ3 PQ2 PQ1 PQ0
;   O conjunto so acende com o transistor Q1 habilitado -> PP5 = 1.
;
;   Padrao de 8 bits (R0):
;     bit7->PA7 ... bit4->PA4   (nibble alto -> PA7:PA4)
;     bit3->PQ3 ... bit0->PQ0   (nibble baixo -> PQ3:PQ0)

        THUMB

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08

GPIO_PORTA_BASE     EQU 0x40058000
GPIO_PORTP_BASE     EQU 0x40065000
GPIO_PORTQ_BASE     EQU 0x40066000

GPIO_O_DIR          EQU 0x00000400
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC

RCGC_LEDS_MASK      EQU 0x00006001  ; A (bit0) + P (bit13) + Q (bit14)

LEDS_PA_MASK        EQU 0x000000F0  ; PA7:PA4
LEDS_PQ_MASK        EQU 0x0000000F  ; PQ3:PQ0
LEDS_EN_PP5         EQU 0x00000020  ; PP5

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  LEDs_Init
        EXPORT  LEDs_Escreve
        EXPORT  LEDs_Todos
        EXPORT  LEDs_Apaga

; -----------------------------------------------------------------------------
; LEDs_Init
; -----------------------------------------------------------------------------
LEDs_Init
    PUSH    {LR}
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    LDR     R2, =RCGC_LEDS_MASK
    ORR     R0, R0, R2
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
LED_wclk
    LDR     R0, [R1]
    AND     R0, R0, R2
    CMP     R0, R2
    BNE     LED_wclk
    ; PA7:PA4 saida
    LDR     R1, =(GPIO_PORTA_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #LEDS_PA_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTA_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #LEDS_PA_MASK
    STR     R0, [R1]
    ; PQ3:PQ0 saida
    LDR     R1, =(GPIO_PORTQ_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #LEDS_PQ_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTQ_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #LEDS_PQ_MASK
    STR     R0, [R1]
    ; PP5 saida (habilita transistor)
    LDR     R1, =(GPIO_PORTP_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #LEDS_EN_PP5
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTP_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #LEDS_EN_PP5
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTP_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    ORR     R0, R0, #LEDS_EN_PP5    ; PP5 = 1 (liga os LEDs)
    STR     R0, [R1]
    BL      LEDs_Apaga
    POP     {PC}

; -----------------------------------------------------------------------------
; LEDs_Escreve - R0 = padrao de 8 bits. Usa R0-R3.
; -----------------------------------------------------------------------------
LEDs_Escreve
    AND     R2, R0, #LEDS_PA_MASK
    LDR     R1, =(GPIO_PORTA_BASE + GPIO_O_DATA)
    LDR     R3, [R1]
    BIC     R3, R3, #LEDS_PA_MASK
    ORR     R3, R3, R2
    STR     R3, [R1]
    AND     R2, R0, #LEDS_PQ_MASK
    LDR     R1, =(GPIO_PORTQ_BASE + GPIO_O_DATA)
    LDR     R3, [R1]
    BIC     R3, R3, #LEDS_PQ_MASK
    ORR     R3, R3, R2
    STR     R3, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; LEDs_Todos - acende todos
; -----------------------------------------------------------------------------
LEDs_Todos
    MOV     R0, #0xFF
    B       LEDs_Escreve

; -----------------------------------------------------------------------------
; LEDs_Apaga - apaga todos
; -----------------------------------------------------------------------------
LEDs_Apaga
    MOV     R0, #0x00
    B       LEDs_Escreve

    ALIGN
    END
