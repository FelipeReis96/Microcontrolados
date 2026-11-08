; teclado.s
; Lab 2 - Driver do teclado matricial 4x3 (tipo telefone), com debounce por SW
;
; Ligacao na PAT DAELN (Sch_PATDAELN, folha 2, P16):
;   LINHAS  (saidas)   -> PL0, PL1, PL2, PL3
;   COLUNAS (entradas) -> PM4, PM5, PM6        (PM7 sobra no layout 4x3)
;
; Varredura: ativa UMA linha em nivel 0 por vez e le as colunas.
; Colunas em nivel alto por pull-up interno; tecla pressionada -> coluna = 0.
;
;   Mapa:     PM4  PM5  PM6
;     PL0:     1    2    3
;     PL1:     4    5    6
;     PL2:     7    8    9
;     PL3:     *    0    #

        THUMB

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08

GPIO_PORTL_BASE     EQU 0x40062000  ; linhas PL0..PL3
GPIO_PORTM_BASE     EQU 0x40063000  ; colunas PM4..PM6 (compartilha porta com LCD)

GPIO_O_DIR          EQU 0x00000400
GPIO_O_PUR          EQU 0x00000510
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC

RCGC_TECL_MASK      EQU 0x00000C00  ; L (bit10) + M (bit11)

TECL_LINHAS_MASK    EQU 0x0000000F  ; PL0..PL3
TECL_COLUNAS_MASK   EQU 0x00000070  ; PM4..PM6

TECLA_NENHUMA       EQU 0xFF

        AREA    Constantes, DATA, READONLY, ALIGN=2
TabTeclas
        DCB     '1', '2', '3'
        DCB     '4', '5', '6'
        DCB     '7', '8', '9'
        DCB     '*', '0', '#'

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Teclado_Init
        EXPORT  Teclado_Varredura
        EXPORT  Teclado_LeTecla

        IMPORT  Delay_ms

; -----------------------------------------------------------------------------
; Teclado_Init - configura GPIO do teclado
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
    ; PL0..PL3 como saida
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    ORR     R0, R0, #TECL_LINHAS_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #TECL_LINHAS_MASK
    STR     R0, [R1]
    ; PM4..PM6 como entrada com pull-up (nao mexe em PM0..PM2 do LCD)
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    BIC     R0, R0, #TECL_COLUNAS_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_PUR)
    LDR     R0, [R1]
    ORR     R0, R0, #TECL_COLUNAS_MASK
    STR     R0, [R1]
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #TECL_COLUNAS_MASK
    STR     R0, [R1]
    ; linhas em repouso (nivel alto)
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    ORR     R0, R0, #TECL_LINHAS_MASK
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Teclado_Varredura - uma varredura (sem bloquear, sem debounce)
; Saida: R0 = ASCII da tecla, ou TECLA_NENHUMA (0xFF)
; -----------------------------------------------------------------------------
Teclado_Varredura
    PUSH    {R4-R7, LR}
    MOV     R4, #0                  ; indice da linha (0..3)
    LDR     R7, =TabTeclas
TV_row
    CMP     R4, #4
    BGE     TV_none
    ; ativa apenas a linha R4 em nivel 0
    MOV     R5, #1
    LSL     R5, R5, R4
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    ORR     R0, R0, #TECL_LINHAS_MASK
    BIC     R0, R0, R5
    STR     R0, [R1]
    ; pequeno atraso de estabilizacao
    MOV     R6, #200
TV_dly
    SUBS    R6, R6, #1
    BNE     TV_dly
    ; le as colunas
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #TECL_COLUNAS_MASK
    TST     R0, #0x10               ; PM4 -> coluna 0
    BEQ     TV_c0
    TST     R0, #0x20               ; PM5 -> coluna 1
    BEQ     TV_c1
    TST     R0, #0x40               ; PM6 -> coluna 2
    BEQ     TV_c2
    ADD     R4, R4, #1
    B       TV_row
TV_c0
    MOV     R6, #0
    B       TV_found
TV_c1
    MOV     R6, #1
    B       TV_found
TV_c2
    MOV     R6, #2
TV_found
    MOV     R0, #3
    MUL     R0, R4, R0
    ADD     R0, R0, R6              ; indice = linha*3 + coluna
    LDRB    R0, [R7, R0]
    BL      TV_restaura
    POP     {R4-R7, PC}
TV_none
    MOV     R0, #TECLA_NENHUMA
    BL      TV_restaura
    POP     {R4-R7, PC}

; restaura todas as linhas em nivel alto. Usa R1,R2 (nao altera R0).
TV_restaura
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R2, [R1]
    ORR     R2, R2, #TECL_LINHAS_MASK
    STR     R2, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Teclado_LeTecla - le uma tecla validada (bloqueante, com debounce)
; Saida: R0 = ASCII da tecla
; -----------------------------------------------------------------------------
Teclado_LeTecla
    PUSH    {R4, LR}
TL_press
    BL      Teclado_Varredura
    CMP     R0, #TECLA_NENHUMA
    BEQ     TL_press                ; espera alguma tecla
    MOV     R4, R0                  ; candidata
    MOV     R0, #20
    BL      Delay_ms                ; espera o bounce passar
    BL      Teclado_Varredura
    CMP     R0, R4
    BNE     TL_press                ; mudou -> era ruido, recomeca
TL_release
    BL      Teclado_Varredura
    CMP     R0, #TECLA_NENHUMA
    BNE     TL_release              ; espera soltar
    MOV     R0, #20
    BL      Delay_ms
    MOV     R0, R4
    POP     {R4, PC}

    ALIGN
    END
