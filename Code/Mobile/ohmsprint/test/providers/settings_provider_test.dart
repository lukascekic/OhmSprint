import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/settings_model.dart';
import 'package:ohmsprint/providers/settings_provider.dart';

import '../test_support/app_fakes.dart';

void main() {
  test('settings persist across notifier recreation', () async {
    final repository = InMemoryMeasurementRepository();
    final notifier = SettingsNotifier(repository);

    await notifier.setDarkMode(false);
    await notifier.setTariffPrice(17.45);
    await notifier.setCurrency(Currency.eur);
    await notifier.setDeviceIp('192.168.4.2');
    await notifier.setDemoMode(false);

    final restored = SettingsNotifier(repository);

    expect(restored.state.darkMode, isFalse);
    expect(restored.state.tariffPrice, 17.45);
    expect(restored.state.currency, Currency.eur);
    expect(restored.state.deviceIp, '192.168.4.2');
    expect(restored.state.demoMode, isFalse);
  });
}
