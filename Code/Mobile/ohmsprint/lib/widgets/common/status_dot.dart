import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StatusDot extends StatefulWidget {
  const StatusDot({
    super.key,
    this.isConnected = false,
    this.size = 8,
  });

  final bool isConnected;
  final double size;

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

    return Semantics(
      label: widget.isConnected ? 'Connected' : 'Disconnected',
      child: ExcludeSemantics(
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
    );
  }
}
