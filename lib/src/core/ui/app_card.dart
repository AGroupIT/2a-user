import 'package:flutter/material.dart';

import 'glass_surface.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      margin: margin,
      padding: padding,
      borderRadius: borderRadius,
      child: child,
    );
  }
}
