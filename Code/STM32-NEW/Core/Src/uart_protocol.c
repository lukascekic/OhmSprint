#include "uart_protocol.h"
#include "debug_console.h"
#include "measure.pb.h"
#include "pb_encode.h"
#include <string.h>

static UART_HandleTypeDef *uart_handle;

void UART_Proto_Init(UART_HandleTypeDef *huart)
{
    uart_handle = huart;
}

void UART_SendMeasurements(const ATM90E26_Meas *m,
                           uint32_t totalImport,
                           uint32_t totalExport,
                           uint32_t uptimeSec)
{
    MeasureData msg = MeasureData_init_zero;
    uint8_t payload[MeasureData_size];
    uint8_t frame[4U + MeasureData_size];
    pb_ostream_t stream = pb_ostream_from_buffer(payload, sizeof(payload));
    uint32_t len;

    (void)totalExport;
    (void)uptimeSec;

    if ((uart_handle == NULL) || (m == NULL))
        return;

    msg.current = (float)m->current / 1000.0f;
    msg.voltage = (float)m->voltage / 100.0f;
    msg.power = (float)m->activePower;
    msg.frequency = (float)m->frequency / 100.0f;
    msg.power_usage = (float)totalImport * 0.0001f;
    msg.sd_logs_enable = true;
    msg.wifi_enable = true;

    if (!pb_encode(&stream, MeasureData_fields, &msg))
        return;

    len = (uint32_t)stream.bytes_written;
    frame[0] = (uint8_t)((len >> 24) & 0xFFU);
    frame[1] = (uint8_t)((len >> 16) & 0xFFU);
    frame[2] = (uint8_t)((len >> 8) & 0xFFU);
    frame[3] = (uint8_t)(len & 0xFFU);
    memcpy(&frame[4], payload, len);

    if (HAL_UART_Transmit(uart_handle, frame, (uint16_t)(4U + len), 100U) == HAL_OK)
        DebugConsole_LogUartTx(4U + len);
}

void UART_SendEvent(const char *evType, const char *payload)
{
    (void)evType;
    (void)payload;
}
