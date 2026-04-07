import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'glass_card.dart';

class ConnectionLostOverlay extends StatefulWidget {
  const ConnectionLostOverlay({
    super.key,
    this.onRetry,
  });

  final VoidCallback? onRetry;

  @override
  State<ConnectionLostOverlay> createState() => _ConnectionLostOverlayState();
}

class _ConnectionLostOverlayState extends State<ConnectionLostOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _iconScale = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _iconOpacity = Tween<double>(
      begin: 0.5,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.68),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              label: 'Connection lost. Reconnecting.',
              liveRegion: true,
              child: GlassCard(
                elevated: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _iconOpacity,
                      child: ScaleTransition(
                        scale: _iconScale,
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 40,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connection Lost',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final dots =
                              '.' * ((_controller.value * 3).floor() + 1);
                          return Text(
                            'Reconnecting$dots',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                    ),
                    if (widget.onRetry != null) ...[
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
