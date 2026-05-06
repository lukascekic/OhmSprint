/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "i2c.h"
#include "spi.h"
#include "tim.h"
#include "usart.h"
#include "gpio.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "atm90e26.h"
#include "board_control.h"
#include "debug_console.h"
#include "delay_us.h"
#include "display.h"
#include "esp_control.h"
#include "uart_protocol.h"
#include <stdio.h>

/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

#define MEASUREMENT_PERIOD_MS 1000U

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */
static ATM90E26_Dev atm_dev;
static ATM90E26_Meas meas;
static uint32_t lastMeasTick = 0U;
static uint8_t senseResetPulsed = 0U;
static volatile uint32_t zxEdgeCount = 0U;
static volatile uint32_t irqEdgeCount = 0U;
static volatile uint32_t warnEdgeCount = 0U;
static volatile uint32_t cf1PulseCount = 0U;
static volatile uint32_t cf2PulseCount = 0U;
static volatile uint8_t alertPulsePending = 0U;
static uint32_t prevZxEdgeCount = 0U;
static uint32_t prevIrqEdgeCount = 0U;
static uint32_t prevWarnEdgeCount = 0U;
static uint32_t prevCf1PulseCount = 0U;
static uint32_t prevCf2PulseCount = 0U;
static uint32_t buzzerOffTick = 0U;

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

static void ATM90E26_PrepareHardware(void)
{
  BoardControl_ApplyBringupDefaults();
  BoardControl_ResetSensing();
  senseResetPulsed = 1U;
  HAL_Delay(20U);
}

static void ShowAtmError(const char *title, const char *phase, ATM90E26_Status status)
{
  char err[22];

  snprintf(err, sizeof(err), "ERR:%d SYS:%04X", status, atm_dev.lastSysStatus);
  Display_Error(title, err);
  DebugConsole_LogAtmError(phase, status, atm_dev.lastSysStatus);
}

static HAL_StatusTypeDef AdvancedIo_Init(void)
{
  __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, 0U);

  HAL_NVIC_SetPriority(TIM2_IRQn, 5U, 0U);
  HAL_NVIC_EnableIRQ(TIM2_IRQn);

  if (HAL_TIM_PWM_Start(&htim2, TIM_CHANNEL_1) != HAL_OK)
    return HAL_ERROR;
  if (HAL_TIM_IC_Start_IT(&htim2, TIM_CHANNEL_3) != HAL_OK)
    return HAL_ERROR;
  if (HAL_TIM_IC_Start_IT(&htim2, TIM_CHANNEL_4) != HAL_OK)
    return HAL_ERROR;

  return HAL_OK;
}

static void Buzzer_StartPulse(uint32_t now, uint32_t durationMs)
{
  __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, 500U);
  buzzerOffTick = now + durationMs;
}

static void AdvancedIo_Task(uint32_t now)
{
  if (alertPulsePending != 0U)
  {
    alertPulsePending = 0U;
    Buzzer_StartPulse(now, 120U);
  }

  if ((buzzerOffTick != 0U) && ((int32_t)(now - buzzerOffTick) >= 0))
  {
    __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, 0U);
    buzzerOffTick = 0U;
  }
}

