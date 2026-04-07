import 'package:flutter/material.dart';

import '../../core/models/connection_state.dart';
import '../../core/theme/app_colors.dart';

class StatusDot extends StatefulWidget {
  const StatusDot({
    super.key,
    this.isConnected = false,
    this.size = 8,
    this.transport,
  });

  final bool isConnected;
  final double size;
  final ConnectionTransport? transport;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: widget.isConnected ? 1 : 0.45,
    );
    _opacity = Tween<double>(
      begin: 0.45,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isConnected) {
      _controller.value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isConnected == widget.isConnected) {
      return;
    }

    if (widget.isConnected) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isConnected ? AppColors.secondary : AppColors.error;
    final transportIcon = switch (widget.transport) {
      ConnectionTransport.http => Icons.sync_alt_rounded,
      ConnectionTransport.websocket => Icons.wifi_tethering_rounded,
      ConnectionTransport.mock => Icons.auto_graph_rounded,
      null => null,
    };
    final badgeSize =
        transportIcon == null ? 0.0 : (widget.size * 0.9).clamp(6.0, 10.0);
    final canvasSize =
        widget.size + (transportIcon == null ? 0 : badgeSize * 0.55);

    return Semantics(
      label: switch ((widget.isConnected, widget.transport)) {
        (true, ConnectionTransport.http) => 'Connected over HTTP',
        (true, ConnectionTransport.websocket) => 'Connected over WebSocket',
        (true, ConnectionTransport.mock) => 'Connected to mock stream',
        (true, null) => 'Connected',
        (false, _) => 'Disconnected',
      },
      child: ExcludeSemantics(
        child: SizedBox(
          width: canvasSize,
          height: canvasSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: transportIcon == null ? 0 : badgeSize * 0.35,
                child: FadeTransition(
                  opacity: _opacity,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (transportIcon != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      transportIcon,
                      size: badgeSize * 0.65,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
