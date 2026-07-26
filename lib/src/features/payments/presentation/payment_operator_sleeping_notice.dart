import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';

class PaymentOperatorSleepingNotice extends StatelessWidget {
  final bool onGradient;
  final bool compact;

  const PaymentOperatorSleepingNotice({
    super.key,
    this.onGradient = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = onGradient ? Colors.white : AppColors.textPrimary;
    final secondary = onGradient
        ? Colors.white.withValues(alpha: 0.88)
        : AppColors.textSecondary;
    final background = onGradient
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFFFFF3E8);
    final border = onGradient
        ? Colors.white.withValues(alpha: 0.26)
        : const Color(0xFFFFC999);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 13 : 15,
        vertical: compact ? 11 : 14,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 16 : 19),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
            decoration: BoxDecoration(
              color: onGradient
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0xFFFFE2C9),
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
            ),
            child: Icon(
              Icons.bedtime_rounded,
              color: onGradient ? Colors.white : const Color(0xFFFF6B00),
              size: compact ? 18 : 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    context,
                    ru: 'Операторы оплаты сейчас отдыхают',
                    zh: '支付客服当前休息中',
                  ),
                  style: TextStyle(
                    color: foreground,
                    fontFamily: 'Gilroy',
                    fontSize: compact ? 13.5 : 14.5,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    context,
                    ru: 'Оплата по QR временно недоступна. Мы отправим PUSH, когда операторы вернутся.',
                    zh: '二维码支付暂不可用。客服恢复在线后，我们会发送推送通知。',
                  ),
                  style: TextStyle(
                    color: secondary,
                    fontFamily: 'Gilroy',
                    fontSize: compact ? 11.7 : 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
