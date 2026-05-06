/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.h
  * @brief          : Header for main.c file.
  *                   This file contains the common defines of the application.
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

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32f1xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

/* Exported functions prototypes ---------------------------------------------*/
void Error_Handler(void);

/* USER CODE BEGIN EFP */

/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
#define WIFI_ONOFF_Pin GPIO_PIN_13
#define WIFI_ONOFF_GPIO_Port GPIOC
#define BOOT_DEBUG_Pin GPIO_PIN_14
#define BOOT_DEBUG_GPIO_Port GPIOC
#define SENSE_RST_Pin GPIO_PIN_15
#define SENSE_RST_GPIO_Port GPIOC
#define OSC_IN_Pin GPIO_PIN_0
#define OSC_IN_GPIO_Port GPIOD
#define OSC_OUT_Pin GPIO_PIN_1
#define OSC_OUT_GPIO_Port GPIOD
#define BUZZER_Pin GPIO_PIN_0
#define BUZZER_GPIO_Port GPIOA
#define ESP_UART_TX_Pin GPIO_PIN_2
#define ESP_UART_TX_GPIO_Port GPIOA
#define ESP_UART_RX_Pin GPIO_PIN_3
#define ESP_UART_RX_GPIO_Port GPIOA
#define ATM_CS_Pin GPIO_PIN_4
#define ATM_CS_GPIO_Port GPIOA
#define ZX_Pin GPIO_PIN_0
#define ZX_GPIO_Port GPIOB
#define IRQ_Pin GPIO_PIN_1
#define IRQ_GPIO_Port GPIOB
#define WARN_OUT_Pin GPIO_PIN_2
#define WARN_OUT_GPIO_Port GPIOB
#define CF2_Pin GPIO_PIN_10
#define CF2_GPIO_Port GPIOB
#define CF1_Pin GPIO_PIN_11
#define CF1_GPIO_Port GPIOB
#define VBAT_PG_Pin GPIO_PIN_12
#define VBAT_PG_GPIO_Port GPIOB
#define USBC_PG_Pin GPIO_PIN_13
#define USBC_PG_GPIO_Port GPIOB
#define DTR_Pin GPIO_PIN_8
#define DTR_GPIO_Port GPIOA
#define STM_TX_Pin GPIO_PIN_9
#define STM_TX_GPIO_Port GPIOA
#define STM_RX_Pin GPIO_PIN_10
#define STM_RX_GPIO_Port GPIOA
#define BUS_SELECT_Pin GPIO_PIN_11
#define BUS_SELECT_GPIO_Port GPIOA
#define RTS_Pin GPIO_PIN_12
#define RTS_GPIO_Port GPIOA
#define SWD_IO_Pin GPIO_PIN_13
#define SWD_IO_GPIO_Port GPIOA
#define SWD_CLK_Pin GPIO_PIN_14
#define SWD_CLK_GPIO_Port GPIOA
#define ESP_BOOT_Pin GPIO_PIN_15
#define ESP_BOOT_GPIO_Port GPIOA
#define MUS_STATUS_Pin GPIO_PIN_3
#define MUS_STATUS_GPIO_Port GPIOB
#define ESP_MODE0_Pin GPIO_PIN_4
#define ESP_MODE0_GPIO_Port GPIOB
#define ESP_MODE1_Pin GPIO_PIN_5
#define ESP_MODE1_GPIO_Port GPIOB
#define OLED_SCK_Pin GPIO_PIN_6
#define OLED_SCK_GPIO_Port GPIOB
#define OLED_SDA_Pin GPIO_PIN_7
#define OLED_SDA_GPIO_Port GPIOB
#define ESP_EN_Pin GPIO_PIN_9
#define ESP_EN_GPIO_Port GPIOB

/* USER CODE BEGIN Private defines */

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
