#include "display.h"
#include "ssd1306.h"
#include <stdio.h>

static char buf[22];
static uint8_t display_ready;

HAL_StatusTypeDef Display_Init(I2C_HandleTypeDef *hi2c)
{
    HAL_StatusTypeDef status = SSD1306_Init(hi2c);
    display_ready = (status == HAL_OK) ? 1U : 0U;
    return status;
}

void Display_Splash(void)
{
    if (display_ready == 0U)
        return;

    SSD1306_Clear();
    SSD1306_SetCursor(16U, 2U);
    SSD1306_WriteString("OhmSprint v1.0");
    SSD1306_SetCursor(10U, 4U);
    SSD1306_WriteString("Initializing...");
    SSD1306_Update();
}

void Display_Update(const ATM90E26_Meas *m, uint32_t totalImport)
{
    int16_t pf;
    uint16_t apf;

    if ((display_ready == 0U) || (m == NULL))
        return;

    pf = m->powerFactor;
    apf = (pf < 0) ? (uint16_t)(-(int32_t)pf) : (uint16_t)pf;

    SSD1306_Clear();

    SSD1306_SetCursor(0U, 0U);
    snprintf(buf, sizeof(buf), "V:%4u.%02u V", m->voltage / 100U, m->voltage % 100U);
    SSD1306_WriteString(buf);

    SSD1306_SetCursor(0U, 1U);
    snprintf(buf, sizeof(buf), "I:%2u.%03u A", m->current / 1000U, m->current % 1000U);
    SSD1306_WriteString(buf);

    SSD1306_SetCursor(0U, 2U);
    snprintf(buf, sizeof(buf), "P:%6d W", m->activePower);
    SSD1306_WriteString(buf);

    SSD1306_SetCursor(0U, 3U);
    snprintf(buf, sizeof(buf), "Q:%5d VAR", m->reactivePower);
    SSD1306_WriteString(buf);

    SSD1306_SetCursor(0U, 4U);
    snprintf(buf, sizeof(buf), "f:%3u.%02u Hz", m->frequency / 100U, m->frequency % 100U);
    SSD1306_WriteString(buf);

    SSD1306_SetCursor(0U, 5U);
    snprintf(buf, sizeof(buf), "PF:%s%u.%03u",
             (pf < 0) ? "-" : " ", apf / 1000U, apf % 1000U);
    SSD1306_WriteString(buf);

    SSD1306_SetCursor(0U, 6U);
    snprintf(buf, sizeof(buf), "E:%lu.%04lu kWh",
             (unsigned long)(totalImport / 10000UL),
             (unsigned long)(totalImport % 10000UL));
    SSD1306_WriteString(buf);

    SSD1306_SetCursor(0U, 7U);
    snprintf(buf, sizeof(buf), "In:%u.%03u A", m->currentN / 1000U, m->currentN % 1000U);
    SSD1306_WriteString(buf);

    SSD1306_Update();
}

void Display_Error(const char *line1, const char *line2)
{
    if (display_ready == 0U)
        return;

    SSD1306_Clear();
    SSD1306_SetCursor(0U, 2U);
    SSD1306_WriteString(line1);
    if (line2 != 0)
    {
        SSD1306_SetCursor(0U, 4U);
        SSD1306_WriteString(line2);
    }
    SSD1306_Update();
}
