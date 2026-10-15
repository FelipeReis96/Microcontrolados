
        THUMB                        

        AREA    |.text|, CODE, READONLY, ALIGN=2

        EXPORT  Start


        IMPORT  Init_Buttons_PortJ
        IMPORT  Read_USR_SW1
        IMPORT  Read_USR_SW2
        IMPORT  VerificarPrimo


Start
    ; 1. Inicializar o hardware dos botões da Porta J
    BL      Init_Buttons_PortJ   

    ; 2. Processar a lista de primos e ordenação apenas uma vez no arranque
    BL      VerificarPrimo

    ; 3. Inicializar variáveis principais
    MOV     R4, #0               ; R4 = Valor do contador (0 a 99)
    MOV     R5, #1               ; R5 = Passo atual (começa em 1)
    MOV     R8, #0               ; R8 = Flag para alternar os LEDs de primos

MainLoop
    ; --- A. Incremento automático da contagem com o passo atual ---
    ADD     R4, R4, R5           
    CMP     R4, #99              
    BLE     TestarPrimo    
    MOV     R4, #0               ; Recomeça em 0 se passar de 99

TestarPrimo
    ; 2. Testa se o número atual (em R4) é primo
    MOV     R0, R4               
    BL      VerificarPrimo       ; Retorna em R0: 1 (é primo) ou 0 (não é)
    
    CMP     R0, #1
    BEQ     Primo        

    ; Se NÃO for primo: mantém os LEDs apagados
    MOV     R6, #0               
    B       SairLogicaPrimos

Primo
    ; Se FOR primo: inverte a flag (0 vira 1, 1 vira 0) para alternar os LEDs
    EOR     R8, R8, #1
    MOV     R6, R8   

SairLogicaPrimos


LoopBotao

    BL      Read_USR_SW1
    CMP     R0, #0
    BEQ     AumentarPasso

    BL      Read_USR_SW2
    CMP     R0, #0
    BEQ     DiminuirPasso

    BL      DelayTemporizacao
    SUBS    R7, R7, #1
    BNE     LoopBotao

    B      MainLoop


AumentarPasso
    ADD     R5, R5, #1           
    CMP     R5, #9               

    MOV     R5, #9               


DiminuirPasso
    SUB     R5, R5, #1           
    CMP     R5, #1               
    MOV     R5, #1               

    ALIGN                        
    END