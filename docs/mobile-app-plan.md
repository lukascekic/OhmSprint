# OhmSprint Flutter Mobile App - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter mobile app for real-time monitoring of ATM90E26 energy meter data, connected via WebSocket to ESP32-C3.

**Architecture:** Riverpod for state management, go_router for navigation, fl_chart for charts, CustomPainter for gauges (no Syncfusion — lighter, better design control). WebSocket streams measurements at 1Hz. Mock data service enables development without hardware. Hive for local persistence.

**Tech Stack:** Flutter/Dart, flutter_riverpod, go_router, fl_chart, web_socket_channel, hive_flutter, google_fonts, pdf, csv, share_plus, path_provider, intl

**Orientation:** Portrait-only for v1 (matches HTML mocks, halves layout testing)

---

## V1 Scope

**Included:** S1 (Splash), S2 (Connection), S3 (Dashboard), S4 (Charts), S5 (Power Quality), S7 (Settings), S8 (Export)

**Excluded:** S6 (Tamper Detection), Core Temp, Stability Index, Magnetic Field, Biometric auth (see `UI-stitch/UI-NOTES.md`)

**Post-v1:** Landscape orientation, pinch-to-zoom on charts, pull-to-refresh, true background notifications, ESP32 history API, home screen widget, prosumer comparison view

## Critical Reference Files

- `UI-stitch/UI-NOTES.md` — exclusion list, must check before each screen
- `UI-stitch/kinetic_grid/DESIGN.md` — design system (colors, glass panels, typography rules)
- `UI-stitch/*/code.html` — exact layouts, colors, SVG gauge math
- `docs/SCREENS.md` — authoritative screen specs
- `docs/mobile-app-spec.md` — feature tiers, tech decisions
- `docs/driver-plan.md` (Step 3) — UART JSON format

## API Contract (frozen for v1)

Source of truth: `docs/driver-plan.md` Step 3 (UART JSON format). Spec (`mobile-app-spec.md`) has an older, narrower payload — firmware is authoritative.

**Required fields** (parser fails without these):
```json
{"v":230.15, "i":4.123, "p":948, "f":50.01, "pf":0.999, "t":12345}
```

**Optional fields** (parser uses `?? 0.0` fallback):
```json
{"in":4.1, "q":52, "s":949, "ei":1.23, "ee":0.05}
```
Legacy compat: if `"e"` is present and `"ei"` is absent, map `"e"` → `importEnergy`.

**Events** (all optional, parsed by `"ev"` key presence):
```json
{"ev":"sag","v":218.3,"ts":12345}
{"ev":"swell","v":254.1,"ts":12345}
{"ev":"freq","f":49.42,"ts":12345}
{"ev":"lpf","pf":0.68,"ts":12345}
```

> **Note:** UART format is still pending confirmation (JSON vs binary). If binary is chosen, the ESP32 will likely re-serialize to JSON for WebSocket anyway. The Flutter parser doesn't change — only ESP32 internals do.

## History Data Source (v1 decision)

**v1: Local Hive cache is the sole history source.** ESP32 does not currently expose a history API endpoint. The colleague's ESP32 firmware is still in development.

Consequence: if a user reinstalls or connects for the first time, there is no historical data. This is acceptable for a hackathon demo. When ESP32 history API becomes available, `MeasurementRepository` can add a `fetchRemoteHistory(ip, from, to)` method as an additional data source.

---

## File Structure

```
Code/Mobile/ohmsprint/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_colors.dart          # All color tokens from design system
│   │   │   ├── app_typography.dart      # Space Grotesk, Inter, JetBrains Mono styles
│   │   │   ├── app_theme.dart           # ThemeData dark + light themes
│   │   │   └── glass_decoration.dart    # BoxDecoration factory for glass/glow effects
│   │   ├── constants/
│   │   │   └── app_constants.dart       # WS URL, metric ranges, thresholds
│   │   ├── models/
│   │   │   ├── measurement.dart         # Measurement data class + JSON parsing
│   │   │   ├── power_event.dart         # PowerQualityEvent + JSON parsing
│   │   │   ├── connection_state.dart    # Enum: disconnected/connecting/connected/reconnecting
│   │   │   ├── metric_type.dart         # Enum with label/unit/color/range metadata
│   │   │   └── settings_model.dart      # All settings with defaults
│   │   ├── router/
│   │   │   └── app_router.dart          # GoRouter: splash->connect->shell(4 tabs)->export
│   │   └── utils/
│   │       ├── formatters.dart          # Number formatting per metric type
│   │       └── quality_evaluator.dart   # normal/warning/critical evaluation
│   │       └── downsampler.dart         # Chart data downsampling for large datasets
│   ├── services/
│   │   ├── websocket_service.dart       # WebSocket connect/stream/reconnect
│   │   ├── http_polling_service.dart    # HTTP fallback polling when WS fails
│   │   ├── mdns_discovery_service.dart  # mDNS device auto-discovery
│   │   ├── mock_data_service.dart       # Fake 1Hz measurement stream for dev/demo
│   │   ├── notification_service.dart    # Local push notifications for alerts
│   │   ├── measurement_repository.dart  # Hive storage: save, query, stats, clear
│   │   └── export_service.dart          # CSV/PDF generation + share
│   ├── providers/
│   │   ├── connection_provider.dart     # WebSocket lifecycle, demo mode switch
│   │   ├── measurement_provider.dart    # Stream + history + latest value
│   │   ├── power_events_provider.dart   # Event accumulation
│   │   ├── settings_provider.dart       # Hive-persisted settings
│   │   ├── stats_provider.dart          # Min/max/avg computation
│   │   └── demo_mode_provider.dart      # Bool toggle: real WS vs mock
│   ├── widgets/
│   │   ├── common/
│   │   │   ├── glass_card.dart          # Reusable glass morphism container
│   │   │   ├── status_dot.dart          # Pulsing green/red connection dot
│   │   │   ├── metric_value.dart        # Large mono number + colored unit
│   │   │   ├── metric_label.dart        # Uppercase tracking label
│   │   │   └── connection_lost_overlay.dart
│   │   ├── gauges/
│   │   │   ├── hero_radial_gauge.dart   # Large CustomPainter gauge for Active Power
│   │   │   ├── mini_metric_card.dart    # Dashboard 2x2 grid cards
│   │   │   ├── semi_circular_gauge.dart # Half-circle PF gauge
│   │   │   └── quality_slider.dart      # 3-zone linear bar (red-green-red)
│   │   ├── charts/
│   │   │   ├── live_line_chart.dart     # fl_chart with auto-scroll
│   │   │   ├── sparkline_widget.dart    # Mini 60-point dashboard chart
│   │   │   ├── time_range_selector.dart # 1m/5m/15m/1h/24h chips
│   │   │   └── stats_row.dart          # Min/Avg/Max display
│   │   └── nav/
│   │       └── bottom_nav_bar.dart      # Glass blur custom nav bar
│   └── screens/
│       ├── splash_screen.dart
│       ├── connection_screen.dart
│       ├── shell_screen.dart            # Scaffold + IndexedStack + bottom nav
│       ├── dashboard_screen.dart
│       ├── charts_screen.dart
│       ├── power_quality_screen.dart
│       ├── settings_screen.dart
│       └── export_screen.dart
├── test/
│   ├── models/measurement_test.dart
│   ├── models/power_event_test.dart
│   ├── utils/formatters_test.dart
│   ├── utils/quality_evaluator_test.dart
│   ├── services/mock_data_service_test.dart
│   ├── services/http_polling_service_test.dart
│   ├── services/mdns_discovery_service_test.dart
│   └── integration/data_flow_test.dart      # Full pipeline: mock→provider→repo→Hive
└── assets/fonts/{SpaceGrotesk,Inter,JetBrainsMono}/
```

