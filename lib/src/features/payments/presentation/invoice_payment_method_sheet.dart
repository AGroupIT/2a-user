import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../tracks/presentation/widgets/track_sheet_surface.dart';
import '../../../core/utils/locale_text.dart';
import '../data/invoice_payment_options.dart';

String invoicePaymentMethodLabel(
  BuildContext context,
  String method, {
  bool action = true,
}) => switch (method) {
  'bank_qr' => tr(
    context,
    ru: action ? 'Оплатить в рублях' : 'Рубли',
    zh: action ? '用卢布支付' : '卢布',
  ),
  'usdt_trc20' => tr(
    context,
    ru: action ? 'Оплатить USDT · TRC20' : 'USDT · TRC20',
    zh: action ? '用 USDT · TRC20 支付' : 'USDT · TRC20',
  ),
  'alipay' => tr(
    context,
    ru: action ? 'Оплатить в юанях · Alipay' : 'Юани · Alipay',
    zh: action ? '用人民币 · 支付宝支付' : '人民币 · 支付宝',
  ),
  'manager' => tr(
    context,
    ru: action
        ? 'Оплатить картой нероссийского банка'
        : 'Карта нероссийского банка',
    zh: action ? '使用非俄罗斯银行卡支付' : '非俄罗斯银行卡',
  ),
  _ => method,
};

class InvoicePaymentMethodSheet extends ConsumerStatefulWidget {
  const InvoicePaymentMethodSheet({super.key, required this.invoiceId});
  final String invoiceId;
  @override
  ConsumerState<InvoicePaymentMethodSheet> createState() =>
      _InvoicePaymentMethodSheetState();
}

class _InvoicePaymentMethodSheetState
    extends ConsumerState<InvoicePaymentMethodSheet> {
  InvoicePaymentOptions? _options;
  bool _loading = true;
  bool _selecting = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final value = await ref
          .read(invoicePaymentOptionsServiceProvider)
          .fetch(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _options = value;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _select(String method) async {
    if (_selecting || _options?.canChange != true) return;
    setState(() {
      _selecting = true;
      _error = false;
    });
    try {
      final value = await ref
          .read(invoicePaymentOptionsServiceProvider)
          .select(widget.invoiceId, method);
      if (!mounted) return;
      Navigator.of(context).pop(value);
    } catch (_) {
      if (!mounted) return;
      // Re-read the authoritative lock after e.g. a receipt submitted elsewhere.
      await _load();
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return TrackSheetSurface(
      icon: Icons.account_balance_wallet_rounded,
      title: tr(context, ru: 'Способ оплаты', zh: '付款方式'),
      subtitle: tr(
        context,
        ru: 'Выберите удобный способ оплаты',
        zh: '请选择付款方式',
      ),
      footer: TrackSheetPrimaryButton(
        label: tr(context, ru: 'Закрыть', zh: '关闭'),
        icon: Icons.close_rounded,
        onTap: _selecting ? null : () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (options != null && !options.canChange) ...[
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                ru: options.lockedReason == 'invoice_not_payable'
                    ? 'Смена способа оплаты недоступна для этого счёта.'
                    : 'Смена способа оплаты сейчас недоступна. Пока чек на проверке, дождитесь решения сотрудника.',
                zh: options.lockedReason == 'invoice_not_payable'
                    ? '此账单无法更改付款方式。'
                    : '暂时无法更改付款方式。凭证审核期间，请等待工作人员处理。',
              ),
            ),
            if (options.activeMethod != null) ...[
              const SizedBox(height: 12),
              Text(invoicePaymentMethodLabel(context, options.activeMethod!)),
            ],
          ] else if (options != null) ...[
            Text(
              tr(
                context,
                ru: 'Способ можно изменить до отправки чека. После отправки дождитесь проверки.',
                zh: '提交凭证前可更改付款方式。提交后请等待审核。',
              ),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            for (final method in options.methods.where(
              (method) => const {
                'bank_qr',
                'usdt_trc20',
                'alipay',
                'manager',
              }.contains(method.code),
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TrackSheetOptionTile(
                  icon: method.code == 'manager'
                      ? Icons.credit_card_rounded
                      : Icons.qr_code_2_rounded,
                  title: invoicePaymentMethodLabel(context, method.code),
                  titleMaxLines: 4,
                  subtitle: !method.available
                      ? tr(
                          context,
                          ru:
                              method.unavailableReason ==
                                  'payment_requisites_missing'
                              ? 'Реквизиты не настроены'
                              : method.unavailableReason ==
                                    'currency_rate_unavailable'
                              ? 'Нет актуального курса'
                              : 'Временно недоступно',
                          zh:
                              method.unavailableReason ==
                                  'payment_requisites_missing'
                              ? '未设置收款信息'
                              : method.unavailableReason ==
                                    'currency_rate_unavailable'
                              ? '暂无有效汇率'
                              : '暂不可用',
                        )
                      : options.activeMethod == method.code
                      ? tr(context, ru: 'Выбранный способ', zh: '已选方式')
                      : invoicePaymentMethodLabel(
                          context,
                          method.code,
                          action: false,
                        ),
                  selected: options.activeMethod == method.code,
                  onTap: method.available && !_selecting
                      ? () => _select(method.code)
                      : null,
                ),
              ),
          ],
          if (_selecting) const Center(child: CircularProgressIndicator()),
          if (_error) ...[
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                ru: 'Не удалось подготовить оплату. Обновите данные и повторите.',
                zh: '无法准备付款，请刷新后重试。',
              ),
            ),
            TextButton(
              onPressed: _selecting ? null : _load,
              child: Text(tr(context, ru: 'Обновить', zh: '刷新')),
            ),
          ],
        ],
      ),
    );
  }
}
