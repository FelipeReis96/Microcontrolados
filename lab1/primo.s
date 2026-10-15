; Exemplo.s
; Desenvolvido para a placa EK-TM4C1294XL
; Prof. Guilherme Peron
; 12/03/2018

; -------------------------------------------------------------------------------
        THUMB                        ; Instruções do tipo Thumb-2
; -------------------------------------------------------------------------------
; Declarações EQU - Defines
;<NOME>         EQU <VALOR>
LISTA_ALEATORIA EQU 0x20000300
LISTA_ORDENADA  EQU 0x20000400
TOTAL_ELEM  EQU 97
; -------------------------------------------------------------------------------
; Área de Dados - Declarações de variáveis
		AREA  DATA, ALIGN=2
        EXPORT  VerificarPrimo
		; Se alguma variável for chamada em outro arquivo
		;EXPORT  <var> [DATA,SIZE=<tam>]   ; Permite chamar a variável <var> a 
		                                   ; partir de outro arquivo
;<var>	SPACE <tam>                        ; Declara uma variável de nome <var>
                                           ; de <tam> bytes a partir da primeira 
                                           ; posição da RAM		

; -------------------------------------------------------------------------------

		AREA    Constantes, DATA, READONLY, ALIGN=2
LISTA_NUM 
        DCB 45, 55, 32, 48, 120, 119, 49, 9, 75, 3, 124, 91, 24, 92, 16, 74, 42, 62, 100, 81, 97, 102, 95, 84, 93, 69, 46, 10, 114, 52, 78, 99, 106, 117, 57, 39, 25, 56, 64, 126, 105, 21, 63, 76, 85, 121, 12, 90, 111, 118, 125, 110, 80, 104, 8, 65, 72, 40, 30, 35, 70, 51, 86, 44, 66, 38, 82, 116, 68, 115, 36, 58, 122, 27, 60, 22, 96, 50, 108, 94, 33, 87, 2, 6, 26, 112, 98, 34, 123, 54, 20, 14, 88, 28, 77, 15, 18
; Área de Código - Tudo abaixo da diretiva a seguir será armazenado na memória de 
;                  código
        AREA    |.text|, CODE, READONLY, ALIGN=2

		; Se alguma função do arquivo for chamada em outro arquivo	
        EXPORT Start                ; Permite chamar a função Start a partir de 
			                        ; outro arquivo. No caso startup.s
									
		; Se chamar alguma função externa	
        ;IMPORT <func>              ; Permite chamar dentro deste arquivo uma 
									; função <func>

; -------------------------------------------------------------------------------
; Função main()
Start  
; Comece o código aqui <======================================================
	LDR R0, =LISTA_NUM
	LDR R1, =LISTA_ALEATORIA
	MOV R3, #TOTAL_ELEM
inserirNumeros ; Rotina para inserir números de LISTA_NUM em LISTA_ALEATORIA
        LDRB R2, [R0], #1 ; Carrega de LISTA_NUM num registrador
        STRB R2, [R1], #1 ; Escreve o valor do registrador em LISTA_ALEATORIA
        SUBS R3, R3, #1 ; Contador
        BNE  inserirNumeros

        LDR R1, =LISTA_ALEATORIA
        LDR R8, =LISTA_ORDENADA
        MOV R3, #TOTAL_ELEM
		MOV R9, #0          ; Inicializa o registrador que guardará o tamanho da lista de primos
inicio
        MOV  R4, #2 ; inicializa o divisor, vai ser usado para tirar o resto da divisão
        LDRB R5, [R1], #1 
        CMP  R5, #2  ; Compara um número de LISTA_ALEATORIA com 2, se esse número for menor que 2, não é primo
        BLT  naoPrimo

verificaPrimo
        CMP  R5, R4 ; ao rodar o loop e chegar que o número que foi pego é igual ao divisor, então esse número é primo
        BEQ  primo
        UDIV R6, R5, R4
        MLS  R7, R6, R4, R5
        CMP  R7, #0 ; pega o resto da divisão e compara se é 0, se for, o número não é primo
        BEQ  naoPrimo
        ADD  R4, R4, #1 ; adiciona 1 no divisor
        B    verificaPrimo

primo ; se for primo, adicionar em LISTA_ORDENADA
        STRB R5, [R8], #1
		ADD  R9, R9, #1 ; Incrementa o tamanho da lista de primos
        B    proximoNumero

naoPrimo ; se não for primo, avançar para próximo número em LISTA_ALEATORIA
        B    proximoNumero

proximoNumero ; quando o número não é primo, decrementa do contador e volta ao inicio do loop
        SUBS R3, R3, #1
        BNE  inicio

; --- ALGORITMO BUBBLE SORT ---
bubbleSort
        CMP  R9, #1         ; Se a lista de primos tem 0 ou 1 elementos, já está ordenada
        BLE  FIM

novaIteracao
        MOV  R10, #0        ; Registrador de flag para trocas (0 = sem troca, 1 = com troca)
        LDR  R8, =LISTA_ORDENADA ; Coloca o ponteiro no início da lista de primos
        SUB  R11, R9, #1    ; O número de comparações é (tamanho_da_lista - 1)

loopInterno
        LDRB R5, [R8]       ; Lê a primeira posição
        LDRB R6, [R8, #1]   ; Lê a segunda posição
        CMP  R5, R6         ; Compara se um número é menor que o outro
        BLE  avancar        ; Se o primeiro for o menor (ou igual), não faz nada

        STRB R6, [R8]       ; Se o segundo for o menor, troca a posição na RAM do primeiro
        STRB R5, [R8, #1]   ; Troca a posição na RAM do segundo
        MOV  R10, #1        ; Marca a flag indicando que houve troca nesta iteração

avancar
        ADD  R8, R8, #1     ; Avança o ponteiro da lista em 1 byte
        SUBS R11, R11, #1   ; Decrementa as comparações restantes nesta iteração
        BNE  loopInterno    ; Repete para todos os elementos do laço interno

        CMP  R10, #1        ; Verifica se ocorreu alguma troca durante a varredura
        BEQ  novaIteracao   ; Repete o passo anterior se a lista ainda não estiver ordenada

FIM
        B    FIM
		
    ALIGN ; garante que o fim da seção está alinhada 

    END                             ; fim do arquivo