---

## Design System Summary

| Token | Hex | Usage |
|-------|-----|-------|
| surface-dim | #111125 | Scaffold bg |
| surface-container-low | #1a1a2e | Card bg, nav bg |
| surface-container | #1e1e32 | Elevated cards |
| surface-container-high | #28283d | Interactive elements |
| surface-bright | #37374d | Overlays |
| on-surface | #e2e0fc | Primary text |
| on-surface-variant | #bfc7d4 | Labels, secondary text |
| primary | #9ecaff | Voltage, links, active |
| error | #ffb4ab | Current, errors |
| secondary | #78dc77 | Power, PF, online |
| tertiary | #ffb870 | Frequency |

**Metric colors:** Voltage=primary, Current=error, Power=secondary, Frequency=tertiary, Energy=secondary, PF=secondary

**Rules:** No hard borders (tonal shifts + 0.5px glow instead). Glass panels = semi-transparent bg + border-radius 12-16px. All numbers in JetBrains Mono. Labels in Space Grotesk uppercase. Gauge animations 300ms ease-out.

---

## Key Technical Decisions (from review)

1. **Hive storage:** Use JSON serialization (`jsonEncode`/`jsonDecode`), NOT TypeAdapters. Simpler for v1, no codegen required. Store as `box.put(timestamp, jsonEncode(measurement))`.
2. **Hive write frequency:** Batch writes every 30 seconds (NOT every 1Hz reading). In-memory ring buffer is source of truth for live UI; Hive is for persistence across restarts and export.
3. **Chart downsampling:** Add `downsample()` utility. For 1m/5m/15m: all points. For 1h: every 3rd point (~1200 points). For 24h: min/max per 60s window (~1440 points). fl_chart cannot handle 3600+ points with gradients.
4. **JSON error handling:** Wrap WebSocket stream parsing in try/catch in connection_provider. Drop malformed messages, don't crash.
5. **Export limits:** Cap PDF export at 10,000 rows. For longer ranges, auto-downsample or warn user.
6. **Stream split:** `WebSocketService` returns `Stream<Map<String, dynamic>>`. `ConnectionProvider` splits: if map has `"ev"` key → event stream, else → measurement stream. Mock service mirrors this same interface.
7. **Demo mode:** Default `true` in debug builds (`kDebugMode`), `false` in release.
8. **Update interval setting:** Controls UI refresh throttle (how often widgets rebuild), NOT the device send rate.

---

## Task Breakdown

### Task 0: Project Scaffolding

**Files:** Create entire `Code/Mobile/ohmsprint/` project

- [x] **Step 1:** Run `flutter create --org com.ohmsprint ohmsprint` in `Code/Mobile/`
- [x] **Step 2:** Replace `pubspec.yaml` with required dependencies:
```yaml
name: ohmsprint
description: OhmSprint Energy Monitor
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  fl_chart: ^0.68.0
  web_socket_channel: ^3.0.0
  hive_flutter: ^1.1.0
  hive: ^2.2.3
  json_annotation: ^4.9.0
  path_provider: ^2.1.3
  share_plus: ^9.0.0
  pdf: ^3.11.0
  csv: ^6.0.0
  intl: ^0.19.0
  google_fonts: ^6.2.1
  multicast_dns: ^0.3.2+6
  http: ^1.2.1
  flutter_local_notifications: ^17.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```
- [x] **Step 3:** Create all directory structure under `lib/`
- [x] **Step 4:** Download and bundle font files (Space Grotesk, Inter, JetBrains Mono) into `assets/fonts/`, register in pubspec.yaml
- [x] **Step 5:** Lock to portrait-only in `main.dart`: `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`
- [x] **Step 6:** Run `flutter pub get` to verify all dependencies resolve
- [x] **Step 7:** Commit: "feat: scaffold Flutter project with dependencies"

---

