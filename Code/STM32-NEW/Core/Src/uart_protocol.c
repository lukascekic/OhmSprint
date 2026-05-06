#include "uart_protocol.h"
#include <stdio.h>
#include <string.h>

static UART_HandleTypeDef *uart_handle;
static uint16_t sequence;

static uint8_t checksum_xor(const char *payload)
{
    uint8_t checksum = 0U;

    while ((payload != NULL) && (*payload != '\0'))
    {
        checksum ^= (uint8_t)*payload;
        payload++;
    }

    return checksum;
}

static void send_payload(const char *payload)
{
    char frame[192];
    int len;

    if ((uart_handle == NULL) || (payload == NULL))
        return;

    len = snprintf(frame, sizeof(frame), "$%s*%02X\n",
                   payload,
                   checksum_xor(payload));
    if ((len <= 0) || (len >= (int)sizeof(frame)))
        return;

    (void)HAL_UART_Transmit(uart_handle, (uint8_t *)frame, (uint16_t)len, 100U);
}

void UART_Proto_Init(UART_HandleTypeDef *huart)
{
    uart_handle = huart;
    sequence = 0U;
}

void UART_SendMeasurements(const ATM90E26_Meas *m,
                           uint32_t totalImport,
                           uint32_t totalExport,
                           uint32_t uptimeSec)
{
    char payload[160];
    int len;

    if (m == NULL)
        return;

    len = snprintf(payload, sizeof(payload),
                   "M,seq=%u,t=%lu,v=%u,i=%u,in=%u,p=%d,q=%d,s=%u,f=%u,pf=%d,ei=%lu,ee=%lu",
                   sequence++,
                   (unsigned long)uptimeSec,
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
    if ((len <= 0) || (len >= (int)sizeof(payload)))
        return;

    send_payload(payload);
}

void UART_SendEvent(const char *evType, const char *payload)
{
    char eventPayload[160];
    int len;

    len = snprintf(eventPayload, sizeof(eventPayload),
                   "E,type=%s,payload=%s",
                   (evType != NULL) ? evType : "unknown",
                   (payload != NULL) ? payload : "");
    if ((len <= 0) || (len >= (int)sizeof(eventPayload)))
        return;

    send_payload(eventPayload);
}
