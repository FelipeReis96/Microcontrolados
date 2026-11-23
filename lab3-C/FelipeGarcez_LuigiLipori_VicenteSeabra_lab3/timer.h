

#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

#define SYSCLK_HZ   16000000u

// Converte milissegundos em contagens do Timer0A (16 MHz => 16000 ticks/ms).
// Ex.: MS_TO_TICKS(2) = 32000  -> um passo a cada 2 ms.
#define MS_TO_TICKS(ms)   ((uint32_t)(ms) * (SYSCLK_HZ / 1000u))

// Configura o Timer0A periodico com o periodo dado (em ticks), mas NAO inicia.
void Timer0A_Init(uint32_t ticks);

// Altera o periodo (velocidade do motor) em tempo de execucao.
void Timer0A_SetPeriod(uint32_t ticks);

// Liga / desliga a contagem (controla o giro do motor).
void Timer0A_Start(void);
void Timer0A_Stop(void);


extern void Timer0A_Task(void);

#endif // TIMER_H
