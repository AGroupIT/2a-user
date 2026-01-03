import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  final String text;
  final Color? color;

  const StatusPill({
    super.key,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    final bg = Color.alphaBlend(
      c.withValues(alpha: 0.12),
      Colors.white.withValues(alpha: 0.72),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}
