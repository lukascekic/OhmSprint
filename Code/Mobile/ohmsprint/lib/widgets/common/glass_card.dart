import 'package:flutter/material.dart';

import '../../core/theme/glass_decoration.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration:
          elevated ? GlassDecoration.elevated() : GlassDecoration.card(),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
