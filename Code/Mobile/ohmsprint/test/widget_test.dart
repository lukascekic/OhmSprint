import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohmsprint/app.dart';
import 'package:ohmsprint/core/models/measurement.dart';
import 'package:ohmsprint/core/models/settings_model.dart';
import 'package:ohmsprint/providers/measurement_provider.dart';
import 'package:ohmsprint/services/measurement_repository.dart';

class _FakeMeasurementRepository extends MeasurementRepository {
  @override
  Future<void> init() async {}

  @override
  List<Measurement> getRange(int fromTimestamp, int toTimestamp) {
    return const [];
  }

  @override
  SettingsModel loadSettings() {
    return const SettingsModel();
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {}
}

void main() {
  testWidgets('renders splash app shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          measurementRepositoryProvider.overrideWithValue(
            _FakeMeasurementRepository(),
          ),
        ],
        child: const OhmSprintApp(),
      ),
    );

    await tester.pump();

    expect(find.text('OhmSprint'), findsOneWidget);
    expect(find.text('ENERGY MONITOR'), findsOneWidget);
  });
}
