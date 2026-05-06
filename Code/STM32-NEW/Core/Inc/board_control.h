#ifndef __BOARD_CONTROL_H
#define __BOARD_CONTROL_H

#include "stm32f1xx_hal.h"

typedef enum {
    BOARD_POWER_NONE = 0,
    BOARD_POWER_VBAT,
    BOARD_POWER_USBC,
    BOARD_POWER_BOTH
} BoardPowerSource;

typedef struct {
    BoardPowerSource powerSource;
    GPIO_PinState usbcPg;
    GPIO_PinState vbatPg;
    GPIO_PinState bootDebug;
    GPIO_PinState senseReset;
} BoardControlSnapshot;

void BoardControl_ApplyBringupDefaults(void);
void BoardControl_ResetSensing(void);
BoardPowerSource BoardControl_GetPowerSource(void);
BoardControlSnapshot BoardControl_GetSnapshot(void);
const char *BoardControl_PowerSourceLabel(BoardPowerSource source);

#endif /* __BOARD_CONTROL_H */
