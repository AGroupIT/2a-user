import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../data/client_payment_summary.dart';

class ClientPaymentSummaryPanel extends StatelessWidget {
  final ClientPaymentSummary summary;
  final bool terminalRefund;

  const ClientPaymentSummaryPanel({
    super.key,
    required this.summary,
    this.terminalRefund = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _stateColor(summary.state, context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _stateLabel(context, summary.state),
                style: TextStyle(
                  color: accent,
                  fontFamily: 'Gilroy',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (summary.state == ClientPaymentState.refunded && terminalRefund)
            _row(
              context,
              tr(context, ru: 'Сумма счёта', zh: '账单金额'),
              summary.requiredRub,
            )
          else ...[
            _row(
              context,
              tr(context, ru: 'К оплате', zh: '应付金额'),
              summary.requiredRub,
            ),
            _row(
              context,
              tr(context, ru: 'Получено', zh: '已收金额'),
              summary.creditedRub,
            ),
            if (summary.hasAcceptedShortfall)
              _row(
                context,
                tr(context, ru: 'Недостача принята', zh: '已接受少付金额'),
                summary.waivedShortfallRub,
                emphasized: true,
              ),
            _row(
              context,
              tr(context, ru: 'Осталось', zh: '剩余金额'),
              summary.remainingRub,
              emphasized: summary.hasRemaining,
            ),
            if (summary.overpaidRub.kopecks > 0)
              _row(
                context,
                tr(context, ru: 'Переплата', zh: '多付金额'),
                summary.overpaidRub,
                emphasized: true,
              ),
            if (summary.hasAcceptedShortfall) ...[
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  ru:
                      'Оплата принята. Доплачивать прощённую недостачу не требуется.',
                  zh: '付款已接受，无需补交已免除的差额。',
                ),
                style: TextStyle(
                  color: accent,
                  fontFamily: 'Gilroy',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    RubAmount value, {
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value.display,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 13.5,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _stateLabel(BuildContext context, ClientPaymentState state) =>
    switch (state) {
      ClientPaymentState.unpaid => tr(context, ru: 'Не оплачено', zh: '未付款'),
      ClientPaymentState.awaitingReview => tr(
        context,
        ru: 'Платёж на проверке',
        zh: '付款审核中',
      ),
      ClientPaymentState.partial => tr(
        context,
        ru: 'Частично оплачено',
        zh: '部分付款',
      ),
      ClientPaymentState.paid => tr(context, ru: 'Оплачено', zh: '已付款'),
      ClientPaymentState.overpaid => tr(context, ru: 'Переплата', zh: '已多付'),
      ClientPaymentState.refunded => tr(
        context,
        ru: 'Оплата возвращена',
        zh: '款项已退回',
      ),
      ClientPaymentState.unknown => tr(
        context,
        ru: 'Статус оплаты обновляется',
        zh: '付款状态更新中',
      ),
    };

Color _stateColor(ClientPaymentState state, BuildContext context) =>
    switch (state) {
      ClientPaymentState.partial ||
      ClientPaymentState.awaitingReview => const Color(0xFFD97706),
      ClientPaymentState.paid => const Color(0xFF15803D),
      ClientPaymentState.overpaid => const Color(0xFF0369A1),
      ClientPaymentState.refunded => const Color(0xFF6B7280),
      ClientPaymentState.unpaid ||
      ClientPaymentState.unknown => context.brandPrimary,
    };
