; jogo.s
; Lab 2 - Logica do Jogo da Memoria
;
; - gera numeros pseudoaleatorios (0..9) por software (LCG);
; - guarda a sequencia sorteada (ate 100 numeros) na RAM;
; - apresenta a sequencia no LCD;
; - le a entrada do usuario pelo teclado e compara.
;
; A orquestracao das telas/sinalizacoes fica no main.s.

NUM_MAX             EQU 100

        THUMB

; -----------------------------------------------------------------------------
; Estado do jogo (RAM)
; -----------------------------------------------------------------------------
        AREA    DadosJogo, DATA, ALIGN=2
Sequencia   SPACE   NUM_MAX         ; 1 byte por numero (0..9)
Nivel       SPACE   4               ; quantos numeros ja estao na sequencia
SementeRNG  SPACE   4               ; estado do gerador pseudoaleatorio

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Jogo_Init
        EXPORT  Random_Semente
        EXPORT  Random_Proximo
        EXPORT  Jogo_NovoNumero
        EXPORT  Jogo_Apresenta
        EXPORT  Jogo_LeEntrada

        IMPORT  Delay_ms
        IMPORT  LCD_Clear
        IMPORT  LCD_SetCursor
        IMPORT  LCD_WriteNum
        IMPORT  Teclado_LeTecla

; -----------------------------------------------------------------------------
; Jogo_Init - zera o nivel (sequencia vazia)
; -----------------------------------------------------------------------------
Jogo_Init
    LDR     R1, =Nivel
    MOV     R0, #0
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Random_Semente - R0 = semente inicial
; -----------------------------------------------------------------------------
Random_Semente
    LDR     R1, =SementeRNG
    STR     R0, [R1]
    BX      LR

; -----------------------------------------------------------------------------
; Random_Proximo - Saida: R0 = proximo numero pseudoaleatorio (0..9)
; LCG: x = x*1664525 + 1013904223 ; devolve (x >> 16) mod 10
; -----------------------------------------------------------------------------
Random_Proximo
    LDR     R1, =SementeRNG
    LDR     R0, [R1]
    LDR     R2, =1664525
    MUL     R0, R0, R2
    LDR     R2, =1013904223
    ADD     R0, R0, R2
    STR     R0, [R1]                ; salva o novo estado
    LSR     R0, R0, #16             ; usa os bits altos (melhor distribuicao)
    MOV     R2, #10
    UDIV    R3, R0, R2
    MLS     R0, R3, R2, R0          ; R0 = R0 - (R0/10)*10 = resto
    BX      LR

; -----------------------------------------------------------------------------
; Jogo_NovoNumero - sorteia e acrescenta 1 numero ao fim da sequencia
; Saida: R0 = novo nivel (quantidade de numeros na sequencia)
; -----------------------------------------------------------------------------
Jogo_NovoNumero
    PUSH    {R4-R5, LR}
    BL      Random_Proximo          ; R0 = 0..9
    LDR     R4, =Nivel
    LDR     R5, [R4]
    LDR     R1, =Sequencia
    STRB    R0, [R1, R5]            ; Sequencia[Nivel] = numero
    ADD     R5, R5, #1
    STR     R5, [R4]
    MOV     R0, R5
    POP     {R4-R5, PC}

; -----------------------------------------------------------------------------
; Jogo_Apresenta - mostra os Nivel numeros no LCD, um a um, com pausa
; -----------------------------------------------------------------------------
Jogo_Apresenta
    PUSH    {R4-R6, LR}
    LDR     R6, =Nivel
    LDR     R6, [R6]                ; quantidade
    LDR     R5, =Sequencia
    MOV     R4, #0                  ; indice
JA_loop
    CMP     R4, R6
    BGE     JA_done
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #8                  ; centraliza o digito
    BL      LCD_SetCursor
    LDRB    R0, [R5, R4]
    BL      LCD_WriteNum
    MOVW    R0, #700                ; numero visivel ~0,7 s
    BL      Delay_ms
    BL      LCD_Clear
    MOVW    R0, #250                ; pequeno intervalo apagado
    BL      Delay_ms
    ADD     R4, R4, #1
    B       JA_loop
JA_done
    POP     {R4-R6, PC}

; -----------------------------------------------------------------------------
; Jogo_LeEntrada - le Nivel teclas e compara com a sequencia
; Saida: R0 = 1 se acertou tudo, 0 se errou
; Teclas '*' e '#' sao ignoradas (so digitos 0..9 contam).
; -----------------------------------------------------------------------------
Jogo_LeEntrada
    PUSH    {R4-R6, LR}
    LDR     R6, =Nivel
    LDR     R6, [R6]
    LDR     R5, =Sequencia
    MOV     R4, #0
JL_loop
    CMP     R4, R6
    BGE     JL_ok
JL_read
    BL      Teclado_LeTecla         ; R0 = ASCII
    CMP     R0, #'0'
    BLT     JL_read                 ; ignora teclas nao numericas
    CMP     R0, #'9'
    BGT     JL_read
    SUB     R0, R0, #'0'            ; R0 = digito 0..9
    LDRB    R1, [R5, R4]
    CMP     R0, R1
    BNE     JL_err
    ADD     R4, R4, #1
    B       JL_loop
JL_ok
    MOV     R0, #1
    POP     {R4-R6, PC}
JL_err
    MOV     R0, #0
    POP     {R4-R6, PC}

    ALIGN
    END
