#include "esp_control.h"
#include "main.h"

#define ESP_EN_ENABLED_LEVEL GPIO_PIN_SET
#define ESP_EN_DISABLED_LEVEL GPIO_PIN_RESET
#define ESP_BOOT_APP_LEVEL GPIO_PIN_SET
#define ESP_BOOT_FLASH_LEVEL GPIO_PIN_RESET
#define ESP_MUX_STM_LEVEL GPIO_PIN_RESET
#define ESP_MUX_ESP_LEVEL GPIO_PIN_SET
#define BOOT_DEBUG_USB_STM_LEVEL GPIO_PIN_RESET
#define BOOT_DEBUG_USB_ESP_LEVEL GPIO_PIN_SET
#define USB_DTR_ACTIVE_LEVEL GPIO_PIN_RESET
#define USB_RTS_ACTIVE_LEVEL GPIO_PIN_RESET
#define BOOT_DEBUG_DEBOUNCE_MS 30U

static uint8_t esp_enabled;
static EspBootMode esp_boot_mode = ESP_BOOTMODE_APP;
static EspMuxRoute esp_mux_route = ESP_MUX_ROUTE_STM;
static EspRunMode esp_run_mode = ESP_RUNMODE_NORMAL;
static uint8_t flash_passthrough_active;
static uint8_t esp_enabled_written;
static uint8_t esp_boot_mode_written;
static GPIO_PinState last_boot_debug = BOOT_DEBUG_USB_STM_LEVEL;
static GPIO_PinState stable_boot_debug = BOOT_DEBUG_USB_STM_LEVEL;
static uint32_t boot_debug_changed_tick;

static uint8_t usb_signal_active(GPIO_PinState level, GPIO_PinState activeLevel)
{
    return (level == activeLevel) ? 1U : 0U;
}

static void apply_normal_app_mode(void)
{
    flash_passthrough_active = 0U;
    esp_run_mode = ESP_RUNMODE_NORMAL;
    EspControl_SetBootMode(ESP_BOOTMODE_APP);
    EspControl_SetEnabled(1U);
}

static void apply_usb_boot_signals(void)
{
    GPIO_PinState dtr = HAL_GPIO_ReadPin(DTR_GPIO_Port, DTR_Pin);
    GPIO_PinState rts = HAL_GPIO_ReadPin(RTS_GPIO_Port, RTS_Pin);
    uint8_t dtrActive = usb_signal_active(dtr, USB_DTR_ACTIVE_LEVEL);
    uint8_t rtsActive = usb_signal_active(rts, USB_RTS_ACTIVE_LEVEL);

    flash_passthrough_active = 1U;
    esp_run_mode = ESP_RUNMODE_USB_FLASH;
    EspControl_SetBootMode((dtrActive != 0U) ? ESP_BOOTMODE_FLASH : ESP_BOOTMODE_APP);
    EspControl_SetEnabled((rtsActive != 0U) ? 0U : 1U);
}

static void apply_boot_debug_route(GPIO_PinState bootDebug)
{
    if (bootDebug == BOOT_DEBUG_USB_ESP_LEVEL)
    {
        EspControl_SetMuxRoute(ESP_MUX_ROUTE_ESP);
        apply_usb_boot_signals();
    }
    else
    {
        EspControl_SetMuxRoute(ESP_MUX_ROUTE_STM);
        apply_normal_app_mode();
    }
}

void EspControl_SetEnabled(uint8_t enabled)
{
    uint8_t requested = (enabled != 0U) ? 1U : 0U;

    if ((esp_enabled_written != 0U) && (requested == esp_enabled))
        return;

    esp_enabled = requested;
    esp_enabled_written = 1U;
    HAL_GPIO_WritePin(ESP_EN_GPIO_Port,
                      ESP_EN_Pin,
                      esp_enabled ? ESP_EN_ENABLED_LEVEL : ESP_EN_DISABLED_LEVEL);
}

void EspControl_SetBootMode(EspBootMode mode)
{
    if ((esp_boot_mode_written != 0U) && (mode == esp_boot_mode))
        return;

    esp_boot_mode = mode;
    esp_boot_mode_written = 1U;

    /* ESP boot strap defaults to app mode when BOOT stays high. */
    HAL_GPIO_WritePin(ESP_BOOT_GPIO_Port,
                      ESP_BOOT_Pin,
                      (mode == ESP_BOOTMODE_FLASH) ? ESP_BOOT_FLASH_LEVEL : ESP_BOOT_APP_LEVEL);
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

void EspControl_Init(void)
{
    GPIO_PinState bootDebug = HAL_GPIO_ReadPin(BOOT_DEBUG_GPIO_Port, BOOT_DEBUG_Pin);

    HAL_GPIO_WritePin(ESP_MODE0_GPIO_Port, ESP_MODE0_Pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(ESP_MODE1_GPIO_Port, ESP_MODE1_Pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(MUS_STATUS_GPIO_Port, MUS_STATUS_Pin, GPIO_PIN_RESET);

    last_boot_debug = bootDebug;
    stable_boot_debug = bootDebug;
    boot_debug_changed_tick = HAL_GetTick();
    apply_boot_debug_route(bootDebug);
}

void EspControl_InitSafeDefaults(void)
{
    EspControl_Init();
}

void EspControl_Task(void)
{
    GPIO_PinState bootDebug = HAL_GPIO_ReadPin(BOOT_DEBUG_GPIO_Port, BOOT_DEBUG_Pin);
    uint32_t now = HAL_GetTick();

    if (bootDebug != last_boot_debug)
    {
        last_boot_debug = bootDebug;
        boot_debug_changed_tick = now;
    }

    if ((bootDebug != stable_boot_debug) &&
        ((uint32_t)(now - boot_debug_changed_tick) >= BOOT_DEBUG_DEBOUNCE_MS))
    {
        stable_boot_debug = bootDebug;
        apply_boot_debug_route(stable_boot_debug);
    }

    if (esp_mux_route == ESP_MUX_ROUTE_ESP)
    {
        apply_usb_boot_signals();
    }
    else
    {
        apply_normal_app_mode();
    }
}

EspControlSnapshot EspControl_GetSnapshot(void)
{
    EspControlSnapshot snapshot;

    snapshot.bootMode = esp_boot_mode;
    snapshot.muxRoute = esp_mux_route;
    snapshot.runMode = esp_run_mode;
    snapshot.enabled = esp_enabled;
    snapshot.flashPassthroughActive = flash_passthrough_active;
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

const char *EspControl_RunModeLabel(EspRunMode mode)
{
    switch (mode)
    {
        case ESP_RUNMODE_USB_FLASH:
            return "usb_flash";
        case ESP_RUNMODE_NORMAL:
        default:
            return "normal";
    }
}
