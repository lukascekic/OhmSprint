import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../common/metric_label.dart';
import '../common/metric_value.dart';

class HeroRadialGauge extends StatefulWidget {
  const HeroRadialGauge({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.unit,
    required this.gradientStart,
    required this.gradientEnd,
    super.key,
    this.minValue = 0,
    this.size = 240,
    this.rangeLabel,
    this.showTicks = false,
    this.formatter,
  });

  final String label;
  final double value;
  final double minValue;
  final double maxValue;
  final String unit;
  final Color gradientStart;
  final Color gradientEnd;
  final double size;
  final String? rangeLabel;
  final bool showTicks;
  final String Function(double value)? formatter;

  @override
  State<HeroRadialGauge> createState() => _HeroRadialGaugeState();
}

class _HeroRadialGaugeState extends State<HeroRadialGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final initialProgress = _normalizedValue(widget.value);
    _progress = AlwaysStoppedAnimation<double>(initialProgress);
  }

  @override
  void didUpdateWidget(covariant HeroRadialGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value &&
        oldWidget.minValue == widget.minValue &&
        oldWidget.maxValue == widget.maxValue) {
      return;
    }

    final nextProgress = _normalizedValue(widget.value);
    final begin = _progress.value;

    _progress = Tween<double>(
      begin: begin,
      end: nextProgress,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _normalizedValue(double value) {
    final span = widget.maxValue - widget.minValue;
    if (span <= 0) {
      return 0;
    }

    return ((value - widget.minValue) / span).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final badgeText = widget.rangeLabel ??
        '${widget.minValue.toStringAsFixed(0)}-${widget.maxValue.toStringAsFixed(0)}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''}';

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _HeroRadialGaugePainter(
                  progress: _progress.value,
                  gradientStart: widget.gradientStart,
                  gradientEnd: widget.gradientEnd,
                  showTicks: widget.showTicks,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MetricLabel(widget.label, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    MetricValue(
                      value: widget.value,
                      unit: widget.unit,
                      color: widget.gradientEnd,
                      style: AppTypography.monoLarge.copyWith(
                        color: AppColors.onSurface,
                      ),
                      formatter: widget.formatter,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            AppColors.surfaceContainer.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: widget.gradientEnd.withValues(alpha: 0.18),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: AppTypography.monoSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroRadialGaugePainter extends CustomPainter {
  const _HeroRadialGaugePainter({
    required this.progress,
    required this.gradientStart,
    required this.gradientEnd,
    required this.showTicks,
  });

  final double progress;
  final Color gradientStart;
  final Color gradientEnd;
  final bool showTicks;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.025;
    final rect = Rect.fromLTWH(
      strokeWidth,
      strokeWidth,
      size.width - (strokeWidth * 2),
      size.height - (strokeWidth * 2),
    );
    const startAngle = 3 * math.pi / 4;
    const sweepAngle = 3 * math.pi / 2;

    final trackPaint = Paint()
      ..color = AppColors.surfaceContainerHighest
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    if (showTicks) {
      final tickPaint = Paint()
        ..color = AppColors.outlineVariant.withValues(alpha: 0.4)
        ..strokeWidth = 1;
      final radius = rect.width / 2;
      final center = rect.center;

      for (var index = 0; index <= 12; index++) {
        final tickAngle = startAngle + (sweepAngle * (index / 12));
        final outer = Offset(
          center.dx + math.cos(tickAngle) * (radius + strokeWidth * 0.8),
          center.dy + math.sin(tickAngle) * (radius + strokeWidth * 0.8),
        );
        final inner = Offset(
          center.dx + math.cos(tickAngle) * (radius - strokeWidth * 1.2),
          center.dy + math.sin(tickAngle) * (radius - strokeWidth * 1.2),
        );
        canvas.drawLine(inner, outer, tickPaint);
      }
    }

    if (progress <= 0) {
      return;
    }

    final fillPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          gradientStart,
          gradientEnd,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroRadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gradientStart != gradientStart ||
        oldDelegate.gradientEnd != gradientEnd ||
        oldDelegate.showTicks != showTicks;
  }
}
