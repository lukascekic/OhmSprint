# OhmSprint Mobile App

Cross-platform Flutter application for OhmSprint. It discovers the ESP32
gateway on the local network, streams measurements over WebSocket (with HTTP
polling as a fallback), displays live charts, and persists history locally.
The app does not talk to STM32 directly; ESP32 is the WiFi-facing layer.

A Dart mock device server is included so the app can be developed and tested
without physical hardware.

## Main Responsibilities

- Discover the device over mDNS (`_ohmsprint._tcp.local`, fallback
  `_http._tcp.local`).
- Connect over WebSocket as the primary transport, fall back to HTTP polling
  after repeated failures, and probe periodically to recover the WebSocket.
- Parse measurement JSON with short and long field aliases, and derive apparent
  power / power factor when missing.
- Treat payloads with the `ev` key as power-quality events instead of
  measurements.
- Display live charts, statistics, and connection state.
- Persist measurement history with Hive.
- Build for Android and iOS from a single Flutter codebase.

## Project Structure

| Path | Purpose |
|---|---|
| `lib/main.dart`, `lib/app.dart` | Entry point and root widget |
| `lib/core/models/` | Domain models (`measurement`, `power_event`, `connection_state`, ...) |
| `lib/core/theme/`, `lib/core/utils/` | Styling and shared utilities |
| `lib/services/websocket_service.dart` | WebSocket transport wrapper |
| `lib/services/http_polling_service.dart` | HTTP polling fallback transport |
| `lib/services/mdns_discovery_service.dart` | mDNS device discovery |
| `lib/services/measurement_repository.dart` | Hive-backed local persistence |
| `lib/services/mock_data_service.dart` | In-app demo data source |
| `lib/providers/` | Riverpod providers for connection, measurements, stats |
| `lib/screens/` | Splash, shell, charts, export screens |
| `lib/widgets/` | Charts, glass cards, common UI components |
| `tool/mock_device_server.dart` | Standalone mock device server |
| `android/`, `ios/` | Native platform projects |

## Connection Flow

```text
mDNS discovery
  -> Connecting
  -> Connected (WebSocket)
  -> Reconnecting (WebSocket)
  -> HTTP polling fallback
  -> Periodic WebSocket recovery probe
  -> Connected (WebSocket)
```

The WebSocket URL is `ws://<ip>:<port>/ws`. HTTP polling tries `/api/readings`
then `/api/measurements`.

## Run

Requires the Flutter SDK with Dart 3.5 or newer. Standard Flutter commands:

```bash
flutter pub get
flutter run                 # debug build on a connected device or emulator
flutter build apk           # Android release APK
flutter build appbundle     # Android Play Store bundle
flutter build ios           # iOS (requires macOS and Xcode)
```

## Mock Device Server

The mock server exposes the same WebSocket and HTTP endpoints as the real
ESP32 gateway, so the app can be developed without hardware. Run it from the
project root:

```bash
dart run tool/mock_device_server.dart
```

It supports WebSocket-only, HTTP-only, and combined modes, and can simulate an
unstable WebSocket transport to exercise the HTTP fallback path. See the source
for `--transport`, `--ws-behavior`, and the other flags.

## Known Limitations

- A malformed JSON payload over WebSocket currently terminates the
  subscription and triggers a reconnect rather than being dropped silently.
- Cumulative energy that survives an STM32 reset is not persisted locally in
  this iteration.
- The app expects an ESP32 JSON contract; if ESP32 changes field names outside
  the supported aliases, the parser will reject the payload.
