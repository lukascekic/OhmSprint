# STM32-NEW iter4 hardware bring-up firmware

This branch is the first hardware-testable STM32 firmware for the final
`STM32-NEW` pinout. Its purpose is to prove the local metering path on the real
PCB with a small runtime surface, while still sending ESP32-readable telemetry
if the basic STM32 + ATM90E26 path works.

Compared with iter5, this branch intentionally avoids runtime advanced I/O:
`ZX`, `IRQ`, `WARN_OUT`, `CF1`, `CF2`, and buzzer behavior are configured for
the final pinout but not actively counted or driven here.

## What This Iteration Contains

- Final CubeMX pinout in `STM32F103C8T6.ioc`.
- SWD enabled and JTAG disabled, so PA15/PB3/PB4 are available for board
  signals.
- SPI1 ATM90E26 communication using Mode 3, software NSS, and conservative
  bring-up timing.
- I2C1 OLED support with an ACK canary during display init.
- USART1 debug console for PC-side bring-up logs.
- USART2 nanopb `MeasureData` telemetry toward ESP32.
- ESP-compatible UART packet format:
  `[4-byte big-endian protobuf payload length][protobuf payload]`.
- ESP normal app boot enabled by default.
- `BOOT_DEBUG`-controlled USB-UART mux route with DTR/RTS passthrough for ESP32
  flashing.
- ATM90E26 initialization, calibration register writes, checksum verification,
  periodic measurement reads, OLED update, and USART1 measurement logs.
- Board safe-default setup for ATM CS, `SENSE_RST`, ESP control pins, and mux
  selection.

## What This Iteration Does Not Contain

- No extra magic-byte/CRC UART framing around protobuf packets.
- No ESP32 ready/ack/error command state machine.
- No runtime EXTI handling for `ZX`, `IRQ`, or `WARN_OUT`.
- No CF pulse accumulation from `CF1` / `CF2`.
- No buzzer runtime behavior.
- No STM-side persistence for accumulated energy after STM32 reset.
- No final calibration values from the real analog front-end.

The advanced interrupt, pulse, buzzer, and richer board-signal debug work
belongs in iter5.

## Project Structure

- `STM32F103C8T6.ioc`  
  CubeMX source of truth for pinout and peripheral configuration.

- `Core/Src/main.c`  
  Application entry point. Initializes peripherals, applies board bring-up
  defaults, initializes display/debug/ATM90E26, then runs the 1 Hz measurement
  loop.

- `Core/Src/atm90e26.c`, `Core/Inc/atm90e26.h`  
  ATM90E26 SPI driver, calibration defaults, register read/write helpers,
  initialization sequence, checksum handling, and measurement reads.

- `Core/Src/board_control.c`, `Core/Inc/board_control.h`  
  Board-level safe defaults, `SENSE_RST` pulse, power source detection, and
  board-state snapshot logging support.

- `Core/Src/esp_control.c`, `Core/Inc/esp_control.h`  
  ESP32 enable/boot/mux control. In normal mode STM32 keeps ESP enabled in app
  boot mode. When `BOOT_DEBUG` selects ESP USB routing, STM32 maps USB DTR/RTS
  to ESP boot/reset so the ESP can be flashed through the board.

- `Core/Src/debug_console.c`, `Core/Inc/debug_console.h`  
  USART1 debug output. Prints boot canaries, board/ESP state, ATM status, UART
  transmit counts, and periodic measurements.

- `Core/Src/display.c`, `Core/Src/ssd1306.c`  
  OLED display layer. `Display_Init()` returns a status so I2C/OLED failure is
  visible in USART1 logs instead of silently producing a black screen.

- `Core/Proto/measure.proto`, `Core/Src/measure.pb.c`,
  `Core/Inc/measure.pb.h`  
  Shared `MeasureData` schema and generated nanopb metadata.

- `Core/Src/pb_encode.c`, `Core/Src/pb_common.c`, `Core/Inc/pb*.h`  
  Minimal nanopb runtime files needed for STM32 encoding.

- `Core/Src/uart_protocol.c`, `Core/Inc/uart_protocol.h`  
  USART2 sender for nanopb `MeasureData` payloads with a 4-byte big-endian
  payload length prefix.

- `Core/Src/tim.c`, `Core/Inc/tim.h`  
  CubeMX-generated TIM2 setup for future advanced I/O. TIM2 is initialized by
  CubeMX but PWM/input-capture runtime functions are not started in iter4.

## Expected Boot Sequence

1. HAL and system clock init.
2. GPIO/I2C/SPI/USART/TIM init.
3. DWT microsecond delay init.
4. Board safe defaults and ESP control init.
5. `SENSE_RST` low pulse, then high.
6. USART1 debug console init.
7. Board and ESP snapshot logs.
8. OLED init canary.
9. ATM90E26 device struct and calibration setup.
10. ATM90E26 init with up to 3 retries.
11. USART2 protocol init.
12. 1 Hz measurement loop with ESP control polling.

