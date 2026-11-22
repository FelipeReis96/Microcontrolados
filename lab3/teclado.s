; teclado.s
; Lab 3 - Driver do teclado matricial 4x4, com debounce por SW
;
; Ligacao na PAT DAELN (Sch_PATDAELN, folha 2, P16):
;   Saidas (varredura) -> PL0, PL1, PL2, PL3
;   Entradas (leitura) -> PM4, PM5, PM6, PM7
;
; IMPORTANTE: nesta montagem as LINHAS e COLUNAS do teclado 4x4 ficaram
; trocadas em relacao ao layout original 4x3. A tabela TabTeclas abaixo ja
; esta na ordem REAL da fiacao (deduzida por teste), de modo que cada tecla
; fisica produz o caractere correto. A linha de cima do teclado (1 2 3 A)
; e lida por PM7 -- se 1/2/3 continuarem "mortos", falta o fio de PM7.
;
; Varredura: ativa UMA saida em nivel 0 por vez e le as 4 entradas.
; Entradas em nivel alto por pull-up interno; tecla pressionada -> entrada = 0.
;
;   Mapa real (indice = saida*4 + entrada):
;             PM4  PM5  PM6  PM7
;     PL0:     D    C    B    A
;     PL1:     #    9    6    3
;     PL2:     0    8    5    2
;     PL3:     *    7    4    1

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

TECL_LINHAS_MASK    EQU 0x0000000F  ; PL0..PL3 (saidas de varredura)
TECL_COLUNAS_MASK   EQU 0x000000F0  ; PM4..PM7 (entradas de leitura)

TECLA_NENHUMA       EQU 0xFF

        AREA    Constantes, DATA, READONLY, ALIGN=2
; indice = saida(PL)*4 + entrada(PM): ja na ordem real da fiacao
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
    ; le as entradas PM4..PM7
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #TECL_COLUNAS_MASK
    TST     R0, #0x10               ; PM4 -> entrada 0
    BEQ     TV_c0
    TST     R0, #0x20               ; PM5 -> entrada 1
    BEQ     TV_c1
    TST     R0, #0x40               ; PM6 -> entrada 2
    BEQ     TV_c2
    TST     R0, #0x80               ; PM7 -> entrada 3
    BEQ     TV_c3
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
    B       TV_found
TV_c3
    MOV     R6, #3
TV_found
    LSL     R0, R4, #2              ; indice = saida*4 + entrada
    ADD     R0, R0, R6
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
