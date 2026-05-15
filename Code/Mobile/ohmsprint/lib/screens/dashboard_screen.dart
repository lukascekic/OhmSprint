import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/models/connection_state.dart';
import '../core/models/measurement.dart';
import '../core/models/metric_type.dart';
import '../core/models/settings_model.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import '../providers/connection_provider.dart';
import '../providers/measurement_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/charts/sparkline_widget.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/metric_label.dart';
import '../widgets/common/status_dot.dart';
import '../widgets/gauges/hero_radial_gauge.dart';
import '../widgets/gauges/mini_metric_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestMeasurement = ref.watch(latestMeasurementProvider);
    final history = ref.watch(measurementHistoryProvider);
    final connectionState = ref.watch(connectionProvider);
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final isDemoStream = connectionState.transport == ConnectionTransport.mock;
    final deviceName = _deviceName(connectionState);
    final powerValues =
        history.map((measurement) => measurement.activePower).toList();
    final sparklineValues = powerValues.length > 60
        ? powerValues.sublist(powerValues.length - 60)
        : powerValues;

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DashboardHeader(
                deviceName: deviceName,
                time: now,
                isConnected: connectionState.isConnected,
                transport: connectionState.transport,
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: isDemoStream ? 'DEMO TELEMETRY' : 'LIVE TELEMETRY',
                trailing: isDemoStream
                    ? 'SIMULATED STREAM'
                    : DateFormat('HH:mm:ss').format(now),
              ),
              const SizedBox(height: 10),
              Center(
                child: HeroRadialGauge(
                  label: 'Active Power',
                  value: latestMeasurement?.activePower ?? 0,
                  minValue: 0,
                  maxValue: 5000,
                  unit: MetricType.power.unit,
                  gradientStart: const Color(0xFF00761F),
                  gradientEnd: AppColors.secondary,
                  rangeLabel: '0-5000W RANGE',
                  showTicks: true,
                  formatter: (value) => formatMetric(MetricType.power, value),
                ),
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                childAspectRatio: 1.18,
                children: [
                  MiniMetricCard(
                    metricType: MetricType.voltage,
                    value: latestMeasurement?.voltage ?? 0,
                    icon: Icons.electric_bolt_rounded,
                    formatter: (value) =>
                        formatMetric(MetricType.voltage, value),
                    progress:
                        ((latestMeasurement?.voltage ?? 0) / 300).clamp(0, 1),
                  ),
                  MiniMetricCard(
                    metricType: MetricType.current,
                    value: latestMeasurement?.current ?? 0,
                    icon: Icons.settings_input_component_rounded,
                    formatter: (value) =>
                        formatMetric(MetricType.current, value),
                  ),
                  MiniMetricCard(
                    metricType: MetricType.frequency,
                    value: latestMeasurement?.frequency ?? 0,
                    icon: Icons.waves_rounded,
                    formatter: (value) =>
                        formatMetric(MetricType.frequency, value),
                    progress: (((latestMeasurement?.frequency ?? 45) - 45) / 10)
                        .clamp(0, 1),
                  ),
                  MiniMetricCard(
                    metricType: MetricType.powerFactor,
                    value: latestMeasurement?.powerFactor ?? 0,
                    icon: Icons.equalizer_rounded,
                    formatter: (value) =>
                        formatMetric(MetricType.powerFactor, value),
                    progress: (((latestMeasurement?.powerFactor ?? 0) + 1) / 2)
                        .clamp(0, 1),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _EnergyCard(
                latestMeasurement: latestMeasurement,
                previousMeasurement:
                    history.length > 1 ? history[history.length - 2] : null,
                settings: settings,
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'LOAD PROFILE (60S)',
                      trailing:
                          isDemoStream ? 'SIMULATED FEED' : 'REAL-TIME FEED',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 88,
                      child: sparklineValues.isEmpty
                          ? Center(
                              child: Text(
                                isDemoStream
                                    ? 'Awaiting demo telemetry...'
                                    : 'Awaiting live telemetry...',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            )
                          : SparklineWidget(
                              values: sparklineValues,
                              color: AppColors.primary,
                              onTap: () => context.go('/charts'),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _deviceName(DeviceConnectionState connectionState) {
    if (connectionState.transport == ConnectionTransport.mock) {
      return 'Demo Stream';
    }

    final ipAddress = connectionState.ipAddress;
    if (ipAddress == null || ipAddress.isEmpty) {
      return 'EnergyMeter';
    }

    final digits = ipAddress.replaceAll(RegExp(r'[^0-9]'), '');
    final suffix = digits.isEmpty
        ? 'DEMO'
        : digits
            .padLeft(4, '0')
            .substring(digits.length >= 4 ? digits.length - 4 : 0);
    return 'EnergyMeter-$suffix';
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.deviceName,
    required this.time,
    required this.isConnected,
    required this.transport,
  });

  final String deviceName;
  final DateTime time;
  final bool isConnected;
  final ConnectionTransport? transport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'OhmSprint',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Spacer(),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              StatusDot(
                isConnected: isConnected,
                size: 8,
                transport: transport,
              ),
              const SizedBox(width: 8),
              Text(
                deviceName,
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          DateFormat('HH:mm:ss').format(time),
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.trailing,
  });

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        MetricLabel(title),
        Text(
          trailing,
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({
    required this.latestMeasurement,
    required this.previousMeasurement,
    required this.settings,
  });

  final Measurement? latestMeasurement;
  final Measurement? previousMeasurement;
  final SettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final importEnergy = latestMeasurement?.importEnergy ?? 0;
    final previousImportEnergy =
        previousMeasurement?.importEnergy ?? importEnergy;
    final delta = importEnergy - previousImportEnergy;
    final trendUp = delta >= 0;
    final showCost = settings.tariffPrice > 0;
    final currency = settings.currency == Currency.rsd ? 'RSD' : 'EUR';

    return GlassCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: MetricLabel('Cumulative Consumption'),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_flat_rounded,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${delta.abs().toStringAsFixed(2)} kWh',
                      style: AppTypography.monoSmall.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMetric(MetricType.energy, importEnergy),
                style: AppTypography.monoLarge.copyWith(
                  fontSize: 34,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'kWh',
                  style: AppTypography.monoMedium.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          if (showCost) ...[
            const SizedBox(height: 8),
            Text(
              '${(importEnergy * settings.tariffPrice).toStringAsFixed(2)} $currency',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
