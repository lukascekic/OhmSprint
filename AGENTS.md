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

- UART1 on GPIO8 (RX) / GPIO4 (TX) at 115200 baud
- Protocol: `[4-byte big-endian length][protobuf payload]`
- Message: `MeasureData` (proto/simple.proto)
- ESP32 receives via `Serial1`, decodes with nanopb

## Sensor API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/measurements` | GET | Last sensor reading as JSON |
| `/ws` | WebSocket | Real-time sensor data stream |

**JSON response format:**
```json
{"current":1.23,"voltage":220.5,"power":271.4,"frequency":50.02,"power_usage":1234.56,"timestamp":127}
```

- `timestamp` is relative seconds since boot (captured at measurement time, not API call time)
- WebSocket sends same JSON to all connected clients on each new measurement

## Testing WebSocket

Browser console:
```javascript
ws = new WebSocket('ws://<esp32-ip>/ws');
ws.onmessage = (e) => console.log(JSON.parse(e.data));
```

Command line:
```bash
wscat -c ws://<esp32-ip>/ws
```

## WiFi Provisioning

- On first boot: creates AP "ESP32_Config" (no password) at 192.168.4.1
- Captive portal auto-detects and redirects
- After setup, ESP auto-connects to saved credentials
- Credentials stored in NVS partition `wifi_creds`

## Web UI

- Source: `web/` (Astro)
- Output: `data/` (LittleFS)
- Build triggered automatically on `make build` via `web_content.py`
- Requires `pnpm` for Astro build

## Protobuf

- C code generated automatically by PlatformIO via `custom_nanopb_protos`
- Python protobuf for simulator: `tools/simple_pb2.py` (generated from `proto/simple.proto`)
- If `proto/simple.proto` changes, rebuild triggers regeneration

## Key Files

| File | Purpose |
|------|---------|
| `src/main.cpp` | Entry point, UART state machine, API handlers |
| `src/wifi_provisioning.cpp/.h` | WiFi AP/STA logic, captive portal |
| `proto/simple.proto` | `MeasureData` schema |

## Configuration

UART pins/baud in `platformio.ini` build_flags:
```ini
-DUART_RX_PIN=8
-DUART_TX_PIN=4
-DUART_BAUD=115200
```