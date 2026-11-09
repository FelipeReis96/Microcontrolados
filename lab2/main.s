; main.s
; Lab 2 - Jogo da Memoria (LCD 16x2 + teclado matricial 4x3)
; Placa: EK-TM4C1294XL + PAT DAELN
;
; Fluxo (ver fluxograma):
;   1. Inicializa SysTick, LCD, teclado e LEDs;
;   2. Tela de apresentacao (espera 1a tecla -> usada como semente do RNG);
;   3. Laco do jogo:
;        a. sorteia + acrescenta 1 numero (a sequencia cresce de 1 em 1);
;        b. apresenta a sequencia no LCD;
;        c. le a entrada do usuario e compara;
;        d. ACERTOU -> sinaliza (LCD + LEDs); se Nivel == 100 -> vitoria especial;
;        e. ERROU   -> sinaliza e reinicia (volta a tela de apresentacao).
;
; Registradores no laco:  R5 = nivel atual ; R4 = resultado (1/0) ; R6 = contador aux.

NUM_MAX             EQU 100
NVIC_ST_CURRENT_R   EQU 0xE000E018

        THUMB

; -----------------------------------------------------------------------------
; Textos das telas (<= 16 caracteres por linha), terminados em 0
; -----------------------------------------------------------------------------
        AREA    Textos, DATA, READONLY, ALIGN=2
MsgTitulo       DCB "JOGO DA MEMORIA", 0
MsgSubtitulo    DCB "Aperte uma tecla", 0
MsgMemorize     DCB "Memorize:", 0
MsgSuaVez       DCB "Sua vez:", 0
MsgAcerto       DCB "Acertou!", 0
MsgErro         DCB "Errou! :(", 0
MsgReinicia     DCB "Reiniciando...", 0
MsgVitoria      DCB "PARABENS! 100!", 0
        ALIGN

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Start

        IMPORT  SysTick_Init
        IMPORT  Delay_ms
        IMPORT  LCD_Init
        IMPORT  LCD_Clear
        IMPORT  LCD_SetCursor
        IMPORT  LCD_WriteString
        IMPORT  Teclado_Init
        IMPORT  Teclado_LeTecla
        IMPORT  Teclado_Varredura
        IMPORT  LEDs_Init
        IMPORT  LEDs_Todos
        IMPORT  LEDs_Apaga
        IMPORT  Jogo_Init
        IMPORT  Jogo_NovoNumero
        IMPORT  Jogo_Apresenta
        IMPORT  Jogo_LeEntrada
        IMPORT  Random_Semente

; =============================================================================
Start
    BL      SysTick_Init
    BL      LCD_Init
    BL      Teclado_Init
    BL      LEDs_Init

TelaApresentacao
    BL      LEDs_Apaga
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgTitulo
    BL      LCD_WriteString
    MOV     R0, #1
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgSubtitulo
    BL      LCD_WriteString
    ; espera a 1a tecla contando as varreduras -> entropia da duracao do aperto
    MOV     R4, #0
TA_seed
    ADD     R4, R4, #1
    BL      Teclado_Varredura
    CMP     R0, #0xFF
    BEQ     TA_seed
    MOV     R0, R4                  ; semente = quantas varreduras ate apertar
    BL      Random_Semente
TA_rel
    BL      Teclado_Varredura       ; espera soltar a tecla
    CMP     R0, #0xFF
    BNE     TA_rel
    BL      Jogo_Init

MainLoop
    ; a) novo numero
    BL      Jogo_NovoNumero
    MOV     R5, R0                  ; R5 = nivel atual
    ; b) apresenta a sequencia
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgMemorize
    BL      LCD_WriteString
    MOVW    R0, #700
    BL      Delay_ms
    BL      Jogo_Apresenta
    ; c) vez do usuario
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgSuaVez
    BL      LCD_WriteString
    MOVW    R0, #300
    BL      Delay_ms
    BL      Jogo_LeEntrada
    MOV     R4, R0                  ; R4 = 1 acertou / 0 errou
    CMP     R4, #0
    BEQ     Errou

Acertou
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgAcerto
    BL      LCD_WriteString
    BL      LEDs_Todos
    MOVW    R0, #600
    BL      Delay_ms
    BL      LEDs_Apaga
    MOVW    R0, #300
    BL      Delay_ms
    CMP     R5, #NUM_MAX            ; chegou a 100 numeros?
    BGE     Vitoria
    B       MainLoop

Errou
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgErro
    BL      LCD_WriteString
    MOV     R6, #3                  ; pisca os LEDs 3x
Errou_blink
    CMP     R6, #0
    BEQ     Errou_done
    BL      LEDs_Todos
    MOV     R0, #200
    BL      Delay_ms
    BL      LEDs_Apaga
    MOV     R0, #200
    BL      Delay_ms
    SUB     R6, R6, #1
    B       Errou_blink
Errou_done
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgReinicia
    BL      LCD_WriteString
    MOVW    R0, #1000
    BL      Delay_ms
    B       TelaApresentacao

Vitoria
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgVitoria
    BL      LCD_WriteString
    MOV     R6, #6                  ; animacao especial
Vitoria_blink
    CMP     R6, #0
    BEQ     Vitoria_done
    BL      LEDs_Todos
    MOV     R0, #150
    BL      Delay_ms
    BL      LEDs_Apaga
    MOV     R0, #150
    BL      Delay_ms
    SUB     R6, R6, #1
    B       Vitoria_blink
Vitoria_done
    MOVW    R0, #1500
    BL      Delay_ms
    B       TelaApresentacao

    ALIGN
    END
