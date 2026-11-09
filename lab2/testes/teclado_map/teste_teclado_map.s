; teste_teclado_map.s
; Descobre o MAPA real do teclado, mostrando na LINHA 2 (limpa) do LCD:
;     L=x C=y
;   x = qual PL (0..3) fica em 0 quando a tecla e apertada (= a "linha")
;   y = qual PM (4..7) fica em 0 (= a "coluna")
;   '-' = nenhum detectado naquele lado.
;
; Build: so teste_teclado_map.s + lcd.s + util.s + startup.s.
;
; USO: segure UMA tecla e leia a linha 2. Faca a tabela:
;   1 -> L=? C=?      2 -> L=? C=?      3 -> L=? C=?
;   4 -> L=? C=?      5 -> L=? C=?      6 -> L=? C=?
;   7 -> L=? C=?      8 -> L=? C=?      9 -> L=? C=?
;   * -> L=? C=?      0 -> L=? C=?      # -> L=? C=?
; Me mande essa tabela que eu corrijo o teclado.s com o mapa certo.
;
; Se ao apertar aparecer "L=- C=-" -> aquela tecla nao aciona PL/PM (contato/fiacao).

SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08
GPIO_PORTL_BASE     EQU 0x40062000
GPIO_PORTM_BASE     EQU 0x40063000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_PUR          EQU 0x00000510
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC
RCGC_LM             EQU 0x00000C00
MASK_PL             EQU 0x0000000F
MASK_PM             EQU 0x000000F0

        THUMB
        AREA    TextosMap, DATA, READONLY, ALIGN=2
TM_l1       DCB "Segure 1 tecla", 0
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
    BL      LCD_Init
    ; clock PL e PM
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    LDR     R2, =RCGC_LM
    ORR     R0, R0, R2
    STR     R0, [R1]
    LDR     R1, =SYSCTL_PRGPIO_R
TM_wclk
    LDR     R0, [R1]
    AND     R0, R0, R2
    CMP     R0, R2
    BNE     TM_wclk
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
    ; rotulo fixo na linha 1
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =TM_l1
    BL      LCD_WriteString

TM_loop
    ; ===== Modo B: PM saida=0, PL entrada -> acha qual PL cai (linha) =====
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
    BL      TM_settle
    LDR     R1, =(GPIO_PORTL_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #MASK_PL
    ; acha bit 0 em PL0..PL3 -> R8 = '0'..'3' ou '-'
    MOV     R8, #'-'
    TST     R0, #0x01
    BNE     TM_pl1
    MOV     R8, #'0'
    B       TM_pldone
TM_pl1
    TST     R0, #0x02
    BNE     TM_pl2
    MOV     R8, #'1'
    B       TM_pldone
TM_pl2
    TST     R0, #0x04
    BNE     TM_pl3
    MOV     R8, #'2'
    B       TM_pldone
TM_pl3
    TST     R0, #0x08
    BNE     TM_pldone
    MOV     R8, #'3'
TM_pldone

    ; ===== Modo A: PL saida=0, PM entrada -> acha qual PM cai (coluna) =====
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
    BL      TM_settle
    LDR     R1, =(GPIO_PORTM_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #MASK_PM
    ; acha bit 0 em PM4..PM7 -> R9 = '4'..'7' ou '-'
    MOV     R9, #'-'
    TST     R0, #0x10
    BNE     TM_pm1
    MOV     R9, #'4'
    B       TM_pmdone
TM_pm1
    TST     R0, #0x20
    BNE     TM_pm2
    MOV     R9, #'5'
    B       TM_pmdone
TM_pm2
    TST     R0, #0x40
    BNE     TM_pm3
    MOV     R9, #'6'
    B       TM_pmdone
TM_pm3
    TST     R0, #0x80
    BNE     TM_pmdone
    MOV     R9, #'7'
TM_pmdone

    ; ===== mostra "L=x C=y" na linha 2 =====
    MOV     R0, #1
    MOV     R1, #0
    BL      LCD_SetCursor
    MOV     R0, #'L'
    BL      LCD_WriteChar
    MOV     R0, #'='
    BL      LCD_WriteChar
    MOV     R0, R8
    BL      LCD_WriteChar
    MOV     R0, #' '
    BL      LCD_WriteChar
    MOV     R0, #'C'
    BL      LCD_WriteChar
    MOV     R0, #'='
    BL      LCD_WriteChar
    MOV     R0, R9
    BL      LCD_WriteChar
    MOV     R0, #' '
    BL      LCD_WriteChar
    MOV     R0, #' '
    BL      LCD_WriteChar

    MOV     R0, #120
    BL      Delay_ms
    B       TM_loop

TM_settle
    LDR     R0, =400
TM_s1
    SUBS    R0, R0, #1
    BNE     TM_s1
    BX      LR

    ALIGN
    END