## Expected USART1 Debug Logs

At boot, a healthy path should look roughly like:

```text
BOOT,stm32-new iter4-hw-pinout-integrated
BOARD,pwr=...,usbc_pg=...,vbat_pg=...,boot_dbg=...,sense_rst=1,rst_pulse=1
ESP,en=1,boot=app,mux=...,run=normal,flash_pt=0,dtr=...,rts=...,dbg=...
OLED,init,ok
CAL,ugain=0x6720,igainL=0x7A13
ATM,init,try
ATM,init_ok,status=0,sys=0x0000
MEAS,t=...,pwr=...,v=...,i=...,in=...,p=...,q=...,s=...,f=...,pf=...,ei=...,ee=...
TX2,n=...
```

If OLED is missing or I2C is wrong, the firmware should still continue:

```text
OLED,init,err=i2c_no_ack
```

If the MCU reaches a HardFault, USART1 should emit:

```text
HF
```

## USART2 ESP32 Measurement Payload

This branch sends one nanopb-encoded `MeasureData` payload to ESP32 once per
successful measurement. The UART packet format is:

```text
[4-byte big-endian payload length][protobuf payload]
```

The schema is:

```proto
syntax = "proto3";

message MeasureData {
    float current = 1;
    float voltage = 2;
    float power = 3;
    float frequency = 4;
    float power_usage = 5;
    bool sd_logs_enable = 6;
    bool wifi_enable = 7;
}
```

Field scaling sent by STM32:

- `voltage`: volts
- `current`: amperes from line current
- `power`: active power in watts
- `frequency`: hertz
- `power_usage`: accumulated import energy since STM32 boot, in kWh
- `sd_logs_enable`: currently always `true`
- `wifi_enable`: currently always `true`

## ESP32 Boot And Flashing Control

Normal test mode:

- ESP is enabled.
- ESP boot pin is held in app mode.
- USB-UART mux is routed according to `BOOT_DEBUG`.
- STM32 keeps sending measurement telemetry on USART2.

ESP flashing mode:

- Set `BOOT_DEBUG` so USB-UART is routed to ESP.
- STM32 reads USB DTR/RTS and maps them to ESP boot/reset control.
- `ESP,run=usb_flash,flash_pt=1` in USART1 logs confirms passthrough mode.
- After flashing, return `BOOT_DEBUG` to STM route for normal STM debug logs.

Current hardware assumptions:

- `BUS_SELECT` low routes USB-UART to STM32.
- `BUS_SELECT` high routes USB-UART to ESP32.
- DTR/RTS active level is low.
- If hardware validation proves the opposite, only level macros in
  `esp_control.c` should change.

## Test-Day Debug Checklist

Use USART1 as the primary bring-up truth source.

1. Confirm the board boots.
   Expected: `BOOT,...`

2. Confirm board pin defaults.
   Expected: `BOARD,...sense_rst=1,rst_pulse=1`

3. Confirm OLED/I2C.
   Expected: `OLED,init,ok` or a clear `OLED,init,err=...`

4. Confirm ATM90E26 SPI/init.
   Expected: `ATM,init_ok,status=0,sys=0x0000`

5. Confirm measurements.
   Expected: periodic `MEAS,...`

6. Confirm USART2 transmission.
   Expected: `TX2,n=...` after successful measurements.

7. Confirm ESP decode path.
   Expected on ESP side: decoded `MeasureData` messages using the 4-byte
   big-endian length prefix.

## Failure Map

- `BOOT` missing: MCU did not boot far enough, or USART1 debug is not connected.
- `HF`: firmware reached HardFault; attach SWD and inspect fault context.
- `OLED,init,err=i2c_no_ack`: I2C/OLED path, not ATM90E26.
- `ATM,init` failure before measurements: SPI, ATM reset/power/clock, or ATM
  register verification path.
- `MEAS` exists but voltage/frequency are zero: SPI is likely alive, but the
  analog voltage input or ATM sensing path may be wrong.
- `MEAS` exists but ESP app has no data: check USART2 pins, mux route, ESP
  parser, WiFi, then mobile app.
- `TX2` exists but ESP decode fails: confirm the ESP parser expects a 4-byte
  big-endian length followed by raw protobuf bytes.

## Build

From `Code/STM32-NEW/Debug`, the project can be built with STM32CubeIDE's
bundled make and ARM GCC tools. In this workspace, the verified build command
used during preparation was:

```powershell
$env:PATH='C:\ST\STM32CubeIDE_1.17.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.13.3.rel1.win32_1.0.0.202411081344\tools\bin;' + $env:PATH
& 'C:\ST\STM32CubeIDE_1.17.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.make.win32_2.2.0.202409170845\tools\bin\make.exe' main-build -j4
```

Last verified iter4 size:

```text
text=34672, data=92, bss=3660
```
