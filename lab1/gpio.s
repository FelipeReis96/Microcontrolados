
        THUMB                        


SYSCTL_RCGCGPIO_R   EQU 0x400FE608
SYSCTL_PRGPIO_R     EQU 0x400FEA08
GPIO_PORTJ_AHB_BASE EQU 0x40060000
GPIO_O_DIR          EQU 0x00000400
GPIO_O_PUR          EQU 0x00000510
GPIO_O_DEN          EQU 0x0000051C
GPIO_O_DATA         EQU 0x000003FC


        AREA    |.text|, CODE, READONLY, ALIGN=2

        ; Exportar as funções para que o main.s consiga chamá-las
        EXPORT Init_Buttons_PortJ
        EXPORT Read_USR_SW1
        EXPORT Read_USR_SW2


Init_Buttons_PortJ
    ; 1. Habilitar o clock da Porta J (bit 8)
    LDR     R1, =SYSCTL_RCGCGPIO_R
    LDR     R0, [R1]
    ORR     R0, R0, #0x00000100
    STR     R0, [R1]
    
    ; 2. Esperar o clock estabilizar usando SYSCTL_PRGPIO_R
    LDR     R1, =SYSCTL_PRGPIO_R
WaitGPIOJ
    LDR     R0, [R1]
    AND     R0, R0, #0x00000100
    CMP     R0, #0
    BEQ     WaitGPIOJ
    
    ; 3. Configurar PJ0 e PJ1 como entrada (DIR = 0 nos bits 0 e 1)
    LDR     R1, =(GPIO_PORTJ_AHB_BASE + GPIO_O_DIR)
    LDR     R0, [R1]
    BIC     R0, R0, #0x03       ; Limpa os bits 0 e 1 (0x03 = binário 11)
    STR     R0, [R1]
    
    ; 4. Habilitar Pull-Up em PJ0 e PJ1 (PUR = 1)
    LDR     R1, =(GPIO_PORTJ_AHB_BASE + GPIO_O_PUR)
    LDR     R0, [R1]
    ORR     R0, R0, #0x03       ; Seta os bits 0 e 1
    STR     R0, [R1]
    
    ; 5. Habilitar função digital em PJ0 e PJ1 (DEN = 1)
    LDR     R1, =(GPIO_PORTJ_AHB_BASE + GPIO_O_DEN)
    LDR     R0, [R1]
    ORR     R0, R0, #0x03       ; Seta os bits 0 e 1
    STR     R0, [R1]
    
    BX      R14                 ; Retorna para a função que chamou (equivalente a BX LR)


Read_USR_SW1
    LDR     R1, =(GPIO_PORTJ_AHB_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #0x01       ; Isola apenas o bit 0
    BX      R14


Read_USR_SW2
    LDR     R1, =(GPIO_PORTJ_AHB_BASE + GPIO_O_DATA)
    LDR     R0, [R1]
    AND     R0, R0, #0x02       ; Isola apenas o bit 1
    BX      R14

    ALIGN                       ; Garante alinhamento correto da memória
    END                         ; Fim do ficheiro