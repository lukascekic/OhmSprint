#include "delay_us.h"

static uint8_t dwt_available = 0U;

void DWT_Init(void)
{
    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
    DWT->CYCCNT = 0U;
    DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;

    {
        uint32_t start = DWT->CYCCNT;
        __NOP();
        __NOP();
        __NOP();
        __NOP();
        dwt_available = (DWT->CYCCNT != start) ? 1U : 0U;
    }
}

void delay_us(uint32_t us)
{
    if (dwt_available != 0U)
    {
        uint32_t start = DWT->CYCCNT;
        uint32_t ticks = us * (SystemCoreClock / 1000000U);
        while ((DWT->CYCCNT - start) < ticks)
        {
        }
    }
    else
    {
        uint32_t ticks = us * (SystemCoreClock / 1000000U);
        uint32_t iterations = (ticks + 3U) / 4U;
        volatile uint32_t i;

        for (i = 0U; i < iterations; i++)
        {
        }
    }
}

uint32_t micros(void)
{
    if (dwt_available != 0U)
        return DWT->CYCCNT / (SystemCoreClock / 1000000U);

    return HAL_GetTick() * 1000U;
}
