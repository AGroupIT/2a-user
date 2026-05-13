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
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 14 : 16, color: status.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: compact ? 11 : 13,
              height: compact ? 13 / 11 : 15 / 13,
              fontWeight: FontWeight.w600,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
