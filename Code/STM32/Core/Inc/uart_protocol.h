#ifndef __UART_PROTOCOL_H
#define __UART_PROTOCOL_H

#include "stm32f1xx_hal.h"
#include "atm90e26.h"

void UART_Proto_Init(UART_HandleTypeDef *huart);
void UART_SendMeasurements(const ATM90E26_Meas *m,
                           uint32_t totalImport,
                           uint32_t totalExport,
                           uint32_t uptimeSec);
void UART_SendEvent(const char *evType, const char *payload);

#endif /* __UART_PROTOCOL_H */
