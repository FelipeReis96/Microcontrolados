; Exemplo.s
; Desenvolvido para a placa EK-TM4C1294XL
; Prof. Guilherme Peron
; 12/03/2018

; -------------------------------------------------------------------------------
        THUMB                        ; Instruções do tipo Thumb-2
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
; Área de Código - Tudo abaixo da diretiva a seguir será armazenado na memória de
;                  código
        AREA    |.text|, CODE, READONLY, ALIGN=2

; -------------------------------------------------------------------------------
; VerificarPrimo
; Entrada: R0 = número a ser testado
; Saída:   R0 = 1 se o número for primo, 0 se não for
VerificarPrimo
        PUSH {R4-R7}        ; preserva os registradores usados pelo main
        MOV  R5, R0         ; R5 recebe o número
        MOV  R4, #2 ; inicializa o divisor, vai ser usado para tirar o resto da divisão
        CMP  R5, #2  ; Compara o número com 2, se esse número for menor que 2, não é primo
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

primo ; é primo, devolve 1
        MOV  R0, #1
        B    fimVerificar

naoPrimo ; não é primo, devolve 0
        MOV  R0, #0

fimVerificar
        POP  {R4-R7}
        BX   R14

    ALIGN ; garante que o fim da seção está alinhada

    END                             ; fim do arquivo
