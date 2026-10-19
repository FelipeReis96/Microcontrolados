; main.s
; Lab 1 - Contador 0 a 99 em dois displays de 7 segmentos
;
; R4  = contador (0 a 99)
; R5  = passo (1 a 9)
; R6  = padrao dos LEDs para o numero atual
; R7  = ciclos de varredura restantes para o numero atual
; R9  = ultima leitura de USR_SW1, R10 = ultima leitura de USR_SW2 (deteccao de borda)

CICLOS_POR_NUMERO   EQU 80          ; 80 ciclos de ~6 ms = ~0,5 s por numero
LEDS_PRIMO          EQU 0xFF        ; todos os LEDs acesos
LEDS_NAO_PRIMO      EQU 0x55        ; LEDs acesos de forma alternada

        THUMB

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Start

        IMPORT  Init_Buttons_PortJ
        IMPORT  Read_USR_SW1
        IMPORT  Read_USR_SW2
        IMPORT  Init_Display
        IMPORT  Varredura_Display
        IMPORT  VerificarPrimo


Start
    ; 1. Inicializar botoes e displays
    BL      Init_Buttons_PortJ
    BL      Init_Display

    ; 2. Inicializar variaveis principais
    MOV     R4, #0
    MOV     R5, #1
    MOV     R9, #1                  ; botoes soltos (SW1 = 1, SW2 = 2)
    MOV     R10, #2

MainLoop
    ; --- A. Define o estado dos LEDs para o numero atual ---
    MOV     R0, R4
    BL      VerificarPrimo          ; R0 = 1 se primo, 0 se nao
    CMP     R0, #1
    BNE     NaoPrimo

    MOV     R6, #LEDS_PRIMO         ; primo: todos os LEDs acesos
    B       Exibe

NaoPrimo
    MOV     R6, #LEDS_NAO_PRIMO     ; nao primo: LEDs alternados

Exibe
    MOV     R7, #CICLOS_POR_NUMERO

LoopExibe
    ; --- B. Um ciclo de multiplexacao dos displays e dos LEDs ---
    MOV     R0, R4
    MOV     R1, R6
    BL      Varredura_Display

    ; --- C. USR_SW1: aumenta o passo (so na borda de descida) ---
    BL      Read_USR_SW1
    MOV     R1, R0
    CMP     R1, #0
    BNE     FimSW1                  ; solto
    CMP     R9, #0
    BEQ     FimSW1                  ; ja estava pressionado
    CMP     R5, #9
    BGE     FimSW1                  ; passo maximo
    ADD     R5, R5, #1
FimSW1
    MOV     R9, R1

    ; --- D. USR_SW2: diminui o passo (so na borda de descida) ---
    BL      Read_USR_SW2
    MOV     R1, R0
    CMP     R1, #0
    BNE     FimSW2
    CMP     R10, #0
    BEQ     FimSW2
    CMP     R5, #1
    BLE     FimSW2                  ; passo minimo
    SUB     R5, R5, #1
FimSW2
    MOV     R10, R1

    SUBS    R7, R7, #1
    BNE     LoopExibe

    ; --- E. Proximo numero, com modulo 100 ---
    ADD     R4, R4, R5
    CMP     R4, #100
    BLT     MainLoop
    SUB     R4, R4, #100            ; passo maximo e 9, uma subtracao basta
    B       MainLoop

    ALIGN
    END
