#ifndef __ESP_CONTROL_H
#define __ESP_CONTROL_H

#include "stm32f1xx_hal.h"

typedef enum {
    ESP_BOOTMODE_APP = 0,
    ESP_BOOTMODE_FLASH
} EspBootMode;

typedef enum {
    ESP_MUX_ROUTE_STM = 0,
    ESP_MUX_ROUTE_ESP
} EspMuxRoute;

typedef struct {
    EspBootMode bootMode;
    EspMuxRoute muxRoute;
    GPIO_PinState dtr;
    GPIO_PinState rts;
    GPIO_PinState bootDebugSwitch;
    uint8_t enabled;
} EspControlSnapshot;

void EspControl_InitSafeDefaults(void);
void EspControl_SetEnabled(uint8_t enabled);
void EspControl_SetBootMode(EspBootMode mode);
void EspControl_SetMuxRoute(EspMuxRoute route);
EspControlSnapshot EspControl_GetSnapshot(void);
const char *EspControl_BootModeLabel(EspBootMode mode);
const char *EspControl_MuxRouteLabel(EspMuxRoute route);

#endif /* __ESP_CONTROL_H */
