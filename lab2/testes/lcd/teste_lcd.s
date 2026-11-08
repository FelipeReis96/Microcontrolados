; teste_lcd.s
; Teste ISOLADO do LCD (sem teclado, sem jogo) para depuracao.
;
; Como usar no Keil:
;   1. Clique com o botao direito em main.s -> Options for File -> aba Properties
;      -> desmarque "Include in Target Build" (exclui o main.s temporariamente).
;   2. Add Existing File -> adicione este teste_lcd.s.
;      (lcd.s, util.s e startup.s continuam no build.)
;   3. Build + Download.
;
; Resultado esperado: linha 1 "TESTE LCD OK", linha 2 "0123456789".
;   - Apareceu o texto -> LCD e init estao OK; o problema estava no fluxo do jogo.
;   - So retangulos pretos -> contraste OK, mas os dados nao chegam (ver fiacao D0-D7).
;   - Nada em nenhuma posicao do Pot1 -> alimentacao/contraste (VSS/VDD/V0).
;
; Para voltar ao jogo: reinclua main.s no build e exclua (ou remova) este arquivo.

        THUMB

        AREA    TextosTeste, DATA, READONLY, ALIGN=2
TL_Lin1     DCB "TESTE LCD OK", 0
TL_Lin2     DCB "0123456789", 0
        ALIGN

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Start

        IMPORT  SysTick_Init
        IMPORT  LCD_Init
        IMPORT  LCD_Clear
        IMPORT  LCD_SetCursor
        IMPORT  LCD_WriteString

Start
    BL      SysTick_Init
    BL      LCD_Init
    BL      LCD_Clear
    MOV     R0, #0                  ; linha 0
    MOV     R1, #0                  ; coluna 0
    BL      LCD_SetCursor
    LDR     R0, =TL_Lin1
    BL      LCD_WriteString
    MOV     R0, #1                  ; linha 1
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =TL_Lin2
    BL      LCD_WriteString
TL_fim
    B       TL_fim                  ; trava aqui mostrando o texto

    ALIGN
    END
