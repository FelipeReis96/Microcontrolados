
        THUMB


SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08
GPIO_PORTA_AHB_BASE EQU 0x40058000
GPIO_PORTB_AHB_BASE EQU 0x40059000
GPIO_PORTP_AHB_BASE EQU 0x40065000
GPIO_PORTQ_AHB_BASE EQU 0x40066000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC

GPIO_CLOCK_MASK     EQU 0x00006003  ; portas A, B, P e Q

NVIC_ST_CTRL_R      EQU 0xE000E010
NVIC_ST_RELOAD_R    EQU 0xE000E014
NVIC_ST_CURRENT_R   EQU 0xE000E018
SYSTICK_RELOAD_1MS  EQU 15999       ; 16 MHz: (15999 + 1) x 62,5 ns = 1 ms
SYSTICK_COUNT       EQU 0x00010000


        AREA    Constantes, DATA, READONLY, ALIGN=2
; Padrões dos dígitos de 0 a 9 (bit 0 = a, ... bit 6 = g, bit 7 = dp)
TabSegmentos
        DCB     0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F


        AREA    |.text|, CODE, READONLY, ALIGN=2

        ; Exportar as funções para que o main.s consiga chamá-las
        EXPORT Init_Display
        EXPORT Varredura_Display


; PA7:PA4 e PQ3:PQ0 = dados dos segmentos
; PB4 = DS1 (dezenas), PB5 = DS2 (unidades), PP5 = LEDs
Init_Display
    ; 1. Habilitar o clock das portas A, B, P e Q
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    LDR     R2, =GPIO_CLOCK_MASK
    ORR     R0, R0, R2
    STR     R0, [R1]

    ; 2. Esperar o clock estabilizar usando SYSCTL_PRGPIO_R
    LDR     R1, =SYSCTL_PRGPIO_R
WaitGPIODisplay
    LDR     R0, [R1]
    AND     R0, R0, R2
    CMP     R0, R2
    BNE     WaitGPIODisplay

    ; 3. Configurar os pinos como saída (DIR = 1)
    LDR     R1, =(GPIO_PORTA_AHB_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #0xF0       ; PA7:PA4
    STR     R0, [R1]

    LDR     R1, =(GPIO_PORTQ_AHB_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #0x0F       ; PQ3:PQ0
    STR     R0, [R1]

    LDR     R1, =(GPIO_PORTB_AHB_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #0x30       ; PB4 e PB5
    STR     R0, [R1]

    LDR     R1, =(GPIO_PORTP_AHB_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #0x20       ; PP5
    STR     R0, [R1]

    ; 4. Habilitar função digital (DEN = 1)
    LDR     R1, =(GPIO_PORTA_AHB_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #0xF0
    STR     R0, [R1]

    LDR     R1, =(GPIO_PORTQ_AHB_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #0x0F
    STR     R0, [R1]

    LDR     R1, =(GPIO_PORTB_AHB_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #0x30
    STR     R0, [R1]

    LDR     R1, =(GPIO_PORTP_AHB_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #0x20
    STR     R0, [R1]

    ; 5. Começar com os transistores desligados (PB4, PB5 e PP5 = 0)
    LDR     R1, =(GPIO_PORTB_AHB_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    BIC     R0, R0, #0x30
    STR     R0, [R1]

    LDR     R1, =(GPIO_PORTP_AHB_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    BIC     R0, R0, #0x20
    STR     R0, [R1]

    ; 6. Configurar o SysTick (sem interrupção)
    LDR     R1, =NVIC_ST_CTRL_R
    MOV     R0, #0
    STR     R0, [R1]            ; desliga durante a inicialização
    LDR     R1, =NVIC_ST_RELOAD_R
    LDR     R0, =SYSTICK_RELOAD_1MS
    STR     R0, [R1]
    LDR     R1, =NVIC_ST_CURRENT_R
    MOV     R0, #0
    STR     R0, [R1]            ; qualquer escrita limpa o contador
    LDR     R1, =NVIC_ST_CTRL_R
    MOV     R0, #5              ; CLK_SRC e ENABLE
    STR     R0, [R1]

    BX      R14


; Espera 1 ms. Usa R0 a R3
SysTick_Wait1ms
    LDR     R1, =NVIC_ST_CURRENT_R
    MOV     R0, #0
    STR     R0, [R1]            ; zera o contador e o flag COUNT
    LDR     R1, =NVIC_ST_CTRL_R
    LDR     R3, =SYSTICK_COUNT
WaitSysTick
    LDR     R2, [R1]
    AND     R2, R2, R3
    CMP     R2, #0
    BEQ     WaitSysTick
    BX      R14


; R0 = padrão de 8 bits (bits 7:4 vão para PA7:PA4 e bits 3:0 para PQ3:PQ0)
; Usa R1 a R3
Escreve_Segmentos
    LDR     R1, =(GPIO_PORTA_AHB_BASE + GPIO_O_DATA)
    LDR     R2, [R1]
    BIC     R2, R2, #0xF0
    AND     R3, R0, #0xF0
    ORR     R2, R2, R3
    STR     R2, [R1]

    LDR     R1, =(GPIO_PORTQ_AHB_BASE + GPIO_O_DATA)
    LDR     R2, [R1]
    BIC     R2, R2, #0x0F
    AND     R3, R0, #0x0F
    ORR     R2, R2, R3
    STR     R2, [R1]

    BX      R14


; Mostra o padrão por 1 ms e depois desliga por mais 1 ms (tempo de guarda)
; R0 = padrão, R1 = endereço do DATA da porta do transistor, R2 = bit do transistor
Pulso
    PUSH    {R4-R6, R14}
    MOV     R4, R1
    MOV     R5, R2
    BL      Escreve_Segmentos   ; o transistor ainda está desligado

    LDR     R6, [R4]
    ORR     R6, R6, R5          ; liga o transistor
    STR     R6, [R4]
    BL      SysTick_Wait1ms

    LDR     R6, [R4]
    BIC     R6, R6, R5          ; desliga o transistor
    STR     R6, [R4]
    BL      SysTick_Wait1ms     ; tempo de guarda

    POP     {R4-R6, R14}
    BX      R14


; Um ciclo de multiplexação: DS1, DS2 e LEDs, cada um com 1 ms ligado e 1 ms de guarda
; R0 = valor de 0 a 99, R1 = padrão dos LEDs (cada bit é um LED)
Varredura_Display
    PUSH    {R4-R7, R14}
    MOV     R6, R1              ; R6 = padrão dos LEDs
    MOV     R2, #10
    UDIV    R4, R0, R2          ; R4 = dezenas
    MLS     R5, R4, R2, R0      ; R5 = unidades
    LDR     R7, =TabSegmentos

    ; DS1 (dezenas) em PB4
    ADD     R1, R7, R4
    LDRB    R0, [R1]
    LDR     R1, =(GPIO_PORTB_AHB_BASE + GPIO_O_DATA)
    MOV     R2, #0x10
    BL      Pulso

    ; DS2 (unidades) em PB5
    ADD     R1, R7, R5
    LDRB    R0, [R1]
    LDR     R1, =(GPIO_PORTB_AHB_BASE + GPIO_O_DATA)
    MOV     R2, #0x20
    BL      Pulso

    ; LEDs em PP5
    MOV     R0, R6
    LDR     R1, =(GPIO_PORTP_AHB_BASE + GPIO_O_DATA)
    MOV     R2, #0x20
    BL      Pulso

    POP     {R4-R7, R14}
    BX      R14

    ALIGN
    END
