; main.s
; Lab 3 - Bobinador com motor de passo (LCD 16x2 + teclado 4x3 + LEDs + USR_SW1)
; Placa: EK-TM4C1294XL + PAT DAELN
;
; MAQUINA DE ESTADOS (ver DET - diagrama de estados e transicoes):
;
;   INIT     --(automatico)-->  VOLTAS     zera posicao/voltas, pede o numero de voltas
;   VOLTAS   --'#' (1..10)--->  VELOC      digitos 0-9 montam o valor; '#' confirma
;   VELOC    --'1' ou '2'---->  SENTIDO    1 = passo completo, 2 = meio passo
;   SENTIDO  --'1' ou '2'---->  GIRANDO    1 = horario, 2 = anti-horario (dispara o motor)
;   GIRANDO  --passos = 0---->  FIM        (ISR do Timer2A)
;   GIRANDO  --USR_SW1------>   CANCELADO  (ISR do Port J)
;   FIM / CANCELADO --'*'--->   INIT
;   VOLTAS / VELOC / SENTIDO --'*'--> INIT
;
; Em GIRANDO o teclado nao e lido (nenhuma tecla e aceita). O movimento, a contagem
; de passos e o LED de 45 graus sao feitos na ISR do Timer2A (motor.s); aqui o laco
; so atualiza o LCD e os LEDs.
;
; Registradores: R4..R7 sao preservados pelas rotinas chamadas (lcd/teclado/leds).

ST_INIT             EQU 0
ST_VOLTAS           EQU 1
ST_VELOC            EQU 2
ST_SENTIDO          EQU 3
ST_GIRANDO          EQU 4
ST_FIM              EQU 5
ST_CANCEL           EQU 6

TECLA_NENHUMA       EQU 0xFF

        THUMB

; -----------------------------------------------------------------------------
; Textos (<= 16 caracteres por linha), terminados em 0
; -----------------------------------------------------------------------------
        AREA    Textos, DATA, READONLY, ALIGN=2
MsgVoltas1      DCB "Voltas 1-10 [#]", 0
MsgValor        DCB "Valor: ", 0
MsgEspacos      DCB "  ", 0
MsgVeloc1       DCB "Velocidade:", 0
MsgVeloc2       DCB "1=Comp  2=Meio", 0
MsgSent1        DCB "Sentido:", 0
MsgSent2        DCB "1=Hor 2=Anti-h", 0
MsgGiroHC       DCB "Horario  P.Comp.", 0
MsgGiroHM       DCB "Horario  Meio-P.", 0
MsgGiroAC       DCB "Anti-h.  P.Comp.", 0
MsgGiroAM       DCB "Anti-h.  Meio-P.", 0
MsgVoltasRest   DCB "Voltas: ", 0
MsgFim          DCB "FIM", 0
MsgCancel       DCB "CANCELADO", 0
MsgNovo         DCB "* = novo", 0
        ALIGN
; indice = sentido*2 + modo
TabMsgGiro      DCD MsgGiroHC, MsgGiroHM, MsgGiroAC, MsgGiroAM

; -----------------------------------------------------------------------------
; Escolhas do usuario (RAM)
; -----------------------------------------------------------------------------
        AREA    DadosMain, DATA, READWRITE, ALIGN=2
Voltas          SPACE   4           ; 1..10 (0 enquanto digitando)
Modo            SPACE   4           ; 0 = passo completo, 1 = meio passo
Dir             SPACE   4           ; 0 = horario, 1 = anti-horario

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Start

        IMPORT  Timer2_Init
        IMPORT  LCD_Init
        IMPORT  LCD_Clear
        IMPORT  LCD_SetCursor
        IMPORT  LCD_WriteString
        IMPORT  LCD_WriteNum
        IMPORT  Teclado_Init
        IMPORT  Teclado_Varredura
        IMPORT  Teclado_LeTecla
        IMPORT  LEDs_Init
        IMPORT  LEDs_Escreve
        IMPORT  LEDs_Apaga
        IMPORT  Motor_Init
        IMPORT  Motor_Zera
        IMPORT  Motor_Inicia
        IMPORT  Botao_Init
        IMPORT  Estado
        IMPORT  StepsRest
        IMPORT  StepsPorVolta
        IMPORT  LedIdx

