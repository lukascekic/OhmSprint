#ifndef __SSD1306_H
#define __SSD1306_H

#include "stm32f1xx_hal.h"
#include <stdint.h>

#define SSD1306_WIDTH   128U
#define SSD1306_HEIGHT  64U
#define SSD1306_ADDR    0x78U

HAL_StatusTypeDef SSD1306_Init(I2C_HandleTypeDef *hi2c);
void SSD1306_Clear(void);
void SSD1306_SetCursor(uint8_t x, uint8_t y);
void SSD1306_WriteString(const char *str);
void SSD1306_Update(void);

#endif /* __SSD1306_H */
