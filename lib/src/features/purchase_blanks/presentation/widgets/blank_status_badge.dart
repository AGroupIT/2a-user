import 'package:flutter/material.dart';

import '../../data/purchase_blank_model.dart';

/// Бейдж статуса бланка
class BlankStatusBadge extends StatelessWidget {
  final PurchaseBlankStatus status;
  final bool compact;

  const BlankStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final label = locale == 'zh' ? status.labelZh : status.label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 13 : 15, color: status.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: compact ? 11.5 : 13,
                height: 1,
                fontWeight: FontWeight.w900,
                color: status.color,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
