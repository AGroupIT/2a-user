import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  final String text;
  final Color? color;
  final TextStyle? textStyle;
  final bool truncate;

  const StatusPill({
    super.key,
    required this.text,
    this.color,
    this.textStyle,
    this.truncate = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    final bg = Color.alphaBlend(
      c.withValues(alpha: 0.12),
      Colors.white.withValues(alpha: 0.72),
    );

    final resolvedTextStyle = const TextStyle(
      fontWeight: FontWeight.w700,
    ).merge(textStyle).copyWith(color: textStyle?.color ?? c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: truncate ? TextOverflow.ellipsis : TextOverflow.visible,
        softWrap: false,
        style: resolvedTextStyle,
      ),
    );
  }
}
