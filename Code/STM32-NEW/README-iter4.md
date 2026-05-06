# STM32-NEW iter4 hardware bring-up firmware

This branch is the first hardware-testable STM32 firmware for the final
`STM32-NEW` pinout. Its job is to prove the local metering path on the real
PCB with as few moving parts as possible, while still exposing enough debug
signals to isolate failures quickly.

## What This Iteration Contains

- Final CubeMX pinout in `STM32F103C8T6.ioc`.
- SWD enabled, JTAG disabled, so PA15/PB3/PB4 are available for board signals.
- SPI1 configured for ATM90E26 communication: Mode 3, software NSS, slow
  bring-up speed.
- I2C1 OLED support with an ACK canary during display init.
- USART1 debug console for PC-side bring-up logs.
- USART2 minimal measurement transmit path toward ESP32.
- TIM2 generated and configured for future buzzer/CF work, but not started at
  runtime in this branch.
- ATM90E26 initialization, register writes, checksum verification, periodic
  measurement reads, OLED display update, and USART1 measurement logs.
- Board safe-default setup for ATM CS, SENSE_RST, ESP boot/control pins, and
  mux selection.

## What This Iteration Does Not Contain

- No nanopb encoding.
- No final binary ESP32 framing with magic bytes, length, protobuf payload, and
  CRC16.
- No ESP32 command/control state machine.
- No runtime EXTI handling for `ZX`, `IRQ`, or `WARN_OUT`.
- No CF pulse accumulation from `CF1` / `CF2`.
- No buzzer runtime behavior.
- No persistent energy resume after STM32 reset.

The advanced interrupt, pulse, buzzer, nanopb, and full ESP32 integration work
belongs in the next branch.

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

- `Core/Src/debug_console.c`, `Core/Inc/debug_console.h`  
  USART1 debug output. Prints boot canaries, board/ESP state, ATM status, and
  periodic measurements.

- `Core/Src/display.c`, `Core/Src/ssd1306.c`  
  OLED display layer. `Display_Init()` returns a status so I2C/OLED failure is
  visible in USART1 logs instead of silently producing a black screen.

- `Core/Src/uart_protocol.c`, `Core/Inc/uart_protocol.h`  
  Minimal USART2 text-frame sender for ESP32 RX debug. This is intentionally
  not the final nanopb protocol.

- `Core/Src/esp_control.c`, `Core/Inc/esp_control.h`  
  ESP-related GPIO defaults and state labels. This branch logs ESP control
  state but does not implement full ESP orchestration.

- `Core/Src/tim.c`, `Core/Inc/tim.h`  
  CubeMX-generated TIM2 setup for future advanced I/O. The timer is initialized
  but PWM/input-capture runtime functions are not started in iter4.

## Boot Sequence

Expected high-level sequence in `main.c`:

1. HAL and system clock init.
2. GPIO/I2C/SPI/USART/TIM init.
3. DWT microsecond delay init.
4. Board safe defaults.
5. `SENSE_RST` low pulse, then high.
6. USART1 debug console init.
7. Board and ESP snapshot logs.
8. OLED init canary.
9. ATM90E26 device struct and calibration setup.
10. ATM90E26 init with up to 3 retries.
11. USART2 protocol init.
12. 1 Hz measurement loop.

## Expected USART1 Debug Logs

At boot, a healthy path should look roughly like:

```text
BOOT,stm32-new iter4-hw-pinout-integrated
BOARD,pwr=...,usbc_pg=...,vbat_pg=...,boot_dbg=...,sense_rst=1,rst_pulse=1
ESP,en=...,boot=...,mux=...,dtr=...,rts=...,dbg=...
OLED,init,ok
CAL,ugain=0x6720,igainL=0x7A13
ATM,init,try
ATM,init_ok,status=0,sys=0x0000
MEAS,t=...,pwr=...,v=...,i=...,in=...,p=...,q=...,s=...,f=...,pf=...,ei=...,ee=...
```

If OLED is missing or I2C is wrong, the firmware should still continue:

```text
OLED,init,err=i2c_no_ack
```

If the MCU reaches a HardFault, USART1 should emit:

```text
HF
```

