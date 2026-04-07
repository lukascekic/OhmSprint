import '../constants/app_constants.dart';
import '../models/metric_type.dart';

enum QualityLevel { normal, warning, critical }

QualityLevel evaluateQuality(MetricType type, double value) {
  switch (type) {
    case MetricType.voltage:
      if (value < AppConstants.voltageCriticalMin ||
          value > AppConstants.voltageCriticalMax) {
        return QualityLevel.critical;
      }
      if (value < AppConstants.voltageWarningMin ||
          value > AppConstants.voltageWarningMax) {
        return QualityLevel.warning;
      }
      return QualityLevel.normal;
    case MetricType.frequency:
      if (value < AppConstants.frequencyCriticalMin ||
          value > AppConstants.frequencyCriticalMax) {
        return QualityLevel.critical;
      }
      if (value < AppConstants.frequencyWarningMin ||
          value > AppConstants.frequencyWarningMax) {
        return QualityLevel.warning;
      }
      return QualityLevel.normal;
    case MetricType.powerFactor:
      if (value < AppConstants.powerFactorCriticalMin) {
        return QualityLevel.critical;
      }
      if (value < AppConstants.powerFactorWarningMin) {
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