; =============================================================================
Start
    BL      Motor_Init              ; antes do Timer: a ISR usa Estado
    BL      Timer2_Init             ; base de 1 ms com interrupcao (GPTM Timer2A)
    BL      LCD_Init
    BL      Teclado_Init
    BL      LEDs_Init
    BL      Botao_Init              ; USR_SW1 com interrupcao externa
    CPSIE   I                       ; habilita interrupcoes
    MOV     R0, #ST_INIT
    BL      SetEstado

; ----- despacho da maquina de estados ----------------------------------------
MainLoop
    LDR     R0, =Estado
    LDR     R0, [R0]
    CMP     R0, #ST_INIT
    BEQ     Do_Init
    CMP     R0, #ST_VOLTAS
    BEQ     Do_Voltas
    CMP     R0, #ST_VELOC
    BEQ     Do_Veloc
    CMP     R0, #ST_SENTIDO
    BEQ     Do_Sentido
    CMP     R0, #ST_GIRANDO
    BEQ     Do_Girando
    CMP     R0, #ST_FIM
    BEQ.W   Do_Fim
    CMP     R0, #ST_CANCEL
    BEQ.W   Do_Cancel
    B       Start                   ; estado invalido: reinicia

; ----- INIT: posicao 0 grau / 0 voltas, pede o numero de voltas --------------
Do_Init
    BL      Motor_Zera
    BL      LEDs_Apaga
    MOV     R0, #0
    LDR     R1, =Voltas
    STR     R0, [R1]
    BL      TelaVoltas
    MOV     R0, #ST_VOLTAS
    BL      SetEstado
    B       MainLoop

; ----- VOLTAS: digitos 0-9 montam o valor, '#' confirma ----------------------
Do_Voltas
    BL      Teclado_LeTecla         ; bloqueante, com debounce
    CMP     R0, #'*'
    BEQ.W   ToInit
    CMP     R0, #'#'
    BEQ     V_confirma
    CMP     R0, #'0'
    BLT     MainLoop
    CMP     R0, #'9'
    BGT     MainLoop
    SUB     R4, R0, #'0'            ; R4 = digito
    LDR     R5, =Voltas
    LDR     R6, [R5]
    MOV     R1, #10
    MUL     R2, R6, R1
    ADD     R2, R2, R4              ; novo = valor*10 + digito
    CMP     R2, #10
    BLE     V_ok
    CMP     R4, #0                  ; passou de 10: recomeca com o digito
    BEQ     MainLoop                ; (se for 0, ignora)
    MOV     R2, R4
V_ok
    STR     R2, [R5]
    BL      AtualizaValor
    B       MainLoop
V_confirma
    LDR     R0, =Voltas
    LDR     R0, [R0]
    CMP     R0, #1
    BLT     MainLoop                ; valor invalido: continua pedindo
    CMP     R0, #10
    BGT     MainLoop
    BL      TelaVeloc
    MOV     R0, #ST_VELOC
    BL      SetEstado
    B       MainLoop

; ----- VELOC: 1 = passo completo, 2 = meio passo -----------------------------
Do_Veloc
    BL      Teclado_LeTecla
    CMP     R0, #'*'
    BEQ.W   ToInit
    CMP     R0, #'1'
    BEQ     VL_completo
    CMP     R0, #'2'
    BNE     MainLoop
    MOV     R0, #1                  ; meio passo
    B       VL_grava
VL_completo
    MOV     R0, #0                  ; passo completo
VL_grava
    LDR     R1, =Modo
    STR     R0, [R1]
    BL      TelaSentido
    MOV     R0, #ST_SENTIDO
    BL      SetEstado
    B       MainLoop

; ----- SENTIDO: 1 = horario, 2 = anti-horario -> dispara o motor -------------
Do_Sentido
    BL      Teclado_LeTecla
    CMP     R0, #'*'
    BEQ.W   ToInit
    CMP     R0, #'1'
    BEQ     SE_horario
    CMP     R0, #'2'
    BNE     MainLoop
    MOV     R2, #1                  ; anti-horario
    B       SE_inicia
SE_horario
    MOV     R2, #0                  ; horario
SE_inicia
    LDR     R1, =Dir
    STR     R2, [R1]
    LDR     R0, =Voltas
    LDR     R0, [R0]
    LDR     R1, =Modo
    LDR     R1, [R1]
    BL      Motor_Inicia            ; R0 = voltas, R1 = modo, R2 = sentido; Estado = GIRANDO
    B       MainLoop

