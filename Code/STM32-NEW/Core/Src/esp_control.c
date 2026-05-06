#include "esp_control.h"
#include "main.h"

#define ESP_MUX_STM_LEVEL GPIO_PIN_RESET
#define ESP_MUX_ESP_LEVEL GPIO_PIN_SET

static uint8_t esp_enabled;
static EspBootMode esp_boot_mode = ESP_BOOTMODE_APP;
static EspMuxRoute esp_mux_route = ESP_MUX_ROUTE_STM;

void EspControl_SetEnabled(uint8_t enabled)
{
    esp_enabled = (enabled != 0U) ? 1U : 0U;
    HAL_GPIO_WritePin(ESP_EN_GPIO_Port, ESP_EN_Pin, esp_enabled ? GPIO_PIN_SET : GPIO_PIN_RESET);
}

void EspControl_SetBootMode(EspBootMode mode)
{
    esp_boot_mode = mode;

    /* ESP boot strap defaults to app mode when BOOT stays high. */
    HAL_GPIO_WritePin(ESP_BOOT_GPIO_Port,
                      ESP_BOOT_Pin,
                      (mode == ESP_BOOTMODE_FLASH) ? GPIO_PIN_RESET : GPIO_PIN_SET);
}

void EspControl_SetMuxRoute(EspMuxRoute route)
{
    esp_mux_route = route;

    /*
     * Current bring-up assumption:
     * BUS_SELECT low routes USB-UART toward STM32.
     * If hardware validation proves the opposite, only these levels should change.
     */
    HAL_GPIO_WritePin(BUS_SELECT_GPIO_Port,
                      BUS_SELECT_Pin,
                      (route == ESP_MUX_ROUTE_ESP) ? ESP_MUX_ESP_LEVEL : ESP_MUX_STM_LEVEL);
}

void EspControl_InitSafeDefaults(void)
{
    EspControl_SetBootMode(ESP_BOOTMODE_APP);
    EspControl_SetMuxRoute(ESP_MUX_ROUTE_STM);
    EspControl_SetEnabled(0U);

    HAL_GPIO_WritePin(ESP_MODE0_GPIO_Port, ESP_MODE0_Pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(ESP_MODE1_GPIO_Port, ESP_MODE1_Pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(MUS_STATUS_GPIO_Port, MUS_STATUS_Pin, GPIO_PIN_RESET);
}

EspControlSnapshot EspControl_GetSnapshot(void)
{
    EspControlSnapshot snapshot;

    snapshot.bootMode = esp_boot_mode;
    snapshot.muxRoute = esp_mux_route;
    snapshot.enabled = esp_enabled;
    snapshot.dtr = HAL_GPIO_ReadPin(DTR_GPIO_Port, DTR_Pin);
    snapshot.rts = HAL_GPIO_ReadPin(RTS_GPIO_Port, RTS_Pin);
    snapshot.bootDebugSwitch = HAL_GPIO_ReadPin(BOOT_DEBUG_GPIO_Port, BOOT_DEBUG_Pin);

    return snapshot;
}

const char *EspControl_BootModeLabel(EspBootMode mode)
{
    switch (mode)
    {
        case ESP_BOOTMODE_FLASH:
            return "flash";
        case ESP_BOOTMODE_APP:
        default:
            return "app";
    }
}

const char *EspControl_MuxRouteLabel(EspMuxRoute route)
{
    switch (route)
    {
        case ESP_MUX_ROUTE_ESP:
            return "esp";
        case ESP_MUX_ROUTE_STM:
        default:
            return "stm";
    }
}
