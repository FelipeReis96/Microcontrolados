; teste_teclado.s
; Testa o teclado matricial 4x3 isoladamente.
; Linha 1 do LCD: "Tecla:"  | Linha 2: mostra a ULTIMA tecla apertada.
;
; Build: deixe no build so teste_teclado.s + lcd.s + teclado.s + util.s + startup.s.
;
; COMO LER:
;   - Aperta '5' e aparece '5' na linha 2 -> teclado OK e mapa certo.
;   - Aperta e NAO aparece nada -> o teclado nao esta sendo lido (fiacao: linhas
;     PL0-PL3 / colunas PM4-PM6, ou linhas e colunas trocadas).
;   - Aparece, mas a tecla ERRADA (ex.: aperta '1' e mostra '3') -> o mapa de
;     linhas/colunas esta espelhado; a gente corrige a tabela no teclado.s.

        THUMB

        AREA    TextosTec, DATA, READONLY, ALIGN=2
TT_msg      DCB "Tecla:", 0
        ALIGN

        AREA    |.text|, CODE, READONLY, ALIGN=2
        EXPORT  Start
        IMPORT  SysTick_Init
        IMPORT  LCD_Init
        IMPORT  LCD_Clear
        IMPORT  LCD_SetCursor
        IMPORT  LCD_WriteString
        IMPORT  LCD_WriteChar
        IMPORT  Teclado_Init
        IMPORT  Teclado_LeTecla

Start
    BL      SysTick_Init
    BL      LCD_Init
    BL      Teclado_Init
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =TT_msg
    BL      LCD_WriteString
TT_loop
    BL      Teclado_LeTecla         ; bloqueia ate uma tecla (com debounce) -> R0 = ASCII
    PUSH    {R0}
    MOV     R0, #1                  ; linha 2
    MOV     R1, #0                  ; coluna 0
    BL      LCD_SetCursor
    POP     {R0}
    BL      LCD_WriteChar           ; mostra o caractere da tecla
    B       TT_loop

    ALIGN
    END
