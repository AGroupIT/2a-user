import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_layout.dart';

class PixsoTopMenuSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double minWidth;

  const PixsoTopMenuSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.width,
    this.minWidth = 0,
  });

  static const height = 44.0;
  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    final scale = AppLayout.compactScale(context);
    final effectiveHeight = height * scale;
    final effectiveRadius = _radius * scale;
    final effectivePadding =
        padding.resolve(Directionality.of(context)) * scale;

    return Container(
      width: width == null ? null : width! * scale,
      height: effectiveHeight,
      constraints: BoxConstraints(
        minWidth: minWidth * scale,
        minHeight: effectiveHeight,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.05),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(effectiveRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  Colors.white.withValues(alpha: 0.76),
                ],
              ),
            ),
            child: Padding(
              padding: effectivePadding,
              child: width == null ? child : Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class PixsoTopMenuActionSurface extends StatelessWidget {
  final Widget child;
  final bool highlighted;

  const PixsoTopMenuActionSurface({
    super.key,
    required this.child,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scale = AppLayout.compactScale(context);
    final size = 30 * scale;
    final radius = 12 * scale;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlighted
            ? context.brandPrimary.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted
              ? context.brandPrimary.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.035),
        ),
      ),
      child: Center(child: child),
    );
  }
}
