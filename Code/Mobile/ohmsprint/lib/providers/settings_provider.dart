import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/settings_model.dart';
import '../services/measurement_repository.dart';
import 'measurement_provider.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  return SettingsNotifier(ref.watch(measurementRepositoryProvider));
});

class SettingsNotifier extends StateNotifier<SettingsModel> {
  SettingsNotifier(this._repository) : super(_repository.loadSettings());

  final MeasurementRepository _repository;

  Future<void> setDeviceIp(String value) =>
      _update(state.copyWith(deviceIp: value));
  Future<void> setAutoConnect(bool value) =>
      _update(state.copyWith(autoConnect: value));
  Future<void> setTariffPrice(double value) =>
      _update(state.copyWith(tariffPrice: value));
  Future<void> setCurrency(Currency value) =>
      _update(state.copyWith(currency: value));
  Future<void> setVoltageThreshold(double value) =>
      _update(state.copyWith(voltageThreshold: value));
  Future<void> setFreqThreshold(double value) =>
      _update(state.copyWith(freqThreshold: value));
  Future<void> setPfThreshold(double value) =>
      _update(state.copyWith(pfThreshold: value));
  Future<void> setNotificationsEnabled(bool value) =>
      _update(state.copyWith(notificationsEnabled: value));
  Future<void> setDarkMode(bool value) =>
      _update(state.copyWith(darkMode: value));
  Future<void> setUpdateInterval(int value) =>
      _update(state.copyWith(updateInterval: value));
  Future<void> setDemoMode(bool value) =>
      _update(state.copyWith(demoMode: value));

  Future<void> _update(SettingsModel nextState) async {
    state = nextState;
    await _repository.saveSettings(nextState);
  }
}