<!-- execute-plan: complete -->
_Execution note: completed by Codex on 2026-04-07 08:17:30_
### Task 1: Theme and Design System

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_typography.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/theme/glass_decoration.dart`

- [ ] **Step 1:** Create `app_colors.dart` — all color constants from design system table above, plus glow variants (`.withOpacity(0.4)` for each metric color), plus outline-variant (#404752)
- [ ] **Step 2:** Create `app_typography.dart` — TextStyle definitions:
  - `displayLarge`: Space Grotesk, 48, bold (hero numbers)
  - `headlineMedium`: Space Grotesk, 24, w500
  - `labelSmall`: Inter, 10, uppercase, letterSpacing 2.0
  - `bodyMedium`: Inter, 14
  - `monoLarge`: JetBrains Mono, 40, bold (main gauge value)
  - `monoMedium`: JetBrains Mono, 24, w500 (secondary values)
  - `monoSmall`: JetBrains Mono, 11 (chart labels, event timestamps)
- [ ] **Step 3:** Create `app_theme.dart`:
  - `AppTheme.dark` — `ThemeData.dark()` with scaffoldBackgroundColor #111125, cardColor #1e1e32, custom ColorScheme, textTheme from step 2
  - `AppTheme.light` — `ThemeData.light()` with inverted surface colors (white scaffold, light gray cards), same accent colors, adjusted text colors for readability on light bg
- [ ] **Step 4:** Create `glass_decoration.dart` — factory methods:
  - `GlassDecoration.card()`: color #1a1a2e at 60% opacity, borderRadius 12, border 0.5px primary at 10%
  - `GlassDecoration.elevated()`: color #1e1e32 at 80%, borderRadius 16, glow inner shadow
  - `GlassDecoration.surface()`: color #28283d, borderRadius 8
- [ ] **Step 5:** Commit: "feat: add design system theme, colors, typography"

---

### Task 2: Data Models

**Files:**
- Create: `lib/core/models/measurement.dart`
- Create: `lib/core/models/power_event.dart`
- Create: `lib/core/models/connection_state.dart`
- Create: `lib/core/models/metric_type.dart`
- Create: `lib/core/models/settings_model.dart`
- Test: `test/models/measurement_test.dart`
- Test: `test/models/power_event_test.dart`

- [ ] **Step 1:** Write `measurement_test.dart`:
```dart
void main() {
  group('Measurement.fromJson', () {
    test('parses valid JSON with all fields', () {
      final json = {'v': 230.15, 'i': 4.123, 'in': 4.1, 'p': 948.0, 'q': 52.0, 's': 949.0, 'f': 50.01, 'pf': 0.999, 'ei': 1.23, 'ee': 0.05, 't': 1234567890};
      final m = Measurement.fromJson(json);
      expect(m.voltage, 230.15);
      expect(m.current, 4.123);
      expect(m.activePower, 948.0);
      expect(m.frequency, 50.01);
      expect(m.powerFactor, 0.999);
      expect(m.importEnergy, 1.23);
      expect(m.exportEnergy, 0.05);
    });

    test('handles integer values', () {
      final json = {'v': 230, 'i': 4, 'in': 4, 'p': 948, 'q': 52, 's': 949, 'f': 50, 'pf': 1, 'ei': 1, 'ee': 0, 't': 1234567890};
      final m = Measurement.fromJson(json);
      expect(m.voltage, 230.0);
    });

    test('handles negative power (export/reverse)', () {
      final json = {'v': 230.0, 'i': 4.0, 'in': 4.0, 'p': -150.0, 'q': -10.0, 's': 150.0, 'f': 50.0, 'pf': -0.99, 'ei': 0.0, 'ee': 1.5, 't': 1234567890};
      final m = Measurement.fromJson(json);
      expect(m.activePower, -150.0);
    });

    test('handles minimal payload (required fields only)', () {
      final json = {'v': 230.0, 'i': 4.0, 'p': 920.0, 'f': 50.0, 'pf': 0.99, 't': 1234567890};
      final m = Measurement.fromJson(json);
      expect(m.voltage, 230.0);
      expect(m.reactivePower, 0.0);  // default
      expect(m.importEnergy, 0.0);   // default
    });

    test('maps legacy "e" field to importEnergy', () {
      final json = {'v': 230.0, 'i': 4.0, 'p': 920.0, 'f': 50.0, 'pf': 0.99, 'e': 123.45, 't': 1234567890};
      final m = Measurement.fromJson(json);
      expect(m.importEnergy, 123.45);
    });
  });
}
```
- [ ] **Step 2:** Run test to verify it fails: `flutter test test/models/measurement_test.dart`
- [ ] **Step 3:** Create `measurement.dart`:
```dart
class Measurement {
  final double voltage;      // v
  final double current;      // i
  final double currentN;     // in (N-line)
  final double activePower;  // p [W]
  final double reactivePower;// q [VAR]
  final double apparentPower;// s [VA]
  final double frequency;    // f [Hz]
  final double powerFactor;  // pf
  final double importEnergy; // ei [kWh]
  final double exportEnergy; // ee [kWh]
  final int timestamp;       // t

  const Measurement({
    required this.voltage, required this.current, required this.currentN,
    required this.activePower, required this.reactivePower, required this.apparentPower,
    required this.frequency, required this.powerFactor,
    required this.importEnergy, required this.exportEnergy, required this.timestamp,
  });

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      // Required fields — parser throws if missing
      voltage: (json['v'] as num).toDouble(),
      current: (json['i'] as num).toDouble(),
      activePower: (json['p'] as num).toDouble(),
      frequency: (json['f'] as num).toDouble(),
      powerFactor: (json['pf'] as num).toDouble(),
      timestamp: (json['t'] as num).toInt(),
      // Optional fields — graceful fallback
      currentN: (json['in'] as num?)?.toDouble() ?? 0.0,
      reactivePower: (json['q'] as num?)?.toDouble() ?? 0.0,
      apparentPower: (json['s'] as num?)?.toDouble() ?? 0.0,
      importEnergy: (json['ei'] as num?)?.toDouble()
          ?? (json['e'] as num?)?.toDouble() ?? 0.0,  // legacy "e" fallback
      exportEnergy: (json['ee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  double valueFor(MetricType type) {
    switch (type) {
      case MetricType.voltage: return voltage;
      case MetricType.current: return current;
      case MetricType.power: return activePower;
      case MetricType.reactivePower: return reactivePower;
      case MetricType.apparentPower: return apparentPower;
      case MetricType.frequency: return frequency;
      case MetricType.energy: return importEnergy;
      case MetricType.powerFactor: return powerFactor;
    }
  }
}
```
- [ ] **Step 4:** Run test to verify it passes
- [ ] **Step 5:** Write `power_event_test.dart`:
```dart
test('parses sag event', () {
  final json = {'ev': 'sag', 'v': 218.3, 'ts': 12345};
  final e = PowerQualityEvent.fromJson(json);
  expect(e.type, EventType.sag);
  expect(e.description, contains('218.3'));
});
```
- [ ] **Step 6:** Create `power_event.dart`:
```dart
enum EventType { sag, swell, freq, lpf }
enum EventSeverity { warning, critical }

class PowerQualityEvent {
  final EventType type;
  final Map<String, double> values;
  final int timestamp;
  final EventSeverity severity;
  final String description;

