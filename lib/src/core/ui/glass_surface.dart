import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final double blur;
  final Color tintColor;
  final Gradient? tintGradient;
  final Border? border;
  final List<BoxShadow> boxShadow;
  final bool addHighlights;
  final double noiseOpacity;
  final int noiseSeed;
  final bool useLiquidEffect;
  final double saturation; // kept for API compatibility (not used)

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 18,
    this.tintColor = const Color(0xB3FFFFFF),
    this.tintGradient,
    this.border,
    this.boxShadow = const [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
    this.addHighlights = true,
    this.noiseOpacity = 0.02,
    this.noiseSeed = 1,
    this.useLiquidEffect = false,
    this.saturation = 1.8,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = border ?? Border.all(color: Colors.white.withValues(alpha: 0.45), width: 0.8);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          // Use high-quality gaussian blur; color/saturation adjustments to the
          // backdrop are not supported directly, so we keep the material thin
          // and let background content provide vibrancy.
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tintGradient == null ? tintColor : null,
              gradient: tintGradient,
              borderRadius: borderRadius,
              border: effectiveBorder,
            ),
            child: Stack(
              children: [
                // Multi-layer highlights for iOS liquid effect
                if (addHighlights && useLiquidEffect) ...[
                  // Top highlight (most prominent)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: borderRadius.topLeft,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.40),
                              Colors.white.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.50, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Edge glow
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.28),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.08),
                            ],
                            stops: const [0, 0.35, 0.65, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Inner shadow/depth
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 25,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            bottom: borderRadius.bottomLeft,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            stops: const [0, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Subtle side highlights
                  Positioned(
                    left: 0,
                    top: 15,
                    bottom: 15,
                    width: 1.0,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (addHighlights) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.34),
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.12),
                            ],
                            stops: const [0, 0.55, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.20),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.07),
                            ],
                            stops: const [0, 0.65, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (noiseOpacity > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _NoisePainter(
                          seed: noiseSeed,
                          opacity: noiseOpacity,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Note: true saturation of the backdrop isn't possible with BackdropFilter.
  // If we need native UIVisualEffectView materials on iOS, we should consider
  // a platform view wrapper. For now we keep the blur thin and tint low.
}

class _NoisePainter extends CustomPainter {
  final int seed;
  final double opacity;

  const _NoisePainter({
    required this.seed,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rnd = Random(seed);
    final area = size.width * size.height;
    final pointCount = (area / 28).clamp(220, 1200).round();

    final light = <Offset>[];
    final dark = <Offset>[];

    for (var i = 0; i < pointCount; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      (rnd.nextBool() ? light : dark).add(p);
    }

    final a = (opacity.clamp(0, 1) * 255).round();
    final paint = Paint()
      ..strokeWidth = 1
      ..blendMode = BlendMode.softLight;

    if (light.isNotEmpty) {
      paint.color = Colors.white.withAlpha(a);
      canvas.drawPoints(PointMode.points, light, paint);
    }
    if (dark.isNotEmpty) {
      paint.color = Colors.black.withAlpha((a * 0.9).round());
      canvas.drawPoints(PointMode.points, dark, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}
