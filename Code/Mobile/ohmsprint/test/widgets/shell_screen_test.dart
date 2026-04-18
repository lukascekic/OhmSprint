import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/connection_state.dart';
import 'package:ohmsprint/providers/connection_provider.dart';
import 'package:ohmsprint/providers/measurement_provider.dart';
import 'package:ohmsprint/screens/shell_screen.dart';
import 'package:ohmsprint/services/notification_service.dart';

import '../test_support/app_fakes.dart';

void main() {
  testWidgets('IndexedStack preserves charts state across tab switches', (
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
          home: _ShellHarness(
            initialLocation: '/charts',
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Active Load'), findsOneWidget);

    await tester.tap(find.text('Voltage').first);
    await tester.pumpAndSettle();

    expect(find.text('Active Load'), findsNothing);

    await tester.tap(find.text('Show Dashboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Charts'));
    await tester.pumpAndSettle();

    expect(find.text('Active Load'), findsNothing);
  });

  testWidgets('connection lost overlay appears and disappears with state', (
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
          home: _ShellHarness(
            initialLocation: '/dashboard',
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Connection Lost'), findsNothing);

    connectionNotifier.setConnectionState(
      const DeviceConnectionState(
        status: ConnectionStatus.reconnecting,
        transport: ConnectionTransport.websocket,
        ipAddress: '192.168.4.1',
      ),
    );
    await tester.pump();

    expect(find.text('Connection Lost'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    connectionNotifier.setConnectionState(
      const DeviceConnectionState(
        status: ConnectionStatus.connected,
        transport: ConnectionTransport.websocket,
        ipAddress: '192.168.4.1',
      ),
    );
    await tester.pump();

    expect(find.text('Connection Lost'), findsNothing);
  });
}

class _ShellHarness extends StatefulWidget {
  const _ShellHarness({
    required this.initialLocation,
    required this.child,
  });

  final String initialLocation;
  final Widget child;

  @override
  State<_ShellHarness> createState() => _ShellHarnessState();
}

class _ShellHarnessState extends State<_ShellHarness> {
  late String _location;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ShellScreen(
            location: _location,
            child: widget.child,
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => setState(() => _location = '/dashboard'),
                  child: const Text('Show Dashboard'),
                ),
                TextButton(
                  onPressed: () => setState(() => _location = '/charts'),
                  child: const Text('Show Charts'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
