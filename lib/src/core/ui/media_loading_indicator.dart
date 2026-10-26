import 'package:flutter/material.dart';

/// Download progress is determinate only when the server reports its size.
class MediaLoadingIndicator extends StatelessWidget {
  const MediaLoadingIndicator({
    super.key,
    this.progress,
    this.color = Colors.white,
  });

  final ImageChunkEvent? progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = progress?.expectedTotalBytes;
    final value = total != null && total > 0
        ? (progress!.cumulativeBytesLoaded / total).clamp(0.0, 1.0)
        : null;
    final label = value == null ? null : '${(value * 100).floor()}%';
    return SizedBox.square(
      dimension: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            // Keep the 64px circle's stroke inside the viewer's clip bounds.
            padding: const EdgeInsets.all(4),
            child: SizedBox.expand(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                color: color,
                backgroundColor: color.withValues(alpha: 0.18),
                semanticsValue: value == null
                    ? null
                    : '${(value * 100).floor()}',
              ),
            ),
          ),
          if (label != null)
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
