# ESP32-C3 PsychicHttp + nanoPB Project

## Features
- WiFi provisioning via AP configuration page
- HTTP server with JSON and Protobuf endpoints
- Automatic reconnection to stored WiFi credentials
- Fallback to AP mode on connection failure

## Setup

1. Install PlatformIO if needed:
   ```bash
   pip install platformio
   ```

2. Generate protobuf files (requires `protoc` and `nanopb`):
   ```bash
   # Install nanopb generator
   pip install nanopb
   
   # Generate .pb.c and .pb.h files
   protoc --plugin=protoc-gen-nanopb=$(which nanopb_generator.py) -Iproto -pnano_pb proto/simple.proto
   ```
   
   Or use the PlatformIO extra script approach - see [nanopb docs](https://github.com/nanopb/nanopb).

3. Build and upload:
   ```bash
   pio run --target upload
   ```

## First Boot - WiFi Setup

1. ESP creates AP named **ESP32-Config**
2. Connect to it (no password)
3. Open browser to `192.168.4.1`
4. Enter your WiFi SSID and password
5. ESP connects and stores credentials

## Endpoints

| Endpoint | Content-Type | Description |
|----------|-------------|-------------|
| `/` | text/html | Web UI |
| `/status` | application/json | WiFi status |
| `/data/json` | application/json | Sensor data as JSON |
| `/data/proto` | application/x-protobuf | Sensor data as Protobuf |

## Configuration

Edit these in `src/wifi_provisioning.h`:
```cpp
static constexpr uint8_t MAX_RETRIES = 3;           // Connection attempts
static constexpr unsigned long CONNECT_TIMEOUT_MS = 10000;  // Timeout per attempt
```

## Clear Stored Credentials

Call `wifiProv.clearCredentials()` or use NVS partition reset.

## Troubleshooting

- If protobuf generation fails:
  ```bash
  apt install protobuf-compiler
  pip install nanopb
  ```
- Serial monitor: `pio device monitor`
