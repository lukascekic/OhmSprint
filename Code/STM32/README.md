# OhmSprint STM32 Firmware

STM32 firmware is the real-time metering layer of OhmSprint. It initializes the
board, communicates with the ATM90E26 energy-metering IC, drives local
diagnostics, updates the OLED display, and sends measurement frames to the ESP32
gateway over USART2.

The ESP32 firmware is responsible for WiFi, SD logging, and exposing the data to
the mobile application. The mobile app does not talk to STM32 directly.

## Main Responsibilities

- Configure the STM32F103C8T6 peripherals generated from `STM32F103C8T6.ioc`.
- Read voltage, current, power, frequency, power factor, phase, and energy
  registers from ATM90E26 over SPI1.
- Verify ATM90E26 initialization through read-back, calibration checksums, and
  status registers.
- Provide USART1 debug logs for board bring-up and fault diagnosis.
- Send a length-prefixed nanopb `MeasureData` payload to ESP32 over USART2.
- Drive the SSD1306 OLED display when present.
- Count ATM90E26 diagnostic pins and energy pulse outputs:
  `ZX`, `IRQ`, `WARN_OUT`, `CF1`, and `CF2`.
- Control ESP32 enable, boot, and USB-UART mux signals from STM32.

## Project Structure

| Path | Purpose |
|---|---|
| `STM32F103C8T6.ioc` | CubeMX source of truth for pinout and peripheral configuration |
| `Core/Src/main.c` | Application entry point, boot sequence, main loop, interrupt callbacks |
| `Core/Src/atm90e26.c`, `Core/Inc/atm90e26.h` | ATM90E26 SPI driver, calibration, checksums, measurement reads |
| `Core/Src/board_control.c`, `Core/Inc/board_control.h` | Board safe defaults, sensing reset, power-source snapshot |
| `Core/Src/esp_control.c`, `Core/Inc/esp_control.h` | ESP32 enable/boot/mux control and USB DTR/RTS passthrough logic |
| `Core/Src/debug_console.c`, `Core/Inc/debug_console.h` | Structured USART1 diagnostic output |
| `Core/Src/display.c`, `Core/Src/ssd1306.c` | OLED display layer and SSD1306 framebuffer driver |
| `Core/Proto/measure.proto` | STM32-to-ESP32 protobuf schema |
| `Core/Src/measure.pb.c`, `Core/Inc/measure.pb.h` | Generated nanopb files |
| `Core/Src/uart_protocol.c`, `Core/Inc/uart_protocol.h` | USART2 sender for length-prefixed protobuf frames |

## Boot Sequence

The firmware uses a linear bring-up sequence so that early debug output is
available before the riskier hardware initialization steps:

```text
HAL_Init
  -> SystemClock_Config
  -> GPIO/I2C/SPI/USART/TIM init
  -> DWT microsecond delay init
  -> board safe defaults
  -> sensing reset pulse
  -> USART1 debug console
  -> board and ESP state logs
  -> OLED init
  -> TIM2 PWM/input-capture start
  -> ATM90E26 init, up to 3 attempts
  -> USART2 protocol init
  -> 1 Hz measurement loop
```

OLED initialization is non-fatal. If the display is missing or I2C does not
acknowledge, the firmware reports the error on USART1 and continues measuring.

## STM32 to ESP32 Protocol

STM32 sends one nanopb-encoded `MeasureData` message after each successful
measurement. Because UART is a byte stream, each payload is prefixed with a
4-byte big-endian length:

```text
[length byte 0][length byte 1][length byte 2][length byte 3][protobuf payload]
```

The schema is defined in `Core/Proto/measure.proto`:

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
- `current`: amperes, line current
- `power`: active power in watts
- `frequency`: hertz
- `power_usage`: accumulated energy counter since STM32 boot, treated as
  consumption in the tested wiring setup
- `sd_logs_enable`: currently always `true`, reserved for future power modes
- `wifi_enable`: currently always `true`, reserved for future power modes

## Debug Logs

USART1 is the primary bring-up and diagnosis channel. A healthy boot typically
contains:

```text
BOOT,...
BOARD,pwr=...,usbc_pg=...,vbat_pg=...,boot_dbg=...,sense_rst=1,rst_pulse=1
ESP,en=1,boot=app,mux=...,run=normal,flash_pt=0,dtr=...,rts=...,dbg=...
OLED,init,ok
IO,init,ok
ATM,init,try
ATM,init_ok,status=0,sys=0x0000
MEAS,t=...,pwr=...,v=...,i=...,in=...,p=...,q=...,s=...,f=...,pf=...,ei=...,ee=...
TX2,n=...
IO,t=...,zx=...,irq=...,warn=...,cf1=...,cf2=...,dzx=...,dirq=...,dwarn=...,dcf1=...,dcf2=...
```

Useful failure indicators:

| Log / symptom | Likely area |
|---|---|
| No `BOOT` | MCU boot, power, or USART1 debug wiring |
| `HF` | HardFault; attach SWD and inspect fault context |
| `OLED,init,err=...` | OLED/I2C path; measurements can still continue |
| No `ATM,init_ok` | ATM90E26 SPI, reset, power, or checksum/status verification |
| `MEAS` exists but no `TX2` | Measurements work, USART2 frame was not sent |
| `TX2` exists but app has no data | ESP32 parser, WiFi transport, or JSON conversion |

## ESP32 Control

In normal mode, STM32 enables ESP32, keeps it in application boot mode, and
continues sending measurement frames over USART2.

The firmware also contains USB DTR/RTS passthrough logic for ESP32 flashing
through the board. This path was kept in the firmware, but it was not
hardware-validated during the final test phase; ESP32 was flashed through direct
hardware access on the board.

## Build

The project can be opened and built from STM32CubeIDE using the included
`STM32F103C8T6.ioc` project configuration.

For command-line builds, run the generated makefile from the `Debug`
subdirectory with STM32CubeIDE's bundled make and ARM GCC tools on `PATH`:

```powershell
cd Debug
make main-build -j4
```

The last verified firmware size after the final cleanup was:

```text
text=37396, data=92, bss=3708
```

## Known Limitations

- STM32-to-ESP32 UART framing has no magic byte, version field, or CRC.
- STM32 telemetry is fire-and-forget; there is no ESP32 ACK or heartbeat.
- Accumulated energy is stored in STM32 RAM and resets after STM32 reset.
- Calibration values are validated for the tested hardware setup and wiring.
- USB DTR/RTS passthrough toward ESP32 exists, but was not hardware-validated in
  the final test phase.
- The current firmware does not include a watchdog mechanism.
