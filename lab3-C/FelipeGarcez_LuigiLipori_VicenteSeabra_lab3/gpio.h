

#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

// Sentido de giro (sinal do avanco no indice da sequencia de meio-passo).
#define MOTOR_HORARIO       (+1)
#define MOTOR_ANTIHORARIO   (-1)

// Tamanho do avanco no indice da tabela de meio-passo:
//   PASSO_COMPLETO = 2 -> usa so os indices impares (2 bobinas = mais torque)
//   PASSO_MEIO     = 1 -> percorre todos os indices (meio-passo = mais suave)
#define PASSO_COMPLETO      2
#define PASSO_MEIO          1

// Eventos de passo por volta do eixo de saida (28BYJ-48, reducao ~1:64):
//   passo completo (avanco 2) -> 2048 eventos por volta
//   meio-passo     (avanco 1) -> 4096 eventos por volta
#define PASSOS_POR_VOLTA_COMPLETO   2048u
#define PASSOS_POR_VOLTA_MEIO       4096u


void Motor_Init(void);

// Avanca 'delta' posicoes na tabela de meio-passo (delta = sentido * tamanho,
// ou seja +1/-1 para meio-passo e +2/-2 para passo completo) e energiza as
// bobinas (PH0..PH3) com o novo padrao. Mantem o indice interno.
void Motor_Passo(int delta);

// Desenergiza as bobinas (PH0..PH3 = 0). Usar ao parar/cancelar.
void Motor_Parado(void);

// Reinicia a posicao da sequencia (indice = 0) e desliga as bobinas.
void Motor_Zera(void);

// Alinha a sequencia num indice impar (2 bobinas), necessario antes de iniciar
// um movimento em PASSO_COMPLETO para que todos os passos fiquem com 2 bobinas.
void Motor_AlinhaCompleto(void);

#endif 
