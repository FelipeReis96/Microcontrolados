; teclado.s
; Lab 2 - Driver do teclado matricial 4x4, com debounce por software
;
; IMPORTANTE: teclado e LCD compartilham a Porta M (LCD usa PM0-2; teclado PM4-7).
; Para NAO corromper o LCD, este driver:
;   - mantem PM4-7 SEMPRE como saida (nunca troca a direcao da Porta M);
;   - escreve nas colunas por ESCRITA MASCARADA (endereco base+0x3C0), que altera
;     SOMENTE PM4-7 e nunca encosta em PM0-2 (RS/RW/E do LCD).
;
; Varredura (uma direcao): aciona cada coluna PM em 0, uma por vez, e le as
; linhas PL0-3 (entrada com pull-up). Linha em 0 = tecla pressionada.
;
; Ligacao na PAT (P16): PL0..PL3 (linhas) e PM4..PM7 (colunas).
; Mapa MEDIDO (cabo invertido):
;        PM4  PM5  PM6  PM7
; PL0:    D    #    0    *
; PL1:    C    9    8    7
; PL2:    B    6    5    4
; PL3:    A    3    2    1

        THUMB

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08

GPIO_PORTL_BASE     EQU 0x40062000
GPIO_PORTM_BASE     EQU 0x40063000

GPIO_O_DIR          EQU 0x00000400
GPIO_O_PUR          EQU 0x00000510
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC
; escrita MASCARADA de PM4-7: endereco = base + (mascara 0xF0 << 2) = base + 0x3C0
GPIO_O_DATA_PM      EQU 0x000003C0

RCGC_TECL_MASK      EQU 0x00000C00  ; L (bit10) + M (bit11)

MASK_PL             EQU 0x0000000F  ; PL0..PL3
MASK_PM             EQU 0x000000F0  ; PM4..PM7

TECLA_NENHUMA       EQU 0xFF

        AREA    Constantes, DATA, READONLY, ALIGN=2
; indexada por (indice PL)*4 + (indice PM).
; Tabela MEDIDA no teste_teclado (linha e coluna estavam trocadas -> transposta):
;   fisica 1->1, 5->5, 9->9 (diagonal ok); 2->2, 4->4, 6->6, 0->0 corrigidos.
TabTeclas
        DCB     'D', 'C', 'B', 'A'
        DCB     '#', '9', '6', '3'
        DCB     '0', '8', '5', '2'
        DCB     '*', '7', '4', '1'

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Teclado_Init
        EXPORT  Teclado_Varredura
        EXPORT  Teclado_LeTecla

        IMPORT  Delay_ms

; -----------------------------------------------------------------------------
; Teclado_Init - PL0-3 entrada+pull-up ; PM4-7 saida (fixa). Colunas em alto.
; -----------------------------------------------------------------------------
Teclado_Init
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    LDR     R2, =RCGC_TECL_MASK
    ORR     R0, R0, R2
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
TEC_wclk
    LDR     R0, [R1]
    AND     R0, R0, R2
    CMP     R0, R2
    BNE     TEC_wclk
    ; PL0-3 entrada com pull-up
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    BIC     R0, R0, #MASK_PL
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_PUR)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PL
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PL
    STR     R0, [R1]
    ; PM4-7 saida (nao mexe em PM0-2 do LCD)
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PM
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #MASK_PM
    STR     R0, [R1]
    ; colunas em alto (escrita mascarada: so PM4-7)
    MOV     R0, #0xF0
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA_PM)
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Teclado_Varredura - uma varredura (sem bloquear, sem debounce)
; Saida: R0 = ASCII da tecla, ou TECLA_NENHUMA (0xFF)
; -----------------------------------------------------------------------------
Teclado_Varredura
    PUSH    {R4-R7, LR}
    LDR     R7, =TabTeclas
    MOV     R4, #0                  ; indice da coluna (0..3)
TV_col
    CMP     R4, #4
    BGE     TV_none
    ; aciona a coluna R4 em 0 (PM(4+R4)=0, demais=1) - ESCRITA MASCARADA
    MOV     R5, #0x10
    LSL     R5, R5, R4
    MOV     R0, #0xF0
    BIC     R0, R0, R5
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA_PM)
    STR     R0, [R1]
    ; atraso de estabilizacao
    LDR     R3, =1500
TV_dly
    SUBS    R3, R3, #1
    BNE     TV_dly
    ; le as linhas PL0-3
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #MASK_PL
    TST     R0, #0x01               ; PL0 -> linha 0
    BEQ     TV_r0
    TST     R0, #0x02               ; PL1 -> linha 1
    BEQ     TV_r1
    TST     R0, #0x04               ; PL2 -> linha 2
    BEQ     TV_r2
    TST     R0, #0x08               ; PL3 -> linha 3
    BEQ     TV_r3
    ADD     R4, R4, #1
    B       TV_col
TV_r0
    MOV     R6, #0
    B       TV_found
TV_r1
    MOV     R6, #1
    B       TV_found
TV_r2
    MOV     R6, #2
    B       TV_found
TV_r3
    MOV     R6, #3
TV_found
    MOV     R0, #4
    MUL     R0, R6, R0
    ADD     R0, R0, R4              ; indice = linha*4 + coluna
    LDRB    R0, [R7, R0]
    BL      TV_restaura
    POP     {R4-R7, PC}
TV_none
    MOV     R0, #TECLA_NENHUMA
    BL      TV_restaura
    POP     {R4-R7, PC}

; recoloca as colunas em alto (escrita mascarada). Usa R1,R2 (nao altera R0).
TV_restaura
    MOV     R2, #0xF0
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA_PM)
    STR     R2, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Teclado_LeTecla - le uma tecla validada (bloqueante, com debounce)
; -----------------------------------------------------------------------------
Teclado_LeTecla
    PUSH    {R4, LR}
TL_press
    BL      Teclado_Varredura
    CMP     R0, #TECLA_NENHUMA
    BEQ     TL_press
    MOV     R4, R0
    MOV     R0, #20
    BL      Delay_ms
    BL      Teclado_Varredura
    CMP     R0, R4
    BNE     TL_press
TL_release
    BL      Teclado_Varredura
    CMP     R0, #TECLA_NENHUMA
    BNE     TL_release
    MOV     R0, #20
    BL      Delay_ms
    MOV     R0, R4
    POP     {R4, PC}

    ALIGN
    END
