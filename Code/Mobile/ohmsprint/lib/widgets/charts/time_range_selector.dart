import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class TimeRangeSelector extends StatelessWidget {
  const TimeRangeSelector({
    required this.selectedSeconds,
    required this.onChanged,
    super.key,
  });

  final int selectedSeconds;
  final ValueChanged<int> onChanged;

  static const List<({String label, int seconds})> _ranges = [
    (label: '1m', seconds: 60),
    (label: '5m', seconds: 300),
    (label: '15m', seconds: 900),
    (label: '1h', seconds: 3600),
    (label: '24h', seconds: 86400),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: _ranges.map((range) {
          final isSelected = selectedSeconds == range.seconds;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(range.seconds),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.surfaceContainerHigh
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Text(
                      range.label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTypography.monoSmall.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
