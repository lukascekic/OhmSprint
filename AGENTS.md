# AGENTS.md

## Build & Deploy

```bash
pio run                    # Build firmware
pio run --target upload      # Build + flash to device
pio device monitor        # Serial monitor (115200 baud)
```

## Protobuf

If `proto/simple.proto` changes, regenerate C code:
```bash
protoc --plugin=protoc-gen-nanopb=$(which nanopb_generator.py) -Iproto -pnano_pb proto/simple.proto
```
Outputs go to `src/simple.pb.c` and `proto/simple.pb.h`.

## Architecture

- Entry point: `src/main.cpp` (setup/loop)
- WiFi provisioning: `src/wifi_provisioning.cpp/.h`
- Protobuf schema: `proto/simple.proto` → `SensorData`, `SensorResponse`

## Test

No unit tests. Hardware testing requires ESP32-C3 device.