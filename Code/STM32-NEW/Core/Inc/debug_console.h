#ifndef __DEBUG_CONSOLE_H
#define __DEBUG_CONSOLE_H

#include "stm32f1xx_hal.h"
#include "atm90e26.h"
#include "board_control.h"
#include "esp_control.h"

void DebugConsole_Init(UART_HandleTypeDef *huart);
void DebugConsole_Log(const char *msg);
void DebugConsole_LogAtmStatus(const char *phase, ATM90E26_Status status, uint16_t sysStatus);
void DebugConsole_LogAtmError(const char *phase, ATM90E26_Status status, uint16_t sysStatus);
void DebugConsole_LogMeasurement(const ATM90E26_Meas *m,
                                 uint32_t totalImport,
                                 uint32_t totalExport,
                                 BoardPowerSource source,
                                 uint32_t uptimeSec);
void DebugConsole_LogBoardState(const BoardControlSnapshot *snapshot,
                                uint8_t senseResetPulsed);
void DebugConsole_LogEspState(const EspControlSnapshot *snapshot);
void DebugConsole_LogAdvancedIo(uint32_t uptimeSec,
                                uint32_t zxTotal,
                                uint32_t irqTotal,
                                uint32_t warnTotal,
                                uint32_t cf1Total,
                                uint32_t cf2Total,
                                uint32_t zxDelta,
                                uint32_t irqDelta,
                                uint32_t warnDelta,
                                uint32_t cf1Delta,
                                uint32_t cf2Delta);

#endif /* __DEBUG_CONSOLE_H */
