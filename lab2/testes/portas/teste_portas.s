; teste_portas.s
; Pinpoint: descobre em que passo do init das portas K/M o programa trava.
; Usa os LEDs D1/D2 (PN0/PN1) em "rajadas" de 2 piscadas, separadas por ~1 s.
; Conte quantas RAJADAS (de 2 piscadas) acontecem antes de travar.
;
; Build: deixe no build so teste_portas.s + util.s + startup.s.
;
; LEITURA (numero de rajadas de 2 piscadas antes de parar):
;   1 rajada  -> travou esperando o clock das portas K/M (PRGPIO nunca fica pronto)
;   2 rajadas -> PRGPIO OK, mas HardFault ao acessar a PORTA K
;   3 rajadas -> acesso a K OK, HardFault ao acessar a PORTA M
;   4 rajadas + LEDs ACESOS fixos -> portas K e M 100% OK.
;                Entao o travamento do LCD_Init esta na sequencia de comandos do
;                HD44780 / sinais, nao nas portas.

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08
GPIO_PORTN_BASE     EQU 0x40064000
GPIO_PORTK_BASE     EQU 0x40061000
GPIO_PORTM_BASE     EQU 0x40063000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC
RCGC_PORTN          EQU 0x00001000
RCGC_KM             EQU 0x00000A00      ; K (bit9) + M (bit11)

        THUMB
        AREA    |.text|, CODE, READONLY, ALIGN=2
        EXPORT  Start
        IMPORT  SysTick_Init
        IMPORT  Delay_ms

Start
    ; ---- LEDs PN0/PN1 (saida) ----
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    ORR     R0, R0, #RCGC_PORTN
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
TP_wN
    LDR     R0, [R1]
    AND     R0, R0, #RCGC_PORTN
    CMP     R0, #RCGC_PORTN
    BNE     TP_wN
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #0x03
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #0x03
    STR     R0, [R1]

    BL      SysTick_Init

    ; ===== Rajada 1: programa vivo =====
    BL      TP_burst
    BL      TP_gap

    ; ===== passo B: habilita clock K+M e espera PRGPIO =====
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    LDR     R2, =RCGC_KM
    ORR     R0, R0, R2
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
TP_wKM
    LDR     R0, [R1]
    AND     R0, R0, R2
    CMP     R0, R2
    BNE     TP_wKM              ; se travar aqui -> so 1 rajada apareceu
    ; ===== Rajada 2: PRGPIO K/M OK =====
    BL      TP_burst
    BL      TP_gap

    ; ===== passo C: acessa registrador da PORTA K =====
    LDR     R1, =(GPIO_PORTK_BASE + GPIO_O_DIR)
    LDR     R0, [R1]            ; se faltar clock de K -> HardFault aqui
    ORR     R0, R0, #0xFF
    STR     R0, [R1]
    ; ===== Rajada 3: Porta K OK =====
    BL      TP_burst
    BL      TP_gap

    ; ===== passo D: acessa registrador da PORTA M =====
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DIR)
    LDR     R0, [R1]            ; se faltar clock de M -> HardFault aqui
    ORR     R0, R0, #0x07
    STR     R0, [R1]
    ; ===== Rajada 4: Porta M OK =====
    BL      TP_burst
    BL      TP_gap

    ; Tudo OK -> LEDs acesos fixos
    BL      TP_ledon
TP_fim
    B       TP_fim

; ---- rajada de 2 piscadas ----
TP_burst
    PUSH    {R4, LR}
    MOV     R4, #2
TP_b1
    BL      TP_ledon
    MOV     R0, #150
    BL      Delay_ms
    BL      TP_ledoff
    MOV     R0, #150
    BL      Delay_ms
    SUBS    R4, R4, #1
    BNE     TP_b1
    POP     {R4, PC}

; ---- pausa ~1 s (LEDs apagados) ----
TP_gap
    PUSH    {LR}
    MOV     R0, #250
    BL      Delay_ms
    MOV     R0, #250
    BL      Delay_ms
    MOV     R0, #250
    BL      Delay_ms
    MOV     R0, #250
    BL      Delay_ms
    POP     {PC}

TP_ledon
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DATA)
    MOV     R0, #0x03
    STR     R0, [R1]
    BX      LR
TP_ledoff
    LDR     R1, =(GPIO_PORTN_BASE + GPIO_O_DATA)
    MOV     R0, #0x00
    STR     R0, [R1]
    BX      LR

    ALIGN
    END
