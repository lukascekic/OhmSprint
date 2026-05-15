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

typedef enum {
    ESP_RUNMODE_NORMAL = 0,
    ESP_RUNMODE_USB_FLASH
} EspRunMode;

typedef struct {
    EspBootMode bootMode;
    EspMuxRoute muxRoute;
    EspRunMode runMode;
    GPIO_PinState dtr;
    GPIO_PinState rts;
    GPIO_PinState bootDebugSwitch;
    uint8_t enabled;
    uint8_t flashPassthroughActive;
} EspControlSnapshot;

void EspControl_Init(void);
void EspControl_InitSafeDefaults(void);
void EspControl_Task(void);
void EspControl_SetEnabled(uint8_t enabled);
void EspControl_SetBootMode(EspBootMode mode);
void EspControl_SetMuxRoute(EspMuxRoute route);
EspControlSnapshot EspControl_GetSnapshot(void);
const char *EspControl_BootModeLabel(EspBootMode mode);
const char *EspControl_MuxRouteLabel(EspMuxRoute route);
const char *EspControl_RunModeLabel(EspRunMode mode);

#endif /* __ESP_CONTROL_H */
