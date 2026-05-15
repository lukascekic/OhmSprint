#ifndef __DELAY_US_H
#define __DELAY_US_H

#include "stm32f1xx_hal.h"

void DWT_Init(void);
void delay_us(uint32_t us);
uint32_t micros(void);

#endif /* __DELAY_US_H */
