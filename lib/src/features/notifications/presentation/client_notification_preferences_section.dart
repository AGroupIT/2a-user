import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../application/client_notification_preferences_controller.dart';
import '../domain/client_notification_preference.dart';

class ClientNotificationPreferencesSection extends ConsumerWidget {
  const ClientNotificationPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(
      clientNotificationPreferencesControllerProvider,
    );
    return preferences.when(
      loading: () => const _NotificationPreferencesLoadingCard(),
      error: (_, _) => _NotificationPreferencesErrorCard(
        onRetry: () => unawaited(
          ref
              .read(clientNotificationPreferencesControllerProvider.notifier)
              .refresh(),
        ),
      ),
      data: (state) => ClientNotificationPreferencesCard(
        state: state,
        onChanged: (key, enabled) async {
          try {
            await ref
                .read(clientNotificationPreferencesControllerProvider.notifier)
                .setEnabled(key, enabled);
          } catch (_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr(
                    context,
                    ru: 'Не удалось сохранить настройку',
                    zh: '无法保存设置',
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class ClientNotificationPreferencesCard extends StatelessWidget {
  final ClientNotificationPreferencesState state;
  final Future<void> Function(String key, bool enabled) onChanged;

  const ClientNotificationPreferencesCard({
    super.key,
    required this.state,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ClientNotificationPreferenceItem>>{};
    for (final item in state.items) {
      grouped.putIfAbsent(item.group, () => []).add(item);
    }

    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: context.brandPrimary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(context, ru: 'Настройки уведомлений', zh: '通知设置'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              ru: 'Выберите, какие push-уведомления вы хотите получать.',
              zh: '请选择您希望接收的推送通知。',
            ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final group in grouped.entries) ...[
            _NotificationPreferenceGroup(
              group: group.key,
              items: group.value,
              savingKeys: state.savingKeys,
              onChanged: onChanged,
            ),
            if (group.key != grouped.keys.last) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _NotificationPreferenceGroup extends StatelessWidget {
  final String group;
  final List<ClientNotificationPreferenceItem> items;
  final Set<String> savingKeys;
  final Future<void> Function(String key, bool enabled) onChanged;

  const _NotificationPreferenceGroup({
    required this.group,
    required this.items,
    required this.savingKeys,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _groupTitle(context, group),
          style: TextStyle(
            color: context.brandPrimary,
            fontFamily: 'Gilroy',
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        for (var index = 0; index < items.length; index++) ...[
          _NotificationPreferenceRow(
            item: items[index],
            isSaving: savingKeys.contains(items[index].key),
            onChanged: onChanged,
          ),
          if (index != items.length - 1)
            Divider(
              height: 1,
              indent: 2,
              endIndent: 2,
              color: Colors.black.withValues(alpha: 0.055),
            ),
        ],
      ],
    );
  }
}

class _NotificationPreferenceRow extends StatelessWidget {
  final ClientNotificationPreferenceItem item;
  final bool isSaving;
  final Future<void> Function(String key, bool enabled) onChanged;

  const _NotificationPreferenceRow({
    required this.item,
    required this.isSaving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mandatory = !item.isConfigurable;
    return Semantics(
      toggled: item.enabled,
      label: _eventTitle(context, item.key),
      child: SwitchListTile.adaptive(
        key: Key('client-push-preference-${item.key}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          _eventTitle(context, item.key),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Gilroy',
            fontSize: 13.5,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        value: mandatory ? true : item.enabled,
        activeTrackColor: context.brandPrimary.withValues(alpha: 0.55),
        activeThumbColor: context.brandPrimary,
        onChanged: mandatory || isSaving
            ? null
            : (enabled) => unawaited(onChanged(item.key, enabled)),
      ),
    );
  }
}

class _NotificationPreferencesLoadingCard extends StatelessWidget {
  const _NotificationPreferencesLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: _cardDecoration,
      alignment: Alignment.center,
      child: CircularProgressIndicator(color: context.brandPrimary),
    );
  }
}

class _NotificationPreferencesErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _NotificationPreferencesErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            tr(
              context,
              ru: 'Не удалось загрузить настройки уведомлений',
              zh: '无法加载通知设置',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(tr(context, ru: 'Повторить', zh: '重试')),
          ),
        ],
      ),
    );
  }
}

BoxDecoration get _cardDecoration => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.035),
      blurRadius: 18,
      offset: const Offset(0, 7),
    ),
  ],
);

String _groupTitle(BuildContext context, String group) {
  return switch (group) {
    'tracks' => tr(context, ru: 'Треки', zh: '运单'),
    'assemblies' => tr(context, ru: 'Сборки', zh: '集运包裹'),
    'photo_questions' => tr(context, ru: 'Фотоотчёты и вопросы', zh: '照片报告和问题'),
    'invoices_payments' => tr(context, ru: 'Счета и оплаты', zh: '账单与付款'),
    'self_buyout' => tr(context, ru: 'Самовыкуп', zh: '代购'),
    'garage' => tr(context, ru: 'Гараж', zh: '汽配车库'),
    'chats' => tr(context, ru: 'Чаты', zh: '聊天'),
    _ => tr(context, ru: 'Другие', zh: '其他'),
  };
}

String _eventTitle(BuildContext context, String key) {
  return switch (key) {
    'track_created' => tr(context, ru: 'Добавлен новый трек', zh: '已添加新运单'),
    'track_status_changed' => tr(
      context,
      ru: 'Изменён статус трека',
      zh: '运单状态已更改',
    ),
    'track_client_code_changed' => tr(
      context,
      ru: 'Трек перенесён на другой код клиента',
      zh: '运单已转移至其他客户代码',
    ),
    'track_added_to_assembly' => tr(
      context,
      ru: 'Трек добавлен в сборку',
      zh: '运单已加入集运包裹',
    ),
    'assembly_status_changed' => tr(
      context,
      ru: 'Изменён статус сборки',
      zh: '集运包裹状态已更改',
    ),
    'assembly_delivery_method_reminder' => tr(
      context,
      ru: 'Напоминание выбрать способ получения',
      zh: '提醒选择收货方式',
    ),
    'photo_request_completed' => tr(
      context,
      ru: 'Фотоотчёт готов',
      zh: '照片报告已完成',
    ),
    'question_answered' => tr(
      context,
      ru: 'Получен ответ на вопрос',
      zh: '问题已回复',
    ),
    'invoice_created' => tr(context, ru: 'Создан новый счёт', zh: '已创建新账单'),
    'invoice_status_changed' => tr(
      context,
      ru: 'Изменён статус счёта',
      zh: '账单状态已更改',
    ),
    'invoice_paid' => tr(
      context,
      ru: 'Оплата счёта подтверждена',
      zh: '账单付款已确认',
    ),
    'invoice_payment_rejected' => tr(
      context,
      ru: 'Чек оплаты счёта отклонён',
      zh: '账单付款凭证被拒绝',
    ),
    'invoice_payment_reminder' => tr(
      context,
      ru: 'Напоминание о неоплаченном счёте',
      zh: '未付款账单提醒',
    ),
    'invoice_arrival' => tr(
      context,
      ru: 'Накладная прибыла на терминал',
      zh: '货物已到达提货点',
    ),
    'payment_partially_covered' => tr(
      context,
      ru: 'Требуется доплата по счёту',
      zh: '账单需要补款',
    ),
    'payment_fully_covered' => tr(
      context,
      ru: 'Счёт полностью оплачен',
      zh: '账单已全额支付',
    ),
    'payment_operator_status_changed' => tr(
      context,
      ru: 'Статус работы операторов оплаты',
      zh: '付款客服工作状态',
    ),
    'self_buyout_verification_approved' => tr(
      context,
      ru: 'Доступ к самовыкупу подтверждён',
      zh: '代购权限已通过',
    ),
    'self_buyout_verification_rejected' => tr(
      context,
      ru: 'Проверка доступа к самовыкупу отклонена',
      zh: '代购权限审核未通过',
    ),
    'self_buyout_payment_approved' => tr(
      context,
      ru: 'Оплата самовыкупа подтверждена',
      zh: '代购付款已确认',
    ),
    'self_buyout_payment_rejected' => tr(
      context,
      ru: 'Чек оплаты самовыкупа отклонён',
      zh: '代购付款凭证被拒绝',
    ),
    'self_buyout_transfer_proof_uploaded' => tr(
      context,
      ru: 'Загружено подтверждение перевода',
      zh: '转账凭证已上传',
    ),
    'self_buyout_completed' => tr(context, ru: 'Юани отправлены', zh: '人民币已转出'),
    'self_buyout_cancelled' => tr(
      context,
      ru: 'Заявка самовыкупа отменена',
      zh: '代购申请已取消',
    ),
    'garage_offer_ready' => tr(
      context,
      ru: 'Предложение по запчастям готово',
      zh: '配件报价已准备好',
    ),
    'garage_clarification_required' => tr(
      context,
      ru: 'Требуются уточнения по заявке',
      zh: '申请需要补充信息',
    ),
    'garage_employee_reply' => tr(
      context,
      ru: 'Новый ответ сотрудника',
      zh: '员工有新回复',
    ),
    'garage_request_status_changed' => tr(
      context,
      ru: 'Изменён статус заявки',
      zh: '申请状态已更改',
    ),
    'garage_part_purchased' => tr(context, ru: 'Запчасть куплена', zh: '配件已购买'),
    'garage_purchase_started' => tr(
      context,
      ru: 'Покупка началась или ожидается',
      zh: '采购已开始或等待中',
    ),
    'garage_order_status' => tr(
      context,
      ru: 'Изменён статус заказа',
      zh: '订单状态已更改',
    ),
    'garage_order_completed' => tr(context, ru: 'Заказ завершён', zh: '订单已完成'),
    'garage_payment_rejected' => tr(
      context,
      ru: 'Чек оплаты заказа отклонён',
      zh: '订单付款凭证被拒绝',
    ),
    'garage_refund_request_approved' => tr(
      context,
      ru: 'Возврат одобрен',
      zh: '退款申请已批准',
    ),
    'garage_refund_request_rejected' => tr(
      context,
      ru: 'Возврат отклонён',
      zh: '退款申请被拒绝',
    ),
    'garage_refund_completed' => tr(
      context,
      ru: 'Возврат выполнен',
      zh: '退款已完成',
    ),
    'garage_payment_approved' => tr(
      context,
      ru: 'Оплата заказа подтверждена',
      zh: '订单付款已确认',
    ),
    'payment_partially_covered:garage_invoice' => tr(
      context,
      ru: 'Требуется доплата по заказу',
      zh: '订单需要补款',
    ),
    'payment_fully_covered:garage_invoice' => tr(
      context,
      ru: 'Заказ полностью оплачен',
      zh: '订单已全额支付',
    ),
    'support_message' => tr(context, ru: 'Сообщение от поддержки', zh: '客服消息'),
    'payment_chat_message' => tr(
      context,
      ru: 'Сообщение в чате по оплате',
      zh: '付款聊天消息',
    ),
    _ => key,
  };
}
