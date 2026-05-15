#include "board_control.h"
#include "delay_us.h"
#include "esp_control.h"
#include "main.h"

void BoardControl_ApplyBringupDefaults(void)
{
    HAL_GPIO_WritePin(ATM_CS_GPIO_Port, ATM_CS_Pin, GPIO_PIN_SET);
    HAL_GPIO_WritePin(SENSE_RST_GPIO_Port, SENSE_RST_Pin, GPIO_PIN_SET);
    EspControl_Init();
}

void BoardControl_ResetSensing(void)
{
    HAL_GPIO_WritePin(SENSE_RST_GPIO_Port, SENSE_RST_Pin, GPIO_PIN_RESET);
    delay_us(20U);
    HAL_GPIO_WritePin(SENSE_RST_GPIO_Port, SENSE_RST_Pin, GPIO_PIN_SET);
    delay_us(200U);
}

BoardPowerSource BoardControl_GetPowerSource(void)
{
    GPIO_PinState usbc = HAL_GPIO_ReadPin(USBC_PG_GPIO_Port, USBC_PG_Pin);
    GPIO_PinState vbat = HAL_GPIO_ReadPin(VBAT_PG_GPIO_Port, VBAT_PG_Pin);

    if ((usbc == GPIO_PIN_SET) && (vbat == GPIO_PIN_SET))
        return BOARD_POWER_BOTH;
    if (usbc == GPIO_PIN_SET)
        return BOARD_POWER_USBC;
    if (vbat == GPIO_PIN_SET)
        return BOARD_POWER_VBAT;
    return BOARD_POWER_NONE;
}

BoardControlSnapshot BoardControl_GetSnapshot(void)
{
    BoardControlSnapshot snapshot;

    snapshot.usbcPg = HAL_GPIO_ReadPin(USBC_PG_GPIO_Port, USBC_PG_Pin);
    snapshot.vbatPg = HAL_GPIO_ReadPin(VBAT_PG_GPIO_Port, VBAT_PG_Pin);
    snapshot.bootDebug = HAL_GPIO_ReadPin(BOOT_DEBUG_GPIO_Port, BOOT_DEBUG_Pin);
    snapshot.senseReset = HAL_GPIO_ReadPin(SENSE_RST_GPIO_Port, SENSE_RST_Pin);

    if ((snapshot.usbcPg == GPIO_PIN_SET) && (snapshot.vbatPg == GPIO_PIN_SET))
        snapshot.powerSource = BOARD_POWER_BOTH;
    else if (snapshot.usbcPg == GPIO_PIN_SET)
        snapshot.powerSource = BOARD_POWER_USBC;
    else if (snapshot.vbatPg == GPIO_PIN_SET)
        snapshot.powerSource = BOARD_POWER_VBAT;
    else
        snapshot.powerSource = BOARD_POWER_NONE;

    return snapshot;
}

const char *BoardControl_PowerSourceLabel(BoardPowerSource source)
{
    switch (source)
    {
        case BOARD_POWER_USBC:
            return "usbc";
        case BOARD_POWER_VBAT:
            return "vbat";
        case BOARD_POWER_BOTH:
            return "both";
        case BOARD_POWER_NONE:
        default:
            return "none";
    }
}