## USART2 ESP32 Debug Frame

This branch sends a simple text frame to ESP32 once per successful measurement:

```text
$M,seq=0,t=12,v=23005,i=4523,in=0,p=1042,q=120,s=1050,f=4998,pf=988,ei=120,ee=0*CS
```

Notes:

- `CS` is a simple XOR checksum over the payload between `$` and `*`.
- Raw scaling follows the ATM90E26 driver comments:
  - `v`: raw voltage, `/100 = V`
  - `i`, `in`: raw current, `/1000 = A`
  - `f`: raw frequency, `/100 = Hz`
  - `pf`: signed, `/1000`
  - `ei`, `ee`: accumulated import/export energy in `0.1 Wh`
- This is only an integration/debug aid for USART2 RX. It is not the final
  mobile/ESP protocol.

## Test-Day Debug Checklist

Use USART1 as the primary bring-up truth source.

1. Confirm the board boots.
   - Expected: `BOOT,...`
   - If missing: check power, reset, SWD/programming, USART1 wiring, baud rate.

2. Confirm board pin defaults.
   - Expected: `BOARD,...sense_rst=1,rst_pulse=1`
   - If power source reads `none`, check `USBC_PG` / `VBAT_PG` pull-ups and
     hardware power-good outputs.

3. Confirm OLED/I2C.
   - Expected: `OLED,init,ok`
   - If `OLED,init,err=i2c_no_ack`: check OLED address, I2C pull-ups, SCL/SDA
     wiring, and power to the display.

4. Confirm ATM90E26 SPI/init.
   - Expected: `ATM,init_ok,status=0,sys=0x0000`
   - If init fails: focus on ATM CS, SPI mode, SPI wiring, ATM power, reference,
     crystal, reset/sensing front-end, and `LastData` verification path.

5. Confirm measurements.
   - Expected: periodic `MEAS,...`
   - If voltage/frequency are zero but init passes: SPI is likely alive, but the
     analog voltage input or ATM sensing path may be wrong.
   - If voltage exists but current is wrong: check CT, burden resistor, current
     input path, and `IgainL`.

6. Confirm ESP32 UART receive path.
   - Expected on ESP side: `$M,...*CS` frames from STM32 USART2.
   - If USART1 measurements exist but ESP sees nothing: focus on USART2 pins,
     baud rate, mux route, ESP RX configuration, and ground/common power.

## Failure Map

- `BOOT` missing: MCU did not boot far enough, or USART1 debug is not connected.
- `HF`: firmware reached HardFault; attach SWD and inspect fault context.
- `OLED,init,err=i2c_no_ack`: I2C/OLED path, not ATM90E26.
- `ATM,init` failure before measurements: SPI, ATM reset/power/clock, or ATM
  register verification path.
- `MEAS` exists but OLED black: display path only; metering path is likely alive.
- `MEAS` exists but ESP app has no data: do not debug ATM first; check
  STM32-to-ESP UART, ESP parser, WiFi, then mobile app.

## Important Implementation Notes

- `ZX`, `IRQ`, and `WARN_OUT` are plain GPIO inputs in iter4. They are labelled
  for future work but intentionally do not generate interrupts here.
- `CF1` and `CF2` are configured through TIM2 pin setup for later work. The
  firmware does not start input capture in iter4.
- `S_MEAN` / apparent power is stored as unsigned `uint16_t`.
- Current calibration defaults are:
  - `Ugain = 0x6720`
  - `IgainL = 0x7A13`
- Total energy is accumulated in STM32 RAM only in this branch, so it resets on
  MCU reset.

## Build

From `Code/STM32-NEW/Debug`, the project can be built with STM32CubeIDE's
bundled make and ARM GCC tools. In this workspace, the verified build command
used during preparation was:

```powershell
$env:PATH='C:\ST\STM32CubeIDE_1.17.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.13.3.rel1.win32_1.0.0.202411081344\tools\bin;' + $env:PATH
& 'C:\ST\STM32CubeIDE_1.17.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.make.win32_2.2.0.202409170845\tools\bin\make.exe' main-build -j4
```

Last verified size:

```text
text=26756, data=92, bss=3652
```
