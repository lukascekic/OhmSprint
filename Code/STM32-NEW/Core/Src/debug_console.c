#include "debug_console.h"
#include <stdio.h>
#include <string.h>

static UART_HandleTypeDef *debug_uart;
static char debug_buf[192];

static void debug_write(const char *msg)
{
    size_t len;

    if ((debug_uart == NULL) || (msg == NULL))
        return;

    len = strlen(msg);
    if (len == 0U)
        return;

    (void)HAL_UART_Transmit(debug_uart, (uint8_t *)msg, (uint16_t)len, 100U);
}

void DebugConsole_Init(UART_HandleTypeDef *huart)
{
    debug_uart = huart;
}

void DebugConsole_Log(const char *msg)
{
    debug_write(msg);
}

void DebugConsole_LogAtmError(const char *phase, ATM90E26_Status status, uint16_t sysStatus)
{
    int len = snprintf(debug_buf, sizeof(debug_buf),
                       "ATM,%s,err=%d,sys=0x%04X\r\n",
                       (phase != NULL) ? phase : "unknown",
                       status,
                       sysStatus);

    if ((len > 0) && (len < (int)sizeof(debug_buf)))
        debug_write(debug_buf);
}

void DebugConsole_LogAtmStatus(const char *phase, ATM90E26_Status status, uint16_t sysStatus)
{
    int len = snprintf(debug_buf, sizeof(debug_buf),
                       "ATM,%s,status=%d,sys=0x%04X\r\n",
                       (phase != NULL) ? phase : "unknown",
                       status,
                       sysStatus);

    if ((len > 0) && (len < (int)sizeof(debug_buf)))
        debug_write(debug_buf);
}

void DebugConsole_LogMeasurement(const ATM90E26_Meas *m,
                                 uint32_t totalImport,
                                 uint32_t totalExport,
                                 BoardPowerSource source,
                                 uint32_t uptimeSec)
{
    int len;

    if (m == NULL)
        return;

    len = snprintf(debug_buf, sizeof(debug_buf),
                   "MEAS,t=%lu,pwr=%s,v=%u,i=%u,in=%u,p=%d,q=%d,s=%u,f=%u,pf=%d,ei=%lu,ee=%lu\r\n",
                   (unsigned long)uptimeSec,
                   BoardControl_PowerSourceLabel(source),
                   m->voltage,
                   m->current,
                   m->currentN,
                   m->activePower,
                   m->reactivePower,
                   m->apparentPower,
                   m->frequency,
                   m->powerFactor,
                   (unsigned long)totalImport,
                   (unsigned long)totalExport);

    if ((len > 0) && (len < (int)sizeof(debug_buf)))
        debug_write(debug_buf);
}

void DebugConsole_LogBoardState(const BoardControlSnapshot *snapshot,
                                uint8_t senseResetPulsed)
{
    int len;

    if (snapshot == NULL)
        return;

    len = snprintf(debug_buf, sizeof(debug_buf),
                   "BOARD,pwr=%s,usbc_pg=%u,vbat_pg=%u,boot_dbg=%u,sense_rst=%u,rst_pulse=%u\r\n",
                   BoardControl_PowerSourceLabel(snapshot->powerSource),
                   (snapshot->usbcPg == GPIO_PIN_SET) ? 1U : 0U,
                   (snapshot->vbatPg == GPIO_PIN_SET) ? 1U : 0U,
                   (snapshot->bootDebug == GPIO_PIN_SET) ? 1U : 0U,
                   (snapshot->senseReset == GPIO_PIN_SET) ? 1U : 0U,
                   (senseResetPulsed != 0U) ? 1U : 0U);

    if ((len > 0) && (len < (int)sizeof(debug_buf)))
        debug_write(debug_buf);
}

void DebugConsole_LogEspState(const EspControlSnapshot *snapshot)
{
    int len;

    if (snapshot == NULL)
        return;

    len = snprintf(debug_buf, sizeof(debug_buf),
                   "ESP,en=%u,boot=%s,mux=%s,dtr=%u,rts=%u,dbg=%u\r\n",
                   snapshot->enabled,
                   EspControl_BootModeLabel(snapshot->bootMode),
                   EspControl_MuxRouteLabel(snapshot->muxRoute),
                   (snapshot->dtr == GPIO_PIN_SET) ? 1U : 0U,
                   (snapshot->rts == GPIO_PIN_SET) ? 1U : 0U,
                   (snapshot->bootDebugSwitch == GPIO_PIN_SET) ? 1U : 0U);

    if ((len > 0) && (len < (int)sizeof(debug_buf)))
        debug_write(debug_buf);
}

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
                                uint32_t cf2Delta)
{
    int len = snprintf(debug_buf, sizeof(debug_buf),
                       "IO,t=%lu,zx=%lu,irq=%lu,warn=%lu,cf1=%lu,cf2=%lu,dzx=%lu,dirq=%lu,dwarn=%lu,dcf1=%lu,dcf2=%lu\r\n",
                       (unsigned long)uptimeSec,
                       (unsigned long)zxTotal,
                       (unsigned long)irqTotal,
                       (unsigned long)warnTotal,
                       (unsigned long)cf1Total,
                       (unsigned long)cf2Total,
                       (unsigned long)zxDelta,
                       (unsigned long)irqDelta,
                       (unsigned long)warnDelta,
                       (unsigned long)cf1Delta,
                       (unsigned long)cf2Delta);

    if ((len > 0) && (len < (int)sizeof(debug_buf)))
        debug_write(debug_buf);
}
