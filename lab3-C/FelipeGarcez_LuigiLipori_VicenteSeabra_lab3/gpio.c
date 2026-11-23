

#include <stdint.h>
#include "tm4c1294ncpdt.h"
#include "gpio.h"

#define MOTOR_MASK 0x0F

// Sequencia de meio-passo (bits 0..3 = PH0..PH3 = bobinas IN1..IN4).
//   indices pares  = 1 bobina  (meio-passo)
//   indices impares= 2 bobinas (passo completo, mais torque)
static const uint8_t TabPassos[8] = {
    0x01, 0x03, 0x02, 0x06, 0x04, 0x0C, 0x08, 0x09
};

// Posicao atual na sequencia (0..7).
static int seqIdx = 0;


void Motor_Init(void) {
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R7;              // clock do Port H
    while ((SYSCTL_PRGPIO_R & SYSCTL_PRGPIO_R7) == 0) {
    }
    GPIO_PORTH_AHB_AMSEL_R &= ~(MOTOR_MASK);             // desliga analogico
    GPIO_PORTH_AHB_PCTL_R  &= ~0x0000FFFF;               // funcao GPIO (PH0..PH3)
    GPIO_PORTH_AHB_DIR_R   |=  MOTOR_MASK;               // saida
    GPIO_PORTH_AHB_AFSEL_R &= ~(MOTOR_MASK);             // sem funcao alternativa
    GPIO_PORTH_AHB_DEN_R   |=  MOTOR_MASK;               // I/O digital

    seqIdx = 0;
    GPIO_PORTH_AHB_DATA_R &= ~MOTOR_MASK;                // bobinas desligadas
}

void Motor_Passo(int delta) {
    // +16 garante base positiva para delta ate -2 antes do AND (modulo 8).
    seqIdx = (seqIdx + delta + 16) & 7;
    GPIO_PORTH_AHB_DATA_R = (GPIO_PORTH_AHB_DATA_R & ~MOTOR_MASK) | TabPassos[seqIdx];
}

void Motor_Parado(void) {
    GPIO_PORTH_AHB_DATA_R &= ~MOTOR_MASK;
}

void Motor_Zera(void) {
    seqIdx = 0;
    GPIO_PORTH_AHB_DATA_R &= ~MOTOR_MASK;
}

void Motor_AlinhaCompleto(void) {
    seqIdx |= 1;                                         // indice impar -> 2 bobinas
}