static void AdvancedIo_Log(uint32_t uptimeSec)
{
  uint32_t zx = zxEdgeCount;
  uint32_t irq = irqEdgeCount;
  uint32_t warn = warnEdgeCount;
  uint32_t cf1 = cf1PulseCount;
  uint32_t cf2 = cf2PulseCount;

  DebugConsole_LogAdvancedIo(uptimeSec,
                             zx,
                             irq,
                             warn,
                             cf1,
                             cf2,
                             zx - prevZxEdgeCount,
                             irq - prevIrqEdgeCount,
                             warn - prevWarnEdgeCount,
                             cf1 - prevCf1PulseCount,
                             cf2 - prevCf2PulseCount);

  prevZxEdgeCount = zx;
  prevIrqEdgeCount = irq;
  prevWarnEdgeCount = warn;
  prevCf1PulseCount = cf1;
  prevCf2PulseCount = cf2;
}

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_I2C1_Init();
  MX_SPI1_Init();
  MX_USART1_UART_Init();
  MX_USART2_UART_Init();
  MX_TIM2_Init();
  /* USER CODE BEGIN 2 */
  ATM90E26_Status st = ATM_ERR_COMM_VERIFY;
  BoardControlSnapshot boardSnapshot;
  EspControlSnapshot espSnapshot;
  char calLog[64];

  DWT_Init();
  ATM90E26_PrepareHardware();

  DebugConsole_Init(&huart1);
  DebugConsole_Log("BOOT,stm32-new iter5-advanced-io\r\n");
  boardSnapshot = BoardControl_GetSnapshot();
  DebugConsole_LogBoardState(&boardSnapshot, senseResetPulsed);
  espSnapshot = EspControl_GetSnapshot();
  DebugConsole_LogEspState(&espSnapshot);

  if (Display_Init(&hi2c1) == HAL_OK)
  {
    DebugConsole_Log("OLED,init,ok\r\n");
    Display_Splash();
  }
  else
  {
    DebugConsole_Log("OLED,init,err=i2c_no_ack\r\n");
  }

  if (AdvancedIo_Init() == HAL_OK)
  {
    DebugConsole_Log("IO,init,ok\r\n");
  }
  else
  {
    DebugConsole_Log("IO,init,err=tim2_start\r\n");
  }

  atm_dev.hspi = &hspi1;
  atm_dev.csPort = ATM_CS_GPIO_Port;
  atm_dev.csPin = ATM_CS_Pin;
  atm_dev.cal = ATM90E26_DefaultCal();
  atm_dev.totalImportEnergy = 0U;
  atm_dev.totalExportEnergy = 0U;
  atm_dev.lastSysStatus = 0U;
  atm_dev.initialized = 0U;
  snprintf(calLog, sizeof(calLog), "CAL,ugain=0x%04X,igainL=0x%04X\r\n",
           atm_dev.cal.ugain,
           atm_dev.cal.igainL);
  DebugConsole_Log(calLog);

  for (int retry = 0; retry < 3; retry++)
  {
    DebugConsole_Log("ATM,init,try\r\n");
    st = ATM90E26_Init(&atm_dev);
    if (st == ATM_OK)
      break;
    HAL_Delay(500U);
  }
  UART_Proto_Init(&huart2);
  lastMeasTick = HAL_GetTick();

  if (st != ATM_OK)
  {
    ShowAtmError("ATM90E26 INIT FAIL", "init", st);
  }
  else
  {
    DebugConsole_LogAtmStatus("init_ok", st, atm_dev.lastSysStatus);
  }

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
    uint32_t now = HAL_GetTick();

    AdvancedIo_Task(now);

    if ((now - lastMeasTick) >= MEASUREMENT_PERIOD_MS)
    {
      lastMeasTick += MEASUREMENT_PERIOD_MS;
      AdvancedIo_Log(now / 1000U);

      if (atm_dev.initialized != 0U)
      {
        ATM90E26_Status rs = ATM90E26_ReadAll(&atm_dev, &meas);

        if (rs != ATM_OK)
        {
          ShowAtmError("ATM90E26 READ FAIL", "read", rs);
        }
        else
        {
          BoardPowerSource power = BoardControl_GetPowerSource();

          Display_Update(&meas, atm_dev.totalImportEnergy);
          DebugConsole_LogMeasurement(&meas,
                                      atm_dev.totalImportEnergy,
                                      atm_dev.totalExportEnergy,
                                      power,
                                      now / 1000U);
          UART_SendMeasurements(&meas,
                                atm_dev.totalImportEnergy,
                                atm_dev.totalExportEnergy,
                                now / 1000U);
        }
      }
    }
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_NONE;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_HSI;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_0) != HAL_OK)
  {
    Error_Handler();
  }
}

/* USER CODE BEGIN 4 */

void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin)
{
  if (GPIO_Pin == ZX_Pin)
  {
    zxEdgeCount++;
  }
  else if (GPIO_Pin == IRQ_Pin)
  {
    irqEdgeCount++;
    alertPulsePending = 1U;
  }
  else if (GPIO_Pin == WARN_OUT_Pin)
  {
    warnEdgeCount++;
    alertPulsePending = 1U;
  }
}

void HAL_TIM_IC_CaptureCallback(TIM_HandleTypeDef *htim)
{
  if (htim->Instance != TIM2)
    return;

  if (htim->Channel == HAL_TIM_ACTIVE_CHANNEL_3)
  {
    cf2PulseCount++;
  }
  else if (htim->Channel == HAL_TIM_ACTIVE_CHANNEL_4)
  {
    cf1PulseCount++;
  }
}

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}

#ifdef  USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
