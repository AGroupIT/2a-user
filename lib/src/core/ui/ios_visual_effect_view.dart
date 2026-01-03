import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A thin wrapper around iOS UIVisualEffectView to achieve true material blur.
///
/// Falls back to a [DecoratedBox] with low-opacity tint on non-iOS platforms.
class IOSVisualEffectBlur extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double height;
  final double? width;
  final String
  style; // e.g. systemUltraThinMaterial, systemThinMaterial, systemMaterial, regular
  final bool addTopHairline;
  final bool addBottomHairline;

  const IOSVisualEffectBlur({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.height = 60,
    this.width,
    this.style = 'systemThinMaterial',
    this.addTopHairline = false,
    this.addBottomHairline = true,
  });

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return _IOSMaterialSurface(
        borderRadius: borderRadius,
        height: height,
        width: width,
        style: style,
        child: child,
        addTopHairline: addTopHairline,
        addBottomHairline: addBottomHairline,
      );
    }

    // Fallback for other platforms: light translucent container
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.0),
          borderRadius: borderRadius,
        ),
        child: SizedBox(height: height, width: width, child: child),
      ),
    );
  }
}

class _IOSMaterialSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double height;
  final double? width;
  final String style;
  final bool addTopHairline;
  final bool addBottomHairline;

  const _IOSMaterialSurface({
    required this.child,
    required this.borderRadius,
    required this.height,
    required this.width,
    required this.style,
    required this.addTopHairline,
    required this.addBottomHairline,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: native blur view
          ClipRRect(
            borderRadius: borderRadius,
            child: UiKitView(
              viewType: 'com.twoa.visual_effect_view',
              creationParams: <String, dynamic>{
                'cornerRadius': borderRadius.topLeft.x,
                'style': style,
              },
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),
          // Hairlines
          if (addTopHairline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 0.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.00),
                    ],
                  ),
                ),
              ),
            ),
          if (addBottomHairline)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 0.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.00),
                    ],
                  ),
                ),
              ),
            ),
          // Foreground content
          child,
        ],
      ),
    );
  }
}

// Placeholder to help iOS compositor allocate layer before UiKitView attaches.
class _iOSBlurViewPlaceholder extends StatelessWidget {
  const _iOSBlurViewPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.transparent);
  }
}