  // fromJson parses "ev" field to type, remaining numeric fields to values
  // description is auto-generated: "Voltage sag detected (218.3V)"
}
```
- [ ] **Step 7:** Run test to verify it passes
- [ ] **Step 8:** Create `connection_state.dart` (enum), `metric_type.dart` (enum with metadata), `settings_model.dart` with persisted app settings:
  - `deviceIp = '192.168.4.1'`
  - `autoConnect = true`
  - `tariffPrice = 0`
  - `currency = RSD`
  - `voltageThreshold = 10`
  - `freqThreshold = 0.5`
  - `pfThreshold = 0.8`
  - `notificationsEnabled = false`
  - `darkMode = true`
  - `updateInterval = 1000`
  - Note: demo mode remains a separate **debug-only runtime toggle** in `demo_mode_provider.dart`, not part of persisted release settings
- [ ] **Step 9:** Commit: "feat: add data models with JSON parsing and tests"

---

### Task 3: Utilities

**Files:**
- Create: `lib/core/utils/formatters.dart`
- Create: `lib/core/utils/quality_evaluator.dart`
- Create: `lib/core/constants/app_constants.dart`
- Test: `test/utils/formatters_test.dart`
- Test: `test/utils/quality_evaluator_test.dart`

- [ ] **Step 1:** Write `formatters_test.dart`:
```dart
test('voltage formats to 1 decimal', () {
  expect(formatMetric(MetricType.voltage, 230.156), '230.2');
});
test('current formats to 2 decimals', () {
  expect(formatMetric(MetricType.current, 4.1), '4.10');
});
test('power formats to 0 decimals for large values', () {
  expect(formatMetric(MetricType.power, 967.2), '967');
});
```
- [ ] **Step 2:** Write `quality_evaluator_test.dart`:
```dart
test('voltage 230V is normal', () {
  expect(evaluateQuality(MetricType.voltage, 230.0), QualityLevel.normal);
});
test('voltage 215V is warning', () {
  expect(evaluateQuality(MetricType.voltage, 215.0), QualityLevel.warning);
});
test('voltage 205V is critical', () {
  expect(evaluateQuality(MetricType.voltage, 205.0), QualityLevel.critical);
});
```
- [ ] **Step 3:** Implement `formatters.dart` and `quality_evaluator.dart`
- [ ] **Step 4:** Create `app_constants.dart`: default WS URL (`ws://192.168.4.1/ws`), reconnect delays (1s/2s/4s/max 30s), history buffer size (3600), Hive flush interval (30s)
- [ ] **Step 5:** Create `lib/core/utils/downsampler.dart`:
```dart
/// Downsample a list of measurements for chart display.
/// For 1m/5m/15m: return all points.
/// For 1h: every 3rd point (~1200 max).
/// For 24h: one point per 60s window (min/max/avg bucket).
List<Measurement> downsample(List<Measurement> data, int targetPoints) {
  if (data.length <= targetPoints) return data;
  final step = data.length / targetPoints;
  return List.generate(targetPoints, (i) => data[(i * step).floor()]);
}
```
- [ ] **Step 6:** Run all tests: `flutter test`
- [ ] **Step 7:** Commit: "feat: add formatters, quality evaluator, downsampler, constants"

---

### Task 4: Services

**Files:**
- Create: `lib/services/websocket_service.dart`
- Create: `lib/services/mock_data_service.dart`
- Create: `lib/services/measurement_repository.dart`
- Test: `test/services/mock_data_service_test.dart`

- [ ] **Step 1:** Create `websocket_service.dart`:
```dart
class WebSocketService {
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>> connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    return _channel!.stream.map((data) => jsonDecode(data as String) as Map<String, dynamic>);
  }

  void disconnect() { _channel?.sink.close(); }
  bool get isConnected => _channel != null && _channel!.closeCode == null;
}
```
- [ ] **Step 2:** Write `mock_data_service_test.dart` — verify stream emits Measurement-compatible JSON, values in valid ranges (V: 200-260, I: 0-20, f: 49-51)
- [ ] **Step 3:** Create `mock_data_service.dart` — `Timer.periodic(1s)` emitting realistic Brownian-walk measurements via `StreamController`. Voltage walks around 230V (sigma 2V), current around 4A, frequency around 50Hz (sigma 0.02), PF around 0.97. Random events every 30-60s.
- [ ] **Step 4:** Run test to verify
- [ ] **Step 5:** Create `measurement_repository.dart` using JSON serialization (no TypeAdapters/codegen):
```dart
class MeasurementRepository {
  late Box<String> _measurementsBox;  // key=timestamp, value=jsonEncode(measurement)
  late Box<String> _eventsBox;        // key=timestamp, value=jsonEncode(event)
  late Box _settingsBox;              // key=field name, value=primitive

  Future<void> init() async {
    _measurementsBox = await Hive.openBox<String>('measurements');
    _eventsBox = await Hive.openBox<String>('events');
    _settingsBox = await Hive.openBox('settings');
  }

  /// Batch save — called every 30s from provider, NOT every 1Hz reading
  Future<void> saveBatch(List<Measurement> batch) async {
    for (final m in batch) {
      _measurementsBox.put(m.timestamp.toString(), jsonEncode(m.toJson()));
    }
  }

  List<Measurement> getRange(int fromTimestamp, int toTimestamp) {
    // Iterate keys in range, decode JSON
  }

  ({double min, double max, double avg}) getStats(MetricType type, int from, int to) { ... }
  Future<void> clearAll() async { ... }

  SettingsModel loadSettings() { ... }
  Future<void> saveSettings(SettingsModel s) async { ... }
  Future<void> clearEvents() async { ... }
}
```
Note: Add `toJson()` method to Measurement model (inverse of fromJson).
- [ ] **Step 6:** Commit: "feat: add WebSocket, mock data, and Hive repository services"

---

### Task 5: Providers (State Management)

**Files:**
- Create: `lib/providers/demo_mode_provider.dart`
- Create: `lib/providers/connection_provider.dart`
- Create: `lib/providers/measurement_provider.dart`
- Create: `lib/providers/power_events_provider.dart`
- Create: `lib/providers/settings_provider.dart`
- Create: `lib/providers/stats_provider.dart`

- [ ] **Step 1:** Create `demo_mode_provider.dart`: `final demoModeProvider = StateProvider<bool>((ref) => kDebugMode);` (true in debug, false in release)
- [ ] **Step 2:** Create `connection_provider.dart`:
  - `ConnectionNotifier extends StateNotifier<DeviceConnectionState>`
  - `connect(String ip)`: checks demoMode — if true, subscribe to MockDataService; else WebSocketService. After 3 consecutive WS failures, auto-fallback to HttpPollingService (Task 21 adds this).
  - Both services return `Stream<Map<String, dynamic>>`. ConnectionProvider owns the split:
    - If map has `"ev"` key → parse as `PowerQualityEvent`, emit to event stream
    - Else → parse as `Measurement`, emit to measurement stream
  - **Wrap all JSON parsing in try/catch** — drop malformed messages, don't crash
  - Auto-reconnect with exponential backoff (1s, 2s, 4s, max 30s)
  - `disconnect()`: cancel subscriptions, close WS
- [ ] **Step 3:** Create `measurement_provider.dart`:
  - `measurementStreamProvider`: StreamProvider watching connection's measurement stream
  - `latestMeasurementProvider`: derived, holds most recent
  - `measurementHistoryProvider`: StateNotifier maintaining ring buffer of last 3600 readings in memory
  - **Batched Hive writes:** Every 30s, flush unsaved measurements to `MeasurementRepository.saveBatch()`. Also flush on app lifecycle pause (`WidgetsBindingObserver`).
  - For chart queries beyond 1h: read from Hive via repository, not the in-memory buffer
- [ ] **Step 4:** Create `power_events_provider.dart`:
  - StateNotifier accumulating events from connection stream, max 200 in memory, also saves to Hive
  - Add `clearEvents()` method for S5 "Clear" button
  - `clearEvents()` clears in-memory list and calls repository method to clear persisted event log
- [ ] **Step 5:** Create `settings_provider.dart`:
  - StateNotifier persisting `SettingsModel` to Hive via repository
  - Explicitly covers: `deviceIp`, `autoConnect`, `tariffPrice`, `currency`, `voltageThreshold`, `freqThreshold`, `pfThreshold`, `notificationsEnabled`, `darkMode`, `updateInterval`
  - Does **not** own demo mode; demo mode stays in `demo_mode_provider.dart` and is only surfaced in debug builds
- [ ] **Step 6:** Create `stats_provider.dart`: family provider `(MetricType, int secondsBack)` computing min/max/avg. For <=1h: from in-memory history. For >1h: query Hive repository.
- [ ] **Step 7:** Commit: "feat: add Riverpod providers for connection, measurements, settings"

---

### Task 6: Router

**Files:**
- Create: `lib/core/router/app_router.dart`

- [ ] **Step 1:** Configure GoRouter:
  - `/` -> SplashScreen (redirect to `/connect` after 1.5s)
  - `/connect` -> ConnectionScreen (redirect to `/dashboard` when connected)
  - ShellRoute with bottom nav for: `/dashboard`, `/charts`, `/quality`, `/settings`
  - `/settings/export` -> ExportScreen (push on top of shell)
- [ ] **Step 2:** Commit: "feat: add go_router navigation configuration"

---

### Task 7: Common Widgets

**Files:**
- Create: `lib/widgets/common/glass_card.dart`
- Create: `lib/widgets/common/status_dot.dart`
- Create: `lib/widgets/common/metric_value.dart`
- Create: `lib/widgets/common/metric_label.dart`
- Create: `lib/widgets/common/connection_lost_overlay.dart`

- [ ] **Step 1:** Create `glass_card.dart`: Container with GlassDecoration, padding, child. Optional `elevated` flag for different surface tier.
- [ ] **Step 2:** Create `status_dot.dart`: 8px circle, AnimatedContainer for color (green=connected, red=disconnected), pulsing animation with `AnimationController` + `FadeTransition`.
- [ ] **Step 3:** Create `metric_value.dart`: Row of [value in monoLarge/monoMedium] + [unit in smaller colored text]. Takes `double value`, `String unit`, `Color color`, `TextStyle style`. Uses `TweenAnimationBuilder<double>` for smooth number transitions.
- [ ] **Step 4:** Create `metric_label.dart`: Text with Space Grotesk, uppercase, tracking 2.0, on-surface-variant color.
- [ ] **Step 5:** Create `connection_lost_overlay.dart`: Positioned.fill with dark semi-transparent background, centered Column with pulsing WiFi icon, "Connection Lost" text, "Reconnecting..." with animated dots, "Retry" button.
- [ ] **Step 6:** Commit: "feat: add common reusable widgets"

---

### Task 8: Gauge Widgets

**Files:**
- Create: `lib/widgets/gauges/hero_radial_gauge.dart`
- Create: `lib/widgets/gauges/mini_metric_card.dart`
- Create: `lib/widgets/gauges/semi_circular_gauge.dart`
- Create: `lib/widgets/gauges/quality_slider.dart`

- [ ] **Step 1:** Create `hero_radial_gauge.dart`:
  - CustomPainter draws: background arc track (#333348, 6px stroke, 270-degree sweep), gradient fill arc (sweep proportional to value/max, SweepGradient from gradientStart to gradientEnd, round stroke cap), optional tick marks
  - Center child: Column with [MetricLabel, MetricValue (large), range badge]
  - `AnimationController` + `Tween<double>` for smooth arc transitions (300ms, Curves.easeOut)
  - Reference: `UI-stitch/dashboard/code.html` SVG gauge (stroke-dasharray: 251.2, dashoffset calculation)
- [ ] **Step 2:** Create `mini_metric_card.dart`:
  - GlowBorderCard containing: metric icon, MetricLabel, MetricValue (medium size), horizontal LinearProgressIndicator with colored fill + glow shadow
  - Color-coded per metric type
  - Matches the 2x2 grid cards in dashboard mock
- [ ] **Step 3:** Create `semi_circular_gauge.dart`:
  - CustomPainter, 180-degree arc, gradient fill, labels at 0 and max
  - Used for Power Factor on S5
  - Same animation approach as hero gauge
- [ ] **Step 4:** Create `quality_slider.dart`:
  - Stack-based layout: 3-zone background (red zone | green zone | red zone for voltage), positioned marker circle at current value, labels below (min / nominal / max)
  - Takes: `double value`, `double min`, `double nominal`, `double max`, `Color normalColor`
- [ ] **Step 5:** Commit: "feat: add gauge and quality indicator widgets"

---

### Task 9: Chart Widgets

**Files:**
- Create: `lib/widgets/charts/live_line_chart.dart`
- Create: `lib/widgets/charts/sparkline_widget.dart`
- Create: `lib/widgets/charts/time_range_selector.dart`
- Create: `lib/widgets/charts/stats_row.dart`

- [ ] **Step 1:** Create `live_line_chart.dart`:
  - Wraps fl_chart `LineChart` with dark theme styling
  - Props: `List<FlSpot> data`, `Color lineColor`, `double minY`, `double maxY`
  - Config: transparent background, grid lines at surface-variant 10%, line gradient with fill below at 20% opacity, auto-scrolling X axis, `LineTouchData` for long-press tooltip
  - Empty state: centered "Waiting for data..." text
- [ ] **Step 2:** Create `sparkline_widget.dart`:
  - Simplified `LineChart`: no axes, no grid, no labels, just the line + gradient fill
  - Takes `List<double> values` (last 60), `Color color`
  - GestureDetector wrapping for tap-to-navigate
- [ ] **Step 3:** Create `time_range_selector.dart`:
  - Row of `ChoiceChip`-like buttons: "1m", "5m", "15m", "1h", "24h"
  - Active chip: surface-container-high bg, primary text
  - Inactive: transparent, on-surface-variant text
  - Calls `onChanged(int seconds)` callback
- [ ] **Step 4:** Create `stats_row.dart`:
  - Row of 3 columns: Min / Avg / Max
  - Each: MetricLabel on top, MetricValue (monoSmall) below
  - Separated by thin vertical dividers (outline-variant at 15%)
- [ ] **Step 5:** Commit: "feat: add chart and sparkline widgets"

---

### Task 10: Bottom Navigation Bar

**Files:**
- Create: `lib/widgets/nav/bottom_nav_bar.dart`

- [ ] **Step 1:** Create custom bottom nav:
  - Container with: backdrop blur (if performant, else solid #1a1a2e at 90%), rounded top corners (16px), padding
  - Row of 4 items: icon + label
  - Active: primary color icon + label, subtle bg circle with primary at 10%
  - Inactive: on-surface-variant at 60%
  - Labels: monoSmall, uppercase, tracking 1.5
  - Items: Dashboard (dashboard icon), Charts (show_chart), Quality (verified_user), Settings (settings)
  - Calls `onTap(int index)` callback
- [ ] **Step 2:** Commit: "feat: add custom glass bottom navigation bar"

---

### Task 11: Splash Screen (S1)

**Files:**
- Create: `lib/screens/splash_screen.dart`

- [ ] **Step 1:** Build splash screen matching mock:
  - Full screen, scaffold bg color (#111125)
  - Center: bolt icon in rounded square container with primary-container glow
  - "OhmSprint" in displayLarge, "ENERGY MONITOR" in labelSmall between horizontal dividers
  - Linear progress bar (primary-container color, 200px wide)
  - Version text at bottom in monoSmall
  - `Future.delayed(Duration(milliseconds: 1500))` then `context.go('/connect')`
- [ ] **Step 2:** Commit: "feat: add splash screen"

---

### Task 12: Connection Screen (S2)

**Files:**
- Create: `lib/screens/connection_screen.dart`

- [ ] **Step 1:** Build connection screen:
  - Pulsing concentric circles animation (3 rings expanding with decreasing opacity)
  - Center: wifi_tethering icon in circular container with glow
  - "Connecting to EnergyMeter..." text
  - Scan info panel (glass card with monospace key-value pairs: SSID, Protocol, Signal)
  - "Scanning Devices" primary button
  - "Connect Manually" outlined button -> shows dialog with IP text field (pre-filled 192.168.4.1)
  - ConsumerWidget: watches `connectionProvider`, when connected → `context.go('/dashboard')`
  - In demo mode: fake 2s "scanning" animation then auto-connect
- [ ] **Step 2:** Commit: "feat: add connection screen with manual IP entry"

---

### Task 13: Shell Screen (Navigation Scaffold)

**Files:**
- Create: `lib/screens/shell_screen.dart`

- [ ] **Step 1:** Build shell:
  - Scaffold body: `IndexedStack` with 4 children (Dashboard, Charts, Quality, Settings)
  - bottomNavigationBar: custom `BottomNavBar` from Task 10
  - Stack overlay: `ConnectionLostOverlay` shown when connection state != connected
  - Tab state preserved via IndexedStack
- [ ] **Step 2:** Commit: "feat: add shell screen with tab navigation"

---

### Task 14: Dashboard Screen (S3)

**Files:**
- Create: `lib/screens/dashboard_screen.dart`

- [ ] **Step 1:** Build dashboard — the most complex screen. Reference `UI-stitch/dashboard/code.html`:
  - **Header row:** "OhmSprint" logo text + GlassCard pill with StatusDot + device name "EnergyMeter-XXXX" + current time
  - **"LIVE TELEMETRY" section header** with timestamp
  - **HeroRadialGauge** for Active Power (value from latestMeasurement.activePower, max 5000, secondary green gradient)
  - **2x2 GridView** of MiniMetricCards:
    - Voltage (latestMeasurement.voltage, max 300, primary blue)
    - Current (latestMeasurement.current, max 100, error red)
    - Frequency (latestMeasurement.frequency, max 55, min 45, tertiary orange)
    - Power Factor (latestMeasurement.powerFactor, max 1.0, secondary green)
  - **Energy GlassCard:** lightning bolt icon, "CUMULATIVE CONSUMPTION" label, importEnergy value in monoMedium + "kWh", optional cost display if tariff > 0 (value * tariffPrice + currency), trend arrow (compare last reading)
  - **SparklineWidget** showing last 60 power readings from measurementHistory, tappable to navigate to `/charts`
  - Entire body is a SingleChildScrollView
  - ConsumerWidget watching latestMeasurementProvider
- [ ] **Step 2:** Commit: "feat: add dashboard screen with live gauges and energy card"

---

### Task 15: Charts Screen (S4)

**Files:**
- Create: `lib/screens/charts_screen.dart`

- [ ] **Step 1:** Build charts screen. Reference `UI-stitch/charts_screen/code.html`:
  - **Tab bar:** 5 tabs (Voltage, Current, Power, Frequency, Energy) in scrollable row, styled as chips
  - **Current value display:** large monoLarge number + unit for selected metric, delta arrow vs previous minute
  - **LiveLineChart** showing history data filtered by selected MetricType and timeRange
  - **Apply downsampling** before passing data to chart: use `downsample()` utility. For 1h: max ~1200 points. For 24h: max ~1440 points. fl_chart will lag with more.
  - For <=15m ranges: use in-memory history. For 1h/24h: query Hive via repository, then downsample.
  - **TimeRangeSelector** below chart
  - **StatsRow** with min/max/avg from statsProvider
  - NOTE: Do NOT implement "Stability Index" or "Core Temp" (UI-NOTES.md)
  - NOTE: Power tab shows values in **W** not kW (UI-NOTES.md)
  - State: selected tab (MetricType), selected time range (int seconds)
- [ ] **Step 2:** Commit: "feat: add charts screen with live graphs and time range selection"

---

### Task 16: Power Quality Screen (S5)

**Files:**
- Create: `lib/screens/power_quality_screen.dart`

- [ ] **Step 1:** Build power quality screen. Reference `UI-stitch/power_quality/code.html`:
  - NOTE: Do NOT include tamper status section at top (UI-NOTES.md, S6 excluded from v1)
  - NOTE: Do NOT include magnetic field status (UI-NOTES.md)
  - **Power Factor section:** SemiCircularGauge (0.0-1.0), "OPTIMAL"/"WARNING"/"CRITICAL" badge based on qualityEvaluator
  - **Voltage Quality:** QualitySlider with min=207, nominal=230, max=253, current value from latestMeasurement
  - **Frequency Quality:** QualitySlider with min=49.5, nominal=50.0, max=50.5
  - **"QUALITY EVENT LOG" section header** with "Clear" button
  - **Event list:** ListView of PowerQualityEvent items, each in a glass card row with: severity icon (warning yellow / critical red / check green), timestamp in monoSmall, description text
  - Events from powerEventsProvider, sorted newest first
  - Clear button calls `powerEventsProvider.notifier.clearEvents()` with confirmation dialog
- [ ] **Step 2:** Commit: "feat: add power quality screen with gauges and event log"

---

### Task 17: Settings Screen (S7)

**Files:**
- Create: `lib/screens/settings_screen.dart`

- [ ] **Step 1:** Build settings screen. Reference `UI-stitch/settings/code.html`:
  - ScrollView with sections, each in a GlassCard:
  - **Device Connection:** IP text field (settingsProvider.deviceIp), auto-connect Switch, WiFi name read-only
  - **Tariff Configuration:** price/kWh TextField (numeric keyboard), currency DropdownButton (RSD/EUR)
  - **Alert Thresholds:** voltage % Slider (1-20, default 10), frequency Hz TextField, PF threshold TextField, "Enable push notifications" Switch
  - When notifications switch changes from off -> on: request platform notification permission first; if denied, revert toggle and show inline explanation/snackbar
  - **Display:** dark/light theme Switch (toggles settingsProvider.darkMode), update interval DropdownButton (0.5s/1s/2s/5s)
  - **Developer (debug only):** "Demo Mode" Switch bound to `demoModeProvider`; hidden in release builds and not persisted as a user setting
  - **Data Management:** "Export Data" ElevatedButton -> `context.push('/settings/export')`, "Clear Local Data" TextButton with confirmation AlertDialog
  - **About:** "OhmSprint v0.1.0" in headlineMedium, "OhmSprint 2026" label
  - All persisted values read/written through settingsProvider; debug-only demo switch reads/writes `demoModeProvider`
- [ ] **Step 2:** Commit: "feat: add settings screen"

---

### Task 18: Export Screen (S8)

**Files:**
- Create: `lib/screens/export_screen.dart`
- Create: `lib/services/export_service.dart`

- [ ] **Step 1:** Create `export_service.dart`:
  - `Future<String> generateCsv(List<Measurement> data, List<MetricType> metrics)` — uses csv package, writes to temp dir, returns file path
  - `Future<String> generatePdf(List<Measurement> data, List<MetricType> metrics, DateTimeRange range)` — uses pdf package, creates header with "OHMSPRINT" title, data table, min/max/avg stats, returns file path. **Note:** SCREENS.md spec mentions inline charts in PDF — stretch goal for v1. Table + stats are core, chart rendering via `pdf` package LineChart widget if time permits.
  - **PDF export limit:** Cap at 10,000 rows. For larger datasets, auto-downsample before generating PDF. CSV has no limit.
  - `Future<void> shareFile(String path)` — uses share_plus
- [ ] **Step 2:** Build export screen. Reference `UI-stitch/export_report/code.html`:
  - **"Data Synthesis" header**
  - **Temporal Range:** two date picker buttons (from/to), quick select chips ("Last 24h", "Last 7 Days")
  - **Telemetry Nodes:** CheckboxListTile for each MetricType value (V, I, P, Q, S, f, PF, E) — all map to `Measurement.valueFor()`
  - **Output Format:** ToggleButtons or SegmentedButton (CSV / PDF)
  - **Preview section:** GlassCard showing sample data summary (row count, date range, selected metrics)
  - **"Generate Report" primary button** — calls exportService, shows progress indicator
  - **Share button** — appears after generation, calls shareFile
- [ ] **Step 3:** Commit: "feat: add export screen with CSV/PDF generation"

---

### Task 19: App Entry Point and Wiring

**Files:**
- Create: `lib/main.dart`
- Create: `lib/app.dart`

- [ ] **Step 1:** Create `main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Hive.initFlutter();
  final repo = MeasurementRepository();
  await repo.init();
  runApp(ProviderScope(
    overrides: [measurementRepositoryProvider.overrideWithValue(repo)],
    child: const OhmSprintApp(),
  ));
}
```
- [ ] **Step 2:** Create `app.dart`:
```dart
class OhmSprintApp extends ConsumerWidget {
  const OhmSprintApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'OhmSprint',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```
- [ ] **Step 3:** Run `flutter run` — verify splash -> connection -> dashboard flow works with demo data
- [ ] **Step 4:** Commit: "feat: wire up app entry point with Hive init and router"

---

### Task 20: mDNS Device Discovery

**Files:**
- Create: `lib/services/mdns_discovery_service.dart`
- Test: `test/services/mdns_discovery_service_test.dart`
- Modify: `lib/screens/connection_screen.dart`
- Modify: `lib/providers/connection_provider.dart`

ESP32-C3 can advertise itself via mDNS (e.g., `_ohmsprint._tcp`). The app should auto-discover the device before falling back to manual IP entry.

- [ ] **Step 1:** Create `mdns_discovery_service.dart`:
```dart
class MdnsDiscoveryService {
  /// Scans for OhmSprint devices on the local network.
  /// Returns list of discovered devices with IP and name.
  /// Timeout after [duration] seconds.
  Future<List<DiscoveredDevice>> scan({Duration timeout = const Duration(seconds: 5)}) async {
    final client = MDnsClient();
    await client.start();
    final devices = <DiscoveredDevice>[];

    // Listen for _ohmsprint._tcp.local or _http._tcp.local services
    await for (final ptr in client.lookup<ResourceRecordQuery>(
      ResourceRecordQuery.serverPointer('_ohmsprint._tcp.local'),
    ).timeout(timeout, onTimeout: (_) {})) {
      // Resolve SRV → IP address
      await for (final srv in client.lookup<ResourceRecordQuery>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        await for (final ip in client.lookup<ResourceRecordQuery>(
          ResourceRecordQuery.addressIPv4(srv.target),
        )) {
          devices.add(DiscoveredDevice(name: ptr.domainName, ip: ip.address.address, port: srv.port));
        }
      }
    }
    client.stop();
    return devices;
  }
}

class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  const DiscoveredDevice({required this.name, required this.ip, required this.port});
}
```
- [ ] **Step 2:** Write test that verifies scan returns empty list on timeout (mock network)
- [ ] **Step 3:** Update `connection_screen.dart`:
  - On screen load, start mDNS scan with 5s timeout
  - If device found: show device name + IP in scan info panel, auto-fill IP
  - If not found: show "No devices found" after timeout, keep "Connect Manually" option
  - "Scanning Devices" button now triggers real mDNS scan (not just animation)
- [ ] **Step 4:** Update `connection_provider.dart`: `connect()` can now accept IP from mDNS discovery result
- [ ] **Step 5:** Commit: "feat: add mDNS auto-discovery for ESP32 device"

---

### Task 21: HTTP Polling Fallback

**Files:**
- Create: `lib/services/http_polling_service.dart`
- Test: `test/services/http_polling_service_test.dart`
- Modify: `lib/providers/connection_provider.dart`

When WebSocket connection fails repeatedly, fall back to HTTP polling at `http://<device-ip>/api/readings`. Same JSON format, just polled instead of pushed.

- [ ] **Step 1:** Create `http_polling_service.dart`:
```dart
class HttpPollingService {
  final String baseUrl;
  Timer? _timer;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  HttpPollingService(this.baseUrl);

  /// Start polling at the given interval. Returns stream of JSON maps.
  Stream<Map<String, dynamic>> start({Duration interval = const Duration(seconds: 1)}) {
    _timer = Timer.periodic(interval, (_) async {
      try {
        final response = await http.get(Uri.parse('$baseUrl/api/readings'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _controller.add(data);
        }
      } catch (e) {
        // Network error — skip this poll cycle, don't crash
      }
    });
    return _controller.stream;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
```
- [ ] **Step 2:** Write test: mock HTTP responses, verify stream emits parsed JSON
- [ ] **Step 3:** Update `connection_provider.dart`:
  - Primary: try WebSocket connection
  - If WebSocket fails 3 times consecutively: switch to HTTP polling automatically
  - Update connection state to include transport type (ws/http) for UI display
  - If WebSocket reconnects successfully later: switch back to WS
  - Log transport switches for debugging
- [ ] **Step 4:** Update `connection_screen.dart` and `status_dot.dart`: show transport indicator (WS icon vs HTTP icon) so user knows which mode is active
- [ ] **Step 5:** Commit: "feat: add HTTP polling fallback when WebSocket fails"

---

### Task 22: Integration Tests

**Files:**
- Create: `test/integration/data_flow_test.dart`

Full pipeline integration test: MockDataService → ConnectionProvider → MeasurementProvider → MeasurementRepository → Hive. Verifies the entire data flow works end-to-end.

- [ ] **Step 1:** Create `data_flow_test.dart`:
```dart
void main() {
  group('Full data pipeline', () {
    late ProviderContainer container;
    late MeasurementRepository repo;

    setUp(() async {
      await Hive.initFlutter();
      repo = MeasurementRepository();
      await repo.init();
      container = ProviderContainer(overrides: [
        demoModeProvider.overrideWith((_) => true),
        measurementRepositoryProvider.overrideWithValue(repo),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await Hive.deleteFromDisk();
    });

    test('mock data flows through to latest measurement', () async {
      // Trigger connection in demo mode
      container.read(connectionProvider.notifier).connect('mock');

      // Wait for first measurement
      await Future.delayed(const Duration(seconds: 2));

      final latest = container.read(latestMeasurementProvider);
      expect(latest, isNotNull);
      expect(latest!.voltage, inInclusiveRange(200.0, 260.0));
      expect(latest.frequency, inInclusiveRange(49.0, 51.0));
    });

    test('measurements accumulate in history buffer', () async {
      container.read(connectionProvider.notifier).connect('mock');
      await Future.delayed(const Duration(seconds: 5));

      final history = container.read(measurementHistoryProvider);
      expect(history.length, greaterThanOrEqualTo(3));
    });

    test('events are captured from mock stream', () async {
      container.read(connectionProvider.notifier).connect('mock');
      // Mock service emits events every 30-60s, so wait or inject manually
      await Future.delayed(const Duration(seconds: 3));

      // At minimum, provider should be initialized and empty list
      final events = container.read(powerEventsProvider);
      expect(events, isList);
    });

    test('stats compute correctly from history', () async {
      container.read(connectionProvider.notifier).connect('mock');
      await Future.delayed(const Duration(seconds: 5));

      final stats = container.read(statsProvider(MetricType.voltage, 60));
      expect(stats.min, lessThanOrEqualTo(stats.avg));
      expect(stats.avg, lessThanOrEqualTo(stats.max));
    });
  });
}
```
- [ ] **Step 2:** Run `flutter test test/integration/` — verify all pass
- [ ] **Step 3:** Commit: "test: add integration tests for full data pipeline"

---

### Task 23: Push Notifications for Alerts

**Files:**
- Create: `lib/services/notification_service.dart`
- Modify: `lib/providers/power_events_provider.dart`
- Modify: `lib/providers/settings_provider.dart`
- Modify: `lib/screens/settings_screen.dart`

Send local push notifications when voltage/frequency/PF goes out of range. **Foreground-only for v1** — notifications fire while the app is active and receiving data. True background alerting (WorkManager/BGTaskScheduler) is post-v1 due to WiFi lifecycle complexity (phone is on ESP32 AP, OS may drop connection when backgrounded).

- [ ] **Step 1:** Create `notification_service.dart`:
```dart
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(
      android: androidSettings, iOS: iosSettings,
    ));
  }

  Future<bool> requestPermission() async {
    // iOS: request alert/badge/sound permissions
    // Android 13+: request POST_NOTIFICATIONS if needed
    return true; // Replace with real platform permission result
  }

  Future<void> showAlert({
    required String title,
    required String body,
    required int id,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ohmsprint_alerts', 'Power Quality Alerts',
        channelDescription: 'Alerts for voltage, frequency, and power factor anomalies',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }
}
```
- [ ] **Step 2:** Update `power_events_provider.dart`:
  - When a new PowerQualityEvent arrives AND notifications are enabled in settings:
    - Sag event → notification: "Voltage Sag: 218.3V (below 207V threshold)"
    - Swell event → notification: "Voltage Swell: 254.1V (above 253V threshold)"
    - Freq event → notification: "Frequency Deviation: 49.42 Hz"
    - LPF event → notification: "Low Power Factor: 0.68"
  - Debounce: don't send same alert type more than once per 60 seconds
- [ ] **Step 3:** Update `settings_screen.dart`:
  - "Enable push notifications" toggle calls `NotificationService.requestPermission()` on first enable
  - If permission denied: revert toggle and show short explanation
- [ ] **Step 4:** Init `NotificationService` in `main.dart` and provide via Riverpod
- [ ] **Step 5:** Test: trigger events in demo mode, verify notifications appear on a device/emulator with permissions granted
- [ ] **Step 6:** Commit: "feat: add push notifications for power quality alerts"

---

### Task 24: Polish and Edge Cases

- [ ] **Step 1:** Test all tab navigation, verify IndexedStack preserves state
- [ ] **Step 2:** Test connection lost overlay appears/disappears correctly
- [ ] **Step 3:** Test settings persist across app restarts (including dark/light theme toggle)
- [ ] **Step 4:** Test export CSV/PDF generates valid files
- [ ] **Step 5:** Add empty states: charts before first data, event log when empty
- [ ] **Step 6:** Test with `flutter run --release` on a real device for performance
- [ ] **Step 7:** Final commit: "feat: polish UI, add empty states, verify release build"

---

## Verification

### During Development (Demo Mode)
1. `flutter run` — app starts in demo mode, splash -> fake scan -> dashboard with simulated data
2. All gauges animate smoothly with changing values
3. Charts show live scrolling data, downsampling works for 1h/24h ranges
4. Power quality events appear in the log
5. Push notifications fire for voltage/freq/PF alerts while app is foregrounded (verify on device)
6. Settings persist across hot restarts
7. Export generates a valid CSV/PDF file

### With Real Hardware (NTP Beograd, May 4-5)
1. Connect phone to ESP32-C3 WiFi AP
2. If using a debug build: disable Demo Mode in Settings. In release builds, demo mode is already off by default
3. Verify mDNS discovery finds the device automatically
4. If mDNS fails: enter IP 192.168.4.1 manually
5. Verify real measurements match ESP32 web dashboard
6. Test reconnection by briefly turning off ESP32
7. Verify HTTP fallback activates after WS failure
8. Test with real load changes (plug in/out a lamp)
9. Verify foreground push notifications on real power quality events after notification permission is granted

### Run Tests
```bash
cd Code/Mobile/ohmsprint
flutter test                           # All unit tests
flutter test test/integration/         # Integration tests
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| fl_chart performance with 3600+ points | Limit visible window, downsample for 24h view |
| BackdropFilter (glass blur) laggy on low-end Android | Fallback to solid semi-transparent color |
| Font loading flicker | Bundle fonts as assets, don't rely on CDN |
| Hive performance with large datasets | Prune data older than 30 days, use lazy boxes |
| WebSocket reconnection races | State machine prevents concurrent connect attempts |
