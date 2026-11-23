

#include <stdint.h>
#include "tm4c1294ncpdt.h"
#include "timer.h"

#define RCGCTIMER_T0        0x00000001  // Timer0 (bit 0)
#define GPTM_CFG_32BIT      0x00000000  // temporizador de 32 bits
#define GPTM_TAMR_PERIODIC  0x00000002  // TAMR = 2 (periodico)
#define GPTM_CTL_TAEN       0x00000001  // habilita o Timer A
#define GPTM_IMR_TATO       0x00000001  // interrupcao de timeout (TATOIM)
#define GPTM_ICR_TATO       0x00000001  // limpa a flag de timeout (TATOCINT)

// Timer0A = IRQ 19 (vetor 35): NVIC_EN0 bit 19; prioridade no campo 31:29 de PRI4.
#define NVIC_EN0_TIMER0A    0x00080000
#define NVIC_PRI4_TIMER0A_1 0x20000000  // prioridade 1 (alta: preempta o botao)

void Timer0A_Init(uint32_t ticks) {
    SYSCTL_RCGCTIMER_R |= RCGCTIMER_T0;                 // 1) clock do Timer0
    while ((SYSCTL_PRTIMER_R & RCGCTIMER_T0) == 0) {
    }
    TIMER0_CTL_R &= ~GPTM_CTL_TAEN;                     // 2) desabilita p/ configurar
    TIMER0_CFG_R  = GPTM_CFG_32BIT;                     // 3) 32 bits
    TIMER0_TAMR_R = GPTM_TAMR_PERIODIC;                 //    periodico
    if (ticks == 0) {
        ticks = 1;
    }
    TIMER0_TAILR_R = ticks - 1;                         //    periodo = ticks ciclos
    TIMER0_ICR_R  = GPTM_ICR_TATO;                      // 4) limpa flag
    TIMER0_IMR_R |= GPTM_IMR_TATO;                      //    habilita int de timeout
    NVIC_PRI4_R = (NVIC_PRI4_R & ~0xE0000000) | NVIC_PRI4_TIMER0A_1;
    NVIC_EN0_R  = NVIC_EN0_TIMER0A;                     //    habilita IRQ 19 no NVIC
    // TAEN fica desligado: so comeca a contar em Timer0A_Start().
}

void Timer0A_SetPeriod(uint32_t ticks) {
    if (ticks == 0) {
        ticks = 1;
    }
    TIMER0_TAILR_R = ticks - 1;
}

void Timer0A_Start(void) {
    TIMER0_ICR_R = GPTM_ICR_TATO;                       
    TIMER0_CTL_R |= GPTM_CTL_TAEN;
}

void Timer0A_Stop(void) {
    TIMER0_CTL_R &= ~GPTM_CTL_TAEN;
}

void Timer0A_Handler(void) {
    TIMER0_ICR_R = GPTM_ICR_TATO;                       // ACK obrigatorio no GPTM
    Timer0A_Task();                                     // um passo (implementado no main.c)
}
