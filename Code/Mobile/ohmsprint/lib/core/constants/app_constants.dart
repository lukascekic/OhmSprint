class AppConstants {
  const AppConstants._();

  static const String defaultWsUrl = 'ws://192.168.4.1/ws';

  static const double voltageCriticalMin = 207;
  static const double voltageWarningMin = 220;
  static const double voltageWarningMax = 240;
  static const double voltageCriticalMax = 253;

  static const double frequencyCriticalMin = 49.5;
  static const double frequencyWarningMin = 49.8;
  static const double frequencyWarningMax = 50.2;
  static const double frequencyCriticalMax = 50.5;

  static const double powerFactorWarningMin = 0.9;
  static const double powerFactorCriticalMin = 0.8;

  static const Duration reconnectDelayInitial = Duration(seconds: 1);
  static const Duration reconnectDelaySecondary = Duration(seconds: 2);
  static const Duration reconnectDelayTertiary = Duration(seconds: 4);
  static const Duration reconnectDelayMax = Duration(seconds: 30);

  /// 1 hour of 1 Hz samples.
  static const int historyBufferSize = 3600;
  static const int powerEventBufferSize = 200;
  static const Duration hiveFlushInterval = Duration(seconds: 30);
}
