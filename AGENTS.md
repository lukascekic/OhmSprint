# AGENTS.md

## Build & Deploy

```bash
make build              # Build firmware
make upload             # Build + flash to ESP32
make uploadfs           # Upload LittleFS filesystem
make upload-all         # Build + upload firmware + filesystem
make monitor            # Serial monitor (115200 baud)
```

## UART Protobuf Communication

- UART1 on GPIO21 (RX) / GPIO20 (TX) at 115200 baud
- Protocol: `[4-byte big-endian length][protobuf payload]`
- Message: `MeasureData` (proto/simple.proto)
- ESP32 receives via `Serial1`, decodes with nanopb

## Simulator

```bash
make simulator SIM_PORT=/dev/ttyUSB0    # Run UART simulator
```

## Web UI

- Source: `web/` (Astro)
- Output: `data/` (LittleFS)
- Build triggered automatically on `make build` via `web_content.py`
- Requires `pnpm` for Astro build

## Protobuf

- C code generated automatically by PlatformIO via `custom_nanopb_protos`
- Python protobuf for simulator: `tools/simple_pb2.py` (generated from `proto/simple.proto`)
- If `proto/simple.proto` changes, rebuild triggers regeneration

## Architecture

- Entry point: `src/main.cpp`
- WiFi provisioning: `src/wifi_provisioning.cpp/.h`
- Protobuf schema: `proto/simple.proto` → `MeasureData`
- UART receive: `process_uart_byte()` state machine in `main.cpp`

## Configuration

UART pins/baud configured in `platformio.ini` build_flags:
```ini
-DUART_RX_PIN=21
-DUART_TX_PIN=20
-DUART_BAUD=115200
```

## Test

No unit tests. Hardware testing requires ESP32-C3 device.