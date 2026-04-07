import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../common/metric_label.dart';
import '../common/metric_value.dart';

class SemiCircularGauge extends StatefulWidget {
  const SemiCircularGauge({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.gradientStart,
    required this.gradientEnd,
    super.key,
    this.minValue = 0,
    this.unit = '',
    this.width = 240,
    this.formatter,
  });

  final String label;
  final double value;
  final double minValue;
  final double maxValue;
  final String unit;
  final Color gradientStart;
  final Color gradientEnd;
  final double width;
  final String Function(double value)? formatter;

  @override
  State<SemiCircularGauge> createState() => _SemiCircularGaugeState();
}

class _SemiCircularGaugeState extends State<SemiCircularGauge>
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
    _progress = AlwaysStoppedAnimation<double>(_normalizedValue(widget.value));
  }

  @override
  void didUpdateWidget(covariant SemiCircularGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value &&
        oldWidget.minValue == widget.minValue &&
        oldWidget.maxValue == widget.maxValue) {
      return;
    }

    final begin = _progress.value;
    final end = _normalizedValue(widget.value);

    _progress = Tween<double>(
      begin: begin,
      end: end,
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
    return SizedBox(
      width: widget.width,
      height: widget.width * 0.72,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.width, widget.width * 0.72),
                painter: _SemiCircularGaugePainter(
                  progress: _progress.value,
                  gradientStart: widget.gradientStart,
                  gradientEnd: widget.gradientEnd,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MetricLabel(widget.label, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    MetricValue(
                      value: widget.value,
                      unit: widget.unit,
                      color: widget.gradientEnd,
                      style: AppTypography.monoMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                      formatter: widget.formatter,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.minValue.toStringAsFixed(0),
                          style: AppTypography.monoSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          widget.maxValue.toStringAsFixed(0),
                          style: AppTypography.monoSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
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

class _SemiCircularGaugePainter extends CustomPainter {
  const _SemiCircularGaugePainter({
    required this.progress,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final double progress;
  final Color gradientStart;
  final Color gradientEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.032;
    final rect = Rect.fromLTWH(
      strokeWidth,
      strokeWidth,
      size.width - (strokeWidth * 2),
      (size.width - (strokeWidth * 2)),
    );
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    final trackPaint = Paint()
      ..color = AppColors.surfaceContainerHighest
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

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
  bool shouldRepaint(covariant _SemiCircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gradientStart != gradientStart ||
        oldDelegate.gradientEnd != gradientEnd;
  }
}
