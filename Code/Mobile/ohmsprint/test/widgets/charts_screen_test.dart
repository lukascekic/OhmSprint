import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/providers/connection_provider.dart';
import 'package:ohmsprint/providers/measurement_provider.dart';
import 'package:ohmsprint/screens/charts_screen.dart';
import 'package:ohmsprint/services/notification_service.dart';

import '../test_support/app_fakes.dart';

void main() {
  testWidgets('shows an empty state before the first telemetry sample', (
    tester,
  ) async {
    final repository = InMemoryMeasurementRepository();
    final connectionNotifier = TestConnectionNotifier();

    addTearDown(connectionNotifier.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          measurementRepositoryProvider.overrideWithValue(repository),
          connectionProvider.overrideWith((ref) => connectionNotifier),
          notificationServiceProvider.overrideWithValue(
            SilentNotificationService(),
          ),
        ],
        child: const MaterialApp(
          home: ChartsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No telemetry data yet'), findsOneWidget);
    expect(
      find.text(
        'Connect to a device or keep demo mode enabled to start plotting live measurements.',
      ),
      findsOneWidget,
    );
  });
}
