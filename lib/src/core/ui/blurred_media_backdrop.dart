import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class BlurredMediaBackdrop extends StatelessWidget {
  final String? imageUrl;
  final Widget child;
  final double blurSigma;
  final double overlayOpacity;

  const BlurredMediaBackdrop({
    super.key,
    required this.child,
    this.imageUrl,
    this.blurSigma = 18,
    this.overlayOpacity = 0.58,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (imageUrl != null && imageUrl!.isNotEmpty)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Transform.scale(
                scale: 1.08,
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: overlayOpacity),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
