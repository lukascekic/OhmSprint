import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/models/connection_state.dart';
import '../core/models/metric_type.dart';
import '../core/models/power_event.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import '../core/utils/quality_evaluator.dart';
import '../providers/measurement_provider.dart';
import '../providers/power_events_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/metric_label.dart';
import '../widgets/gauges/quality_slider.dart';
import '../widgets/gauges/semi_circular_gauge.dart';


const double _nominalVoltage = 230;
const double _nominalFrequency = 50;
const double _nominalPowerFactor = 1;
const int _visibleEventLimit = 20;

class PowerQualityScreen extends ConsumerWidget {
  const PowerQualityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestMeasurement = ref.watch(latestMeasurementProvider);
    final events = ref.watch(powerEventsProvider);
    final connectionState = ref.watch(connectionProvider);
    final settings = ref.watch(settingsProvider);
    final hasMeasurement = latestMeasurement != null;
    final isDemoStream = connectionState.transport == ConnectionTransport.mock;
    final visibleEvents = events.length > _visibleEventLimit
        ? events.sublist(0, _visibleEventLimit)
        : events;

    final powerFactor = latestMeasurement?.powerFactor ?? _nominalPowerFactor;
    final voltage = latestMeasurement?.voltage ?? _nominalVoltage;
    final frequency = latestMeasurement?.frequency ?? _nominalFrequency;
    final powerFactorLevel = hasMeasurement
        ? evaluateQuality(
            MetricType.powerFactor,
            powerFactor,
            settings: settings,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                elevated: true,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const MetricLabel('Power Factor'),
                              const SizedBox(height: 8),
                              Text(
                                latestMeasurement == null
                                    ? 'Awaiting telemetry'
                                    : isDemoStream
                                        ? 'Demo phase alignment and load quality'
                                        : 'Live phase alignment and load quality',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _QualityBadge(level: powerFactorLevel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: SemiCircularGauge(
                        label: 'Power Factor',
                        value: powerFactor,
                        minValue: 0,
                        maxValue: 1,
                        gradientStart: const Color(0xFF00761F),
                        gradientEnd: AppColors.secondary,
                        formatter: (value) => !hasMeasurement
                            ? '--'
                            : formatMetric(MetricType.powerFactor, value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: _QualityMetricCard(
                  title: 'Voltage Quality',
                  valueText: latestMeasurement == null
                      ? '--'
                      : '${formatMetric(MetricType.voltage, voltage)}V',
                  slider: QualitySlider(
                    value: voltage,
                    min: voltageCriticalMin(settings),
                    nominal: _nominalVoltage,
                    max: voltageCriticalMax(settings),
                    normalColor: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: _QualityMetricCard(
                  title: 'Frequency Quality',
                  valueText: latestMeasurement == null
                      ? '--'
                      : '${formatMetric(MetricType.frequency, frequency)}Hz',
                  slider: QualitySlider(
                    value: frequency,
                    min: frequencyCriticalMin(settings),
                    nominal: _nominalFrequency,
                    max: frequencyCriticalMax(settings),
                    normalColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: MetricLabel('Quality Event Log'),
                  ),
                  TextButton(
                    onPressed: events.isEmpty
                        ? null
                        : () => _confirmClearEvents(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (events.isEmpty)
                const _EmptyEventState()
              else ...[
                // The visible cap keeps this shrink-wrapped list safe inside
                // the parent scroll view without unbounded layout cost.
                ListView.separated(
                  itemCount: visibleEvents.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _EventCard(event: visibleEvents[index]);
                  },
                ),
                if (events.length > visibleEvents.length) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Showing the $_visibleEventLimit most recent events.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearEvents(BuildContext context, WidgetRef ref) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Text(
            'Clear quality events?',
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 20,
              color: AppColors.onSurface,
            ),
          ),
          content: Text(
            'This will remove all locally stored voltage, frequency, and power factor alerts.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surfaceDim,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || shouldClear != true) {
      return;
    }

    try {
      await ref.read(powerEventsProvider.notifier).clearEvents();
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceContainerHigh,
          content: Text(
            'Could not clear quality events right now.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ),
      );
    }
  }
}

class _QualityMetricCard extends StatelessWidget {
  const _QualityMetricCard({
    required this.title,
    required this.valueText,
    required this.slider,
  });

  final String title;
  final String valueText;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: MetricLabel(title),
            ),
            Text(
              valueText,
              style: AppTypography.monoMedium.copyWith(
                color: AppColors.primary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        slider,
      ],
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.level});

  final QualityLevel? level;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (level) {
      null => (
          'NO DATA',
          AppColors.onSurfaceVariant,
          AppColors.surfaceBright.withValues(alpha: 0.28),
        ),
      QualityLevel.normal => (
          'OPTIMAL',
          AppColors.secondary,
          AppColors.secondary.withValues(alpha: 0.12),
        ),
      QualityLevel.warning => (
          'WARNING',
          AppColors.tertiary,
          AppColors.tertiary.withValues(alpha: 0.14),
        ),
      QualityLevel.critical => (
          'CRITICAL',
          AppColors.error,
          AppColors.error.withValues(alpha: 0.14),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.monoSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final PowerQualityEvent event;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (event.severity) {
      EventSeverity.warning => Icons.warning_amber_rounded,
      EventSeverity.critical => Icons.error_outline_rounded,
    };
    final accentColor = switch (event.severity) {
      EventSeverity.warning => AppColors.tertiary,
      EventSeverity.critical => AppColors.error,
    };
    final subtitle = _subtitle(event);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              iconData,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.description,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatTimestamp(event.timestamp),
                      style: AppTypography.monoSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) {
      return '--:--:--';
    }

    return DateFormat('HH:mm:ss').format(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  String _subtitle(PowerQualityEvent event) {
    return switch (event.type) {
      EventType.sag =>
        'Below nominal band. Auto-recovered if readings stabilized.',
      EventType.swell =>
        'Above nominal band. Check for over-voltage conditions.',
      EventType.freq =>
        'Frequency drift detected outside the preferred operating band.',
      EventType.lpf =>
        'Reactive load spike reduced power factor below threshold.',
    };
  }
}

class _EmptyEventState extends StatelessWidget {
  const _EmptyEventState();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.secondary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No quality events yet',
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 18,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Voltage, frequency, and low PF alerts will appear here as the stream runs.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
