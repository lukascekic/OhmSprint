import '../constants/app_constants.dart';
import '../models/metric_type.dart';
import '../models/settings_model.dart';

enum QualityLevel { normal, warning, critical }

QualityLevel evaluateQuality(
  MetricType type,
  double value, {
  SettingsModel? settings,
}) {
  switch (type) {
    case MetricType.voltage:
      if (value < voltageCriticalMin(settings) ||
          value > voltageCriticalMax(settings)) {
        return QualityLevel.critical;
      }
      if (value < voltageWarningMin(settings) ||
          value > voltageWarningMax(settings)) {
        return QualityLevel.warning;
      }
      return QualityLevel.normal;
    case MetricType.frequency:
      if (value < frequencyCriticalMin(settings) ||
          value > frequencyCriticalMax(settings)) {
        return QualityLevel.critical;
      }
      if (value < frequencyWarningMin(settings) ||
          value > frequencyWarningMax(settings)) {
        return QualityLevel.warning;
      }
      return QualityLevel.normal;
    case MetricType.powerFactor:
      if (value < powerFactorCriticalMin(settings)) {
        return QualityLevel.critical;
      }
      if (value < powerFactorWarningMin(settings)) {
        return QualityLevel.warning;
      }
      return QualityLevel.normal;
    case MetricType.current:
    case MetricType.power:
    case MetricType.reactivePower:
    case MetricType.apparentPower:
    case MetricType.energy:
      // No quality thresholds are defined for these metrics yet.
      return QualityLevel.normal;
  }
}

double voltageCriticalMin(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.voltageCriticalMin;
  }
  return _nominalVoltage * (1 - (_safeVoltageBand(settings) / 100));
}

double voltageCriticalMax(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.voltageCriticalMax;
  }
  return _nominalVoltage * (1 + (_safeVoltageBand(settings) / 100));
}

double voltageWarningMin(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.voltageWarningMin;
  }
  return _nominalVoltage * (1 - (_safeVoltageBand(settings) / 200));
}

double voltageWarningMax(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.voltageWarningMax;
  }
  return _nominalVoltage * (1 + (_safeVoltageBand(settings) / 200));
}

double frequencyCriticalMin(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.frequencyCriticalMin;
  }
  return _nominalFrequency - _safeFrequencyBand(settings);
}

double frequencyCriticalMax(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.frequencyCriticalMax;
  }
  return _nominalFrequency + _safeFrequencyBand(settings);
}

double frequencyWarningMin(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.frequencyWarningMin;
  }
  return _nominalFrequency - (_safeFrequencyBand(settings) * 0.4);
}

double frequencyWarningMax(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.frequencyWarningMax;
  }
  return _nominalFrequency + (_safeFrequencyBand(settings) * 0.4);
}

double powerFactorCriticalMin(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.powerFactorCriticalMin;
  }
  return settings.pfThreshold.clamp(0, 1).toDouble();
}

double powerFactorWarningMin(SettingsModel? settings) {
  if (settings == null) {
    return AppConstants.powerFactorWarningMin;
  }
  final critical = powerFactorCriticalMin(settings);
  return critical + ((1 - critical) / 2);
}

const double _nominalVoltage = 230;
const double _nominalFrequency = 50;

double _safeVoltageBand(SettingsModel settings) {
  return settings.voltageThreshold.clamp(0, 100).toDouble();
}

double _safeFrequencyBand(SettingsModel settings) {
  return settings.freqThreshold.clamp(0, 50).toDouble();
}
