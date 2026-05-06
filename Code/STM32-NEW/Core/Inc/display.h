#ifndef __DISPLAY_H
#define __DISPLAY_H

#include "stm32f1xx_hal.h"
#include "atm90e26.h"

HAL_StatusTypeDef Display_Init(I2C_HandleTypeDef *hi2c);
void Display_Splash(void);
void Display_Update(const ATM90E26_Meas *m, uint32_t totalImport);
void Display_Error(const char *line1, const char *line2);

#endif /* __DISPLAY_H */
