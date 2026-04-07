import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum MetricType {
  voltage(
    label: 'Voltage',
    shortLabel: 'V',
    unit: 'V',
    color: AppColors.voltage,
    minValue: 207,
    maxValue: 253,
  ),
  current(
    label: 'Current',
    shortLabel: 'I',
    unit: 'A',
    color: AppColors.current,
    minValue: 0,
    maxValue: 100,
  ),
  power(
    label: 'Active Power',
    shortLabel: 'P',
    unit: 'W',
    color: AppColors.power,
    minValue: -5000,
    maxValue: 5000,
  ),
  reactivePower(
    label: 'Reactive Power',
    shortLabel: 'Q',
    unit: 'VAR',
    color: AppColors.power,
    minValue: -5000,
    maxValue: 5000,
  ),
  apparentPower(
    label: 'Apparent Power',
    shortLabel: 'S',
    unit: 'VA',
    color: AppColors.power,
    minValue: 0,
    maxValue: 5000,
  ),
  frequency(
    label: 'Frequency',
    shortLabel: 'f',
    unit: 'Hz',
    color: AppColors.frequency,
    minValue: 49,
    maxValue: 51,
  ),
  energy(
    label: 'Energy',
    shortLabel: 'E',
    unit: 'kWh',
    color: AppColors.energy,
    minValue: 0,
    maxValue: 100000,
  ),
  powerFactor(
    label: 'Power Factor',
    shortLabel: 'PF',
    unit: '',
    color: AppColors.powerFactor,
    minValue: -1,
    maxValue: 1,
  );

  const MetricType({
    required this.label,
    required this.shortLabel,
    required this.unit,
    required this.color,
    required this.minValue,
    required this.maxValue,
  });

  final String label;
  final String shortLabel;
  final String unit;
  final Color color;
  final double minValue;
  final double maxValue;
}