; ----- GIRANDO: so atualiza LCD e LEDs; teclado NAO e lido -------------------
Do_Girando
    BL      LCD_Clear
    LDR     R0, =Dir
    LDR     R0, [R0]
    LSL     R0, R0, #1
    LDR     R1, =Modo
    LDR     R1, [R1]
    ADD     R0, R0, R1              ; indice = sentido*2 + modo
    LDR     R1, =TabMsgGiro
    LDR     R4, [R1, R0, LSL #2]    ; R4 = texto "sentido + velocidade"
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    MOV     R0, R4
    BL      LCD_WriteString
    MVN     R5, #0                  ; R5 = voltas mostradas (invalido -> forca desenho)
    MOV     R6, #0
    MVN     R6, R6                  ; R6 = LED mostrado   (invalido -> forca escrita)
GL_loop
    LDR     R0, =Estado
    LDR     R0, [R0]
    CMP     R0, #ST_GIRANDO
    BNE     MainLoop                ; ISR mudou: FIM ou CANCELADO
    ; voltas restantes = teto(passos restantes / passos por volta)
    LDR     R0, =StepsRest
    LDR     R0, [R0]
    LDR     R1, =StepsPorVolta
    LDR     R1, [R1]
    ADD     R0, R0, R1
    SUB     R0, R0, #1
    UDIV    R7, R0, R1
    CMP     R7, R5
    BEQ     GL_led
    MOV     R5, R7
    MOV     R0, #1
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgVoltasRest
    BL      LCD_WriteString
    MOV     R0, R5
    BL      LCD_WriteNum
    LDR     R0, =MsgEspacos
    BL      LCD_WriteString
GL_led
    LDR     R0, =LedIdx
    LDR     R0, [R0]
    CMP     R0, R6
    BEQ     GL_loop
    MOV     R6, R0
    MOV     R1, #0x80
    LSR     R0, R1, R0              ; padrao = 0x80 >> posicao (1 LED aceso)
    BL      LEDs_Escreve
    B       GL_loop

; ----- FIM / CANCELADO: mostra a mensagem e espera '*' -----------------------
Do_Fim
    LDR     R4, =MsgFim
    B       FC_comum
Do_Cancel
    LDR     R4, =MsgCancel
FC_comum
    BL      LEDs_Apaga
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    MOV     R0, R4
    BL      LCD_WriteString
    MOV     R0, #1
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgNovo
    BL      LCD_WriteString
FC_solta                            ; descarta tecla que ficou apertada durante o giro
    BL      Teclado_Varredura
    CMP     R0, #TECLA_NENHUMA
    BNE     FC_solta
FC_espera
    BL      Teclado_LeTecla
    CMP     R0, #'*'
    BNE     FC_espera               ; so o '*' e aceito
ToInit
    MOV     R0, #ST_INIT
    BL      SetEstado
    B       MainLoop

; =============================================================================
; Sub-rotinas de apoio
; =============================================================================

; SetEstado - R0 = novo estado. Usa R1.
SetEstado
    LDR     R1, =Estado
    STR     R0, [R1]
    BX      LR

; TelaVoltas - limpa o LCD e mostra o pedido de voltas
TelaVoltas
    PUSH    {LR}
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgVoltas1
    BL      LCD_WriteString
    BL      AtualizaValor
    POP     {PC}

; AtualizaValor - linha 2: "Valor: N"
AtualizaValor
    PUSH    {LR}
    MOV     R0, #1
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgValor
    BL      LCD_WriteString
    LDR     R0, =Voltas
    LDR     R0, [R0]
    BL      LCD_WriteNum
    LDR     R0, =MsgEspacos         ; apaga sobra de "10" -> "5"
    BL      LCD_WriteString
    POP     {PC}

; TelaVeloc - pede passo completo ou meio passo
TelaVeloc
    PUSH    {LR}
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgVeloc1
    BL      LCD_WriteString
    MOV     R0, #1
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgVeloc2
    BL      LCD_WriteString
    POP     {PC}

; TelaSentido - pede horario ou anti-horario
TelaSentido
    PUSH    {LR}
    BL      LCD_Clear
    MOV     R0, #0
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgSent1
    BL      LCD_WriteString
    MOV     R0, #1
    MOV     R1, #0
    BL      LCD_SetCursor
    LDR     R0, =MsgSent2
    BL      LCD_WriteString
    POP     {PC}

    ALIGN
    END
