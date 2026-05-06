################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../Core/Src/atm90e26.c \
../Core/Src/board_control.c \
../Core/Src/debug_console.c \
../Core/Src/delay_us.c \
../Core/Src/display.c \
../Core/Src/esp_control.c \
../Core/Src/gpio.c \
../Core/Src/i2c.c \
../Core/Src/main.c \
../Core/Src/measure.pb.c \
../Core/Src/pb_common.c \
../Core/Src/pb_encode.c \
../Core/Src/spi.c \
../Core/Src/ssd1306.c \
../Core/Src/stm32f1xx_hal_msp.c \
../Core/Src/stm32f1xx_it.c \
../Core/Src/syscalls.c \
../Core/Src/sysmem.c \
../Core/Src/system_stm32f1xx.c \
../Core/Src/tim.c \
../Core/Src/uart_protocol.c \
../Core/Src/usart.c 

OBJS += \
./Core/Src/atm90e26.o \
./Core/Src/board_control.o \
./Core/Src/debug_console.o \
./Core/Src/delay_us.o \
./Core/Src/display.o \
./Core/Src/esp_control.o \
./Core/Src/gpio.o \
./Core/Src/i2c.o \
./Core/Src/main.o \
./Core/Src/measure.pb.o \
./Core/Src/pb_common.o \
./Core/Src/pb_encode.o \
./Core/Src/spi.o \
./Core/Src/ssd1306.o \
./Core/Src/stm32f1xx_hal_msp.o \
./Core/Src/stm32f1xx_it.o \
./Core/Src/syscalls.o \
./Core/Src/sysmem.o \
./Core/Src/system_stm32f1xx.o \
./Core/Src/tim.o \
./Core/Src/uart_protocol.o \
./Core/Src/usart.o 

C_DEPS += \
./Core/Src/atm90e26.d \
./Core/Src/board_control.d \
./Core/Src/debug_console.d \
./Core/Src/delay_us.d \
./Core/Src/display.d \
./Core/Src/esp_control.d \
./Core/Src/gpio.d \
./Core/Src/i2c.d \
./Core/Src/main.d \
./Core/Src/measure.pb.d \
./Core/Src/pb_common.d \
./Core/Src/pb_encode.d \
./Core/Src/spi.d \
./Core/Src/ssd1306.d \
./Core/Src/stm32f1xx_hal_msp.d \
./Core/Src/stm32f1xx_it.d \
./Core/Src/syscalls.d \
./Core/Src/sysmem.d \
./Core/Src/system_stm32f1xx.d \
./Core/Src/tim.d \
./Core/Src/uart_protocol.d \
./Core/Src/usart.d 


# Each subdirectory must supply rules for building sources it contributes
Core/Src/%.o Core/Src/%.su Core/Src/%.cyclo: ../Core/Src/%.c Core/Src/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m3 -std=gnu11 -g3 -DDEBUG -DUSE_HAL_DRIVER -DSTM32F103xB -c -I../Core/Inc -I../Drivers/STM32F1xx_HAL_Driver/Inc -I../Drivers/STM32F1xx_HAL_Driver/Inc/Legacy -I../Drivers/CMSIS/Device/ST/STM32F1xx/Include -I../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfloat-abi=soft -mthumb -o "$@"

clean: clean-Core-2f-Src

clean-Core-2f-Src:
	-$(RM) ./Core/Src/atm90e26.cyclo ./Core/Src/atm90e26.d ./Core/Src/atm90e26.o ./Core/Src/atm90e26.su ./Core/Src/board_control.cyclo ./Core/Src/board_control.d ./Core/Src/board_control.o ./Core/Src/board_control.su ./Core/Src/debug_console.cyclo ./Core/Src/debug_console.d ./Core/Src/debug_console.o ./Core/Src/debug_console.su ./Core/Src/delay_us.cyclo ./Core/Src/delay_us.d ./Core/Src/delay_us.o ./Core/Src/delay_us.su ./Core/Src/display.cyclo ./Core/Src/display.d ./Core/Src/display.o ./Core/Src/display.su ./Core/Src/esp_control.cyclo ./Core/Src/esp_control.d ./Core/Src/esp_control.o ./Core/Src/esp_control.su ./Core/Src/gpio.cyclo ./Core/Src/gpio.d ./Core/Src/gpio.o ./Core/Src/gpio.su ./Core/Src/i2c.cyclo ./Core/Src/i2c.d ./Core/Src/i2c.o ./Core/Src/i2c.su ./Core/Src/main.cyclo ./Core/Src/main.d ./Core/Src/main.o ./Core/Src/main.su ./Core/Src/measure.pb.cyclo ./Core/Src/measure.pb.d ./Core/Src/measure.pb.o ./Core/Src/measure.pb.su ./Core/Src/pb_common.cyclo ./Core/Src/pb_common.d ./Core/Src/pb_common.o ./Core/Src/pb_common.su ./Core/Src/pb_encode.cyclo ./Core/Src/pb_encode.d ./Core/Src/pb_encode.o ./Core/Src/pb_encode.su ./Core/Src/spi.cyclo ./Core/Src/spi.d ./Core/Src/spi.o ./Core/Src/spi.su ./Core/Src/ssd1306.cyclo ./Core/Src/ssd1306.d ./Core/Src/ssd1306.o ./Core/Src/ssd1306.su ./Core/Src/stm32f1xx_hal_msp.cyclo ./Core/Src/stm32f1xx_hal_msp.d ./Core/Src/stm32f1xx_hal_msp.o ./Core/Src/stm32f1xx_hal_msp.su ./Core/Src/stm32f1xx_it.cyclo ./Core/Src/stm32f1xx_it.d ./Core/Src/stm32f1xx_it.o ./Core/Src/stm32f1xx_it.su ./Core/Src/syscalls.cyclo ./Core/Src/syscalls.d ./Core/Src/syscalls.o ./Core/Src/syscalls.su ./Core/Src/sysmem.cyclo ./Core/Src/sysmem.d ./Core/Src/sysmem.o ./Core/Src/sysmem.su ./Core/Src/system_stm32f1xx.cyclo ./Core/Src/system_stm32f1xx.d ./Core/Src/system_stm32f1xx.o ./Core/Src/system_stm32f1xx.su ./Core/Src/tim.cyclo ./Core/Src/tim.d ./Core/Src/tim.o ./Core/Src/tim.su ./Core/Src/uart_protocol.cyclo ./Core/Src/uart_protocol.d ./Core/Src/uart_protocol.o ./Core/Src/uart_protocol.su ./Core/Src/usart.cyclo ./Core/Src/usart.d ./Core/Src/usart.o ./Core/Src/usart.su

.PHONY: clean-Core-2f-Src

