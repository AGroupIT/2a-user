import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../data/sp_organizer_calculation_models.dart';
import '../data/sp_organizer_provider.dart';
import 'sp_finance_ui.dart';

Future<bool?> showSpOrganizerCalculationProfileSheet({
  required BuildContext context,
  required int purchaseId,
  required SpOrganizerCalculationProfile selfProfile,
  required SpOrganizerCalculationProfile clientProfile,
}) {
  return showSpFinanceModalSheet<bool>(
    context: context,
    builder: (context) => _SpOrganizerCalculationProfileSheet(
      purchaseId: purchaseId,
      selfProfile: selfProfile,
      clientProfile: clientProfile,
    ),
  );
}

class _SpOrganizerCalculationProfileSheet extends ConsumerStatefulWidget {
  final int purchaseId;
  final SpOrganizerCalculationProfile selfProfile;
  final SpOrganizerCalculationProfile clientProfile;

  const _SpOrganizerCalculationProfileSheet({
    required this.purchaseId,
    required this.selfProfile,
    required this.clientProfile,
  });

  @override
  ConsumerState<_SpOrganizerCalculationProfileSheet> createState() =>
      _SpOrganizerCalculationProfileSheetState();
}

class _SpOrganizerCalculationProfileSheetState
    extends ConsumerState<_SpOrganizerCalculationProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, _CalculationProfileDraft> _drafts;
  String _scope = 'self';
  bool _previewing = false;
  bool _saving = false;
  String? _error;
  String? _previewedSignature;
  SpOrganizerCalculationPreview? _preview;

  _CalculationProfileDraft get _draft => _drafts[_scope]!;
  TextEditingController get _rateController => _draft.rateController;
  TextEditingController get _deliveryRateController =>
      _draft.deliveryRateController;
  TextEditingController get _usdRateController => _draft.usdRateController;
  TextEditingController get _pricePerKgController =>
      _draft.pricePerKgController;
  TextEditingController get _packingController => _draft.packingController;
  TextEditingController get _parcelWeightController =>
      _draft.parcelWeightController;
  TextEditingController get _insurancePercentController =>
      _draft.insurancePercentController;
  TextEditingController get _insuranceFixedController =>
      _draft.insuranceFixedController;
  TextEditingController get _domesticDeliveryController =>
      _draft.domesticDeliveryController;
  TextEditingController get _additionalExpensesController =>
      _draft.additionalExpensesController;
  TextEditingController get _commissionPercentController =>
      _draft.commissionPercentController;
  TextEditingController get _commissionFixedController =>
      _draft.commissionFixedController;
  String get _currency => _draft.currency;
  set _currency(String value) => _draft.currency = value;
  String get _pricePerKgCurrency => _draft.pricePerKgCurrency;
  set _pricePerKgCurrency(String value) => _draft.pricePerKgCurrency = value;
  String get _packingCurrency => _draft.packingCurrency;
  set _packingCurrency(String value) => _draft.packingCurrency = value;
  String get _insuranceMode => _draft.insuranceMode;
  set _insuranceMode(String value) => _draft.insuranceMode = value;
  String get _insuranceFixedCurrency => _draft.insuranceFixedCurrency;
  set _insuranceFixedCurrency(String value) =>
      _draft.insuranceFixedCurrency = value;
  String get _domesticDeliveryCurrency => _draft.domesticDeliveryCurrency;
  set _domesticDeliveryCurrency(String value) =>
      _draft.domesticDeliveryCurrency = value;
  String get _additionalExpensesCurrency => _draft.additionalExpensesCurrency;
  set _additionalExpensesCurrency(String value) =>
      _draft.additionalExpensesCurrency = value;
  String get _commissionMode => _draft.commissionMode;
  set _commissionMode(String value) => _draft.commissionMode = value;
  String get _commissionBase => _draft.commissionBase;
  set _commissionBase(String value) => _draft.commissionBase = value;

  @override
  void initState() {
    super.initState();
    _drafts = {
      'self': _CalculationProfileDraft.fromProfile(
        scope: 'self',
        profile: widget.selfProfile,
      ),
      'client': _CalculationProfileDraft.fromProfile(
        scope: 'client',
        profile: widget.clientProfile,
      ),
    };
    for (final draft in _drafts.values) {
      for (final controller in draft.controllers) {
        controller.addListener(_invalidatePreview);
      }
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final currentInput = _readInput();
    final canSave =
        !_previewing &&
        !_saving &&
        currentInput != null &&
        _preview != null &&
        _previewedSignature == currentInput.signature;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E5ED),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.brandPrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: context.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, ru: 'Профиль расчёта', zh: '结算配置'),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'Gilroy',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(
                              context,
                              ru: 'Сначала проверьте влияние новых параметров',
                              zh: '请先检查新参数的影响',
                            ),
                            style: SpFinanceUi.labelStyle,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, ru: 'Закрыть', zh: '关闭'),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + bottomInset),
                children: [
                  SpInfoNotice(
                    title: tr(context, ru: 'Безопасный черновик', zh: '安全草稿'),
                    message: tr(
                      context,
                      ru: 'Сохраняется только новый профиль. Текущие начисления, оплаты, курс закупки и снимки расчёта не изменяются.',
                      zh: '只保存新配置。当前应收、付款、采购汇率和结算快照不会改变。',
                    ),
                    icon: Icons.shield_outlined,
                  ),
                  const SizedBox(height: 14),
                  _CalculationScopeSelector(
                    scope: _scope,
                    enabled: !_saving && !_previewing,
                    onChanged: _switchScope,
                  ),
                  if (_scope == 'client') ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _saving ? null : _copyFromSelf,
                        icon: const Icon(Icons.content_copy_rounded, size: 18),
                        label: Text(
                          tr(
                            context,
                            ru: 'Заполнить из «Для себя»',
                            zh: '从“自用”复制',
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('profile-currency-$_scope-$_currency'),
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: SpFinanceUi.inputDecoration(
                      context,
                      labelText: tr(context, ru: 'Валюта профиля', zh: '配置币种'),
                      prefixIcon: Icons.currency_exchange_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CNY', child: Text('CNY · ¥')),
                      DropdownMenuItem(value: 'RUB', child: Text('RUB · ₽')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null || value == _currency) return;
                            setState(() {
                              _currency = value;
                              _resetPreview();
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rateController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: SpFinanceUi.inputDecoration(
                      context,
                      labelText: tr(
                        context,
                        ru: 'Курс CNY → RUB',
                        zh: 'CNY → RUB 汇率',
                      ),
                      hintText: '12,50',
                      suffixText: '₽',
                      prefixIcon: Icons.swap_horiz_rounded,
                    ),
                    validator: (value) {
                      final rate = _parseRate(value);
                      if (rate == null || rate <= 0 || rate > 1000000) {
                        return tr(
                          context,
                          ru: 'Введите курс больше 0',
                          zh: '请输入大于0的汇率',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      context,
                      ru: 'Индивидуальный курс позиции остаётся приоритетным. Профиль применяется в preview только к позициям без своего курса.',
                      zh: '明细自己的汇率仍优先。配置仅在预览中用于没有独立汇率的明细。',
                    ),
                    style: SpFinanceUi.labelStyle,
                  ),
                  const SizedBox(height: 16),
                  _ProfileSectionTitle(
                    icon: Icons.local_shipping_outlined,
                    title: tr(context, ru: 'Логистика и тарифы', zh: '物流与费率'),
                  ),
                  const SizedBox(height: 10),
                  _numberField(
                    controller: _deliveryRateController,
                    label: tr(
                      context,
                      ru: 'Курс доставки CNY → RUB',
                      zh: '运费 CNY → RUB 汇率',
                    ),
                    suffix: '₽',
                    maximum: 1000000,
                  ),
                  const SizedBox(height: 10),
                  _numberField(
                    controller: _usdRateController,
                    label: tr(
                      context,
                      ru: 'Курс USD → RUB',
                      zh: 'USD → RUB 汇率',
                    ),
                    suffix: '₽',
                    maximum: 1000000,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'price-per-kg-currency-$_scope-$_pricePerKgCurrency',
                    ),
                    initialValue: _pricePerKgCurrency,
                    isExpanded: true,
                    decoration: SpFinanceUi.inputDecoration(
                      context,
                      labelText: tr(
                        context,
                        ru: 'Валюта тарифа за кг',
                        zh: '每公斤费率币种',
                      ),
                      prefixIcon: Icons.scale_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CNY', child: Text('CNY · ¥')),
                      DropdownMenuItem(value: 'RUB', child: Text('RUB · ₽')),
                      DropdownMenuItem(value: 'USD', child: Text('USD · \$')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null || value == _pricePerKgCurrency) {
                              return;
                            }
                            setState(() {
                              _pricePerKgCurrency = value;
                              _resetPreview();
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  _numberField(
                    controller: _pricePerKgController,
                    label: tr(context, ru: 'Тариф за 1 кг', zh: '每公斤费率'),
                    suffix: _pricePerKgCurrency,
                    maximum: 1000000,
                    allowZero: true,
                  ),
                  const SizedBox(height: 10),
                  _amountCurrencyField(
                    controller: _packingController,
                    label: tr(context, ru: 'Упаковка', zh: '包装费'),
                    currency: _packingCurrency,
                    fieldKey: 'packing',
                    onCurrencyChanged: (value) {
                      setState(() {
                        _packingCurrency = value;
                        _resetPreview();
                      });
                    },
                    maximum: 100000000,
                    allowZero: true,
                  ),
                  if (_scope == 'self') ...[
                    const SizedBox(height: 10),
                    _numberField(
                      controller: _parcelWeightController,
                      label: tr(
                        context,
                        ru: 'Вес посылки для расчёта упаковки',
                        zh: '用于计算包装费的包裹重量',
                      ),
                      suffix: 'кг',
                      maximum: 1000000,
                      allowZero: true,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _amountCurrencyField(
                    controller: _domesticDeliveryController,
                    label: tr(
                      context,
                      ru: 'Доставка по стране или городу',
                      zh: '国内或城市配送',
                    ),
                    currency: _domesticDeliveryCurrency,
                    fieldKey: 'domestic-delivery',
                    onCurrencyChanged: (value) {
                      setState(() {
                        _domesticDeliveryCurrency = value;
                        _resetPreview();
                      });
                    },
                    maximum: 100000000,
                    allowZero: true,
                  ),
                  const SizedBox(height: 10),
                  _amountCurrencyField(
                    controller: _additionalExpensesController,
                    label: tr(
                      context,
                      ru: 'Дополнительные расходы',
                      zh: '其他费用',
                    ),
                    currency: _additionalExpensesCurrency,
                    fieldKey: 'additional-expenses',
                    onCurrencyChanged: (value) {
                      setState(() {
                        _additionalExpensesCurrency = value;
                        _resetPreview();
                      });
                    },
                    maximum: 100000000,
                    allowZero: true,
                  ),
                  const SizedBox(height: 16),
                  _ProfileSectionTitle(
                    icon: Icons.verified_user_outlined,
                    title: tr(
                      context,
                      ru: _scope == 'client'
                          ? 'Страховка и комиссия'
                          : 'Страховка',
                      zh: _scope == 'client' ? '保险与佣金' : '保险',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('insurance-mode-$_scope-$_insuranceMode'),
                    initialValue: _insuranceMode,
                    isExpanded: true,
                    decoration: SpFinanceUi.inputDecoration(
                      context,
                      labelText: tr(context, ru: 'Страховка', zh: '保险'),
                      prefixIcon: Icons.shield_outlined,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(
                          tr(context, ru: 'Без страховки', zh: '无保险'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'percent',
                        child: Text(tr(context, ru: 'Процент', zh: '百分比')),
                      ),
                      DropdownMenuItem(
                        value: 'fixed',
                        child: Text(
                          tr(context, ru: 'Фиксированная', zh: '固定金额'),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null || value == _insuranceMode) {
                              return;
                            }
                            setState(() {
                              _insuranceMode = value;
                              _resetPreview();
                            });
                          },
                  ),
                  if (_insuranceMode == 'percent') ...[
                    const SizedBox(height: 10),
                    _numberField(
                      controller: _insurancePercentController,
                      label: tr(context, ru: 'Страховка, %', zh: '保险比例'),
                      suffix: '%',
                      maximum: 100,
                      requiredPositive: true,
                    ),
                  ],
                  if (_insuranceMode == 'fixed') ...[
                    const SizedBox(height: 10),
                    _amountCurrencyField(
                      controller: _insuranceFixedController,
                      label: tr(context, ru: 'Страховка, сумма', zh: '保险金额'),
                      currency: _insuranceFixedCurrency,
                      fieldKey: 'insurance-fixed',
                      onCurrencyChanged: (value) {
                        setState(() {
                          _insuranceFixedCurrency = value;
                          _resetPreview();
                        });
                      },
                      maximum: 100000000,
                      requiredPositive: true,
                    ),
                  ],
                  if (_scope == 'client') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey('commission-mode-$_scope-$_commissionMode'),
                      initialValue: _commissionMode,
                      isExpanded: true,
                      decoration: SpFinanceUi.inputDecoration(
                        context,
                        labelText: tr(
                          context,
                          ru: 'Комиссия организатора',
                          zh: '团长佣金',
                        ),
                        prefixIcon: Icons.percent_rounded,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'none',
                          child: Text(
                            tr(context, ru: 'Без комиссии', zh: '无佣金'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'hidden_margin',
                          child: Text(
                            tr(
                              context,
                              ru: 'Скрытая маржа в цене',
                              zh: '价格内含利润',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'percent',
                          child: Text(tr(context, ru: 'Процент', zh: '百分比')),
                        ),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text(
                            tr(context, ru: 'Фиксированная', zh: '固定金额'),
                          ),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null || value == _commissionMode) {
                                return;
                              }
                              setState(() {
                                _commissionMode = value;
                                _resetPreview();
                              });
                            },
                    ),
                    if (_commissionMode == 'percent') ...[
                      const SizedBox(height: 10),
                      _numberField(
                        controller: _commissionPercentController,
                        label: tr(context, ru: 'Комиссия, %', zh: '佣金比例'),
                        suffix: '%',
                        maximum: 100,
                        requiredPositive: true,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'commission-base-$_scope-$_commissionBase',
                        ),
                        initialValue: _commissionBase,
                        isExpanded: true,
                        decoration: SpFinanceUi.inputDecoration(
                          context,
                          labelText: tr(
                            context,
                            ru: 'База комиссии',
                            zh: '佣金计算基础',
                          ),
                          prefixIcon: Icons.account_tree_outlined,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'goods',
                            child: Text(
                              tr(context, ru: 'Стоимость товаров', zh: '商品金额'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'total',
                            child: Text(
                              tr(context, ru: 'Итоговая сумма', zh: '总金额'),
                            ),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null || value == _commissionBase) {
                                  return;
                                }
                                setState(() {
                                  _commissionBase = value;
                                  _resetPreview();
                                });
                              },
                      ),
                    ],
                    if (_commissionMode == 'fixed') ...[
                      const SizedBox(height: 10),
                      _numberField(
                        controller: _commissionFixedController,
                        label: tr(context, ru: 'Комиссия, сумма', zh: '佣金金额'),
                        suffix: _currency,
                        maximum: 100000000,
                        requiredPositive: true,
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  SpInfoNotice(
                    title: tr(
                      context,
                      ru: 'Поля сохраняются отдельно',
                      zh: '字段单独保存',
                    ),
                    message: tr(
                      context,
                      ru: 'Тарифы, валюты расходов, упаковка, страховка, допрасходы и комиссия сохраняются отдельно для каждой вкладки. Пока движок не распределяет их, текущие суммы остаются неизменными.',
                      zh: '费率、费用币种、包装、保险、其他费用和佣金按标签分别保存。在分摊引擎启用前，现有金额保持不变。',
                    ),
                    icon: Icons.lock_clock_outlined,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ProfileError(message: _error!),
                  ],
                  if (_preview != null) ...[
                    const SizedBox(height: 14),
                    _DraftPreviewCard(preview: _preview!),
                    if (_preview!.warnings.contains(
                      'profile_fields_pending_engine',
                    )) ...[
                      const SizedBox(height: 10),
                      SpInfoNotice(
                        title: tr(
                          context,
                          ru: 'Применение пока заблокировано',
                          zh: '暂时无法应用',
                        ),
                        message: tr(
                          context,
                          ru: 'Черновик можно сохранить, но новые расходы пока не меняют начисления клиентов. Это защищает действующую финансовую логику.',
                          zh: '可以保存草稿，但新费用暂不会改变客户应付，以保护现有财务逻辑。',
                        ),
                        icon: Icons.warning_amber_rounded,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              18,
              10,
              18,
              18 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _previewing || _saving ? null : _previewDraft,
                      icon: _previewing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.visibility_outlined),
                      label: Text(tr(context, ru: 'Проверить', zh: '检查')),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: canSave ? _save : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _scope == 'self'
                            ? tr(
                                context,
                                ru: 'Сохранить для себя',
                                zh: '保存自用配置',
                              )
                            : tr(
                                context,
                                ru: 'Сохранить для клиента',
                                zh: '保存客户配置',
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _invalidatePreview() {
    if (!mounted) return;
    setState(_resetPreview);
  }

  void _switchScope(String scope) {
    if (scope == _scope || _saving || _previewing) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _scope = scope;
      _resetPreview();
    });
  }

  void _copyFromSelf() {
    if (_scope != 'client') return;
    _drafts['client']!.copyCommonFrom(_drafts['self']!);
    setState(_resetPreview);
  }

  void _resetPreview() {
    _previewedSignature = null;
    _preview = null;
    _error = null;
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String? suffix,
    required double maximum,
    bool allowZero = false,
    bool requiredPositive = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: SpFinanceUi.inputDecoration(
        context,
        labelText: label,
        suffixText: suffix,
        prefixIcon: Icons.calculate_outlined,
      ),
      validator: (value) {
        final normalized = value?.trim() ?? '';
        if (normalized.isEmpty) {
          if (!requiredPositive) return null;
          return tr(context, ru: 'Введите значение больше 0', zh: '请输入大于0的值');
        }
        final number = _parseRate(normalized);
        final minimumValid = allowZero
            ? (number ?? -1) >= 0
            : (number ?? 0) > 0;
        if (!minimumValid || number! > maximum) {
          return tr(
            context,
            ru: allowZero
                ? 'Введите значение от 0'
                : 'Введите значение больше 0',
            zh: allowZero ? '请输入不小于0的值' : '请输入大于0的值',
          );
        }
        return null;
      },
    );
  }

  Widget _amountCurrencyField({
    required TextEditingController controller,
    required String label,
    required String currency,
    required String fieldKey,
    required ValueChanged<String> onCurrencyChanged,
    required double maximum,
    bool allowZero = false,
    bool requiredPositive = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _numberField(
            controller: controller,
            label: label,
            suffix: null,
            maximum: maximum,
            allowZero: allowZero,
            requiredPositive: requiredPositive,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 116,
          child: DropdownButtonFormField<String>(
            key: ValueKey('$fieldKey-$_scope-$currency'),
            initialValue: currency,
            isExpanded: true,
            decoration: SpFinanceUi.inputDecoration(
              context,
              labelText: tr(context, ru: 'Валюта', zh: '币种'),
            ),
            items: const [
              DropdownMenuItem(value: 'RUB', child: Text('RUB')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'CNY', child: Text('CNY')),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null && value != currency) {
                      onCurrencyChanged(value);
                    }
                  },
          ),
        ),
      ],
    );
  }

  SpOrganizerCalculationProfileInput? _readInput() {
    final rate = _parseRate(_rateController.text);
    if (rate == null || rate <= 0 || rate > 1000000) return null;
    final insurancePercent = _parseOptionalNumber(
      _insurancePercentController.text,
    );
    final insuranceFixed = _parseOptionalNumber(_insuranceFixedController.text);
    final commissionPercent = _parseOptionalNumber(
      _commissionPercentController.text,
    );
    final commissionFixed = _parseOptionalNumber(
      _commissionFixedController.text,
    );
    if (_insuranceMode == 'percent' &&
        (insurancePercent == null || insurancePercent <= 0)) {
      return null;
    }
    if (_insuranceMode == 'fixed' &&
        (insuranceFixed == null || insuranceFixed <= 0)) {
      return null;
    }
    if (_commissionMode == 'percent' &&
        (commissionPercent == null || commissionPercent <= 0)) {
      return null;
    }
    if (_commissionMode == 'fixed' &&
        (commissionFixed == null || commissionFixed <= 0)) {
      return null;
    }
    return SpOrganizerCalculationProfileInput(
      scope: _scope,
      currency: _currency,
      cnyRubRate: rate,
      deliveryCnyRubRate: _parseOptionalNumber(_deliveryRateController.text),
      usdRubRate: _parseOptionalNumber(_usdRateController.text),
      pricePerKg: _parseOptionalNumber(_pricePerKgController.text),
      pricePerKgCurrency: _pricePerKgCurrency,
      packingAmount: _parseOptionalNumber(_packingController.text),
      packingCurrency: _packingCurrency,
      parcelWeightKg: _scope == 'self'
          ? _parseOptionalNumber(_parcelWeightController.text)
          : null,
      insuranceMode: _insuranceMode,
      insurancePercent: insurancePercent,
      insuranceFixedAmount: insuranceFixed,
      insuranceFixedCurrency: _insuranceFixedCurrency,
      domesticDeliveryAmount: _parseOptionalNumber(
        _domesticDeliveryController.text,
      ),
      domesticDeliveryCurrency: _domesticDeliveryCurrency,
      additionalExpensesAmount: _parseOptionalNumber(
        _additionalExpensesController.text,
      ),
      additionalExpensesCurrency: _additionalExpensesCurrency,
      commissionMode: _commissionMode,
      commissionPercent: commissionPercent,
      commissionFixedAmount: commissionFixed,
      commissionBase: _commissionBase,
    );
  }

  Future<void> _previewDraft() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final input = _readInput();
    if (input == null) return;
    setState(() {
      _previewing = true;
      _error = null;
    });
    try {
      final preview = await ref
          .read(spOrganizerRepositoryProvider)
          .getCalculationPreview(widget.purchaseId, profileOverride: input);
      if (!mounted) return;
      if (_readInput()?.signature != input.signature) {
        setState(() => _previewing = false);
        return;
      }
      setState(() {
        _previewing = false;
        _preview = preview;
        _previewedSignature = input.signature;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _previewing = false;
        _preview = null;
        _previewedSignature = null;
        _error =
            '${tr(context, ru: 'Не удалось проверить профиль', zh: '无法检查配置')}: $error';
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final input = _readInput();
    if (input == null ||
        _preview == null ||
        _previewedSignature != input.signature) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(spOrganizerRepositoryProvider)
          .saveCalculationProfile(widget.purchaseId, input);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            '${tr(context, ru: 'Не удалось сохранить профиль', zh: '无法保存配置')}: $error';
      });
    }
  }
}

class _CalculationProfileDraft {
  final String scope;
  final TextEditingController rateController;
  final TextEditingController deliveryRateController;
  final TextEditingController usdRateController;
  final TextEditingController pricePerKgController;
  final TextEditingController packingController;
  final TextEditingController parcelWeightController;
  final TextEditingController insurancePercentController;
  final TextEditingController insuranceFixedController;
  final TextEditingController domesticDeliveryController;
  final TextEditingController additionalExpensesController;
  final TextEditingController commissionPercentController;
  final TextEditingController commissionFixedController;
  String currency;
  String pricePerKgCurrency;
  String packingCurrency;
  String insuranceMode;
  String insuranceFixedCurrency;
  String domesticDeliveryCurrency;
  String additionalExpensesCurrency;
  String commissionMode;
  String commissionBase;

  _CalculationProfileDraft({
    required this.scope,
    required this.rateController,
    required this.deliveryRateController,
    required this.usdRateController,
    required this.pricePerKgController,
    required this.packingController,
    required this.parcelWeightController,
    required this.insurancePercentController,
    required this.insuranceFixedController,
    required this.domesticDeliveryController,
    required this.additionalExpensesController,
    required this.commissionPercentController,
    required this.commissionFixedController,
    required this.currency,
    required this.pricePerKgCurrency,
    required this.packingCurrency,
    required this.insuranceMode,
    required this.insuranceFixedCurrency,
    required this.domesticDeliveryCurrency,
    required this.additionalExpensesCurrency,
    required this.commissionMode,
    required this.commissionBase,
  });

  factory _CalculationProfileDraft.fromProfile({
    required String scope,
    required SpOrganizerCalculationProfile profile,
  }) {
    final currency = const {'CNY', 'RUB'}.contains(profile.currency)
        ? profile.currency
        : 'CNY';
    String expenseCurrency(String? value) =>
        const {'CNY', 'RUB', 'USD'}.contains(value) ? value! : currency;
    return _CalculationProfileDraft(
      scope: scope,
      rateController: TextEditingController(
        text: _formatRate(profile.cnyRubRate),
      ),
      deliveryRateController: TextEditingController(
        text: _formatRate(profile.deliveryCnyRubRate),
      ),
      usdRateController: TextEditingController(
        text: _formatRate(profile.usdRubRate),
      ),
      pricePerKgController: TextEditingController(
        text: _formatRate(profile.pricePerKg),
      ),
      packingController: TextEditingController(
        text: _formatRate(profile.packingAmount),
      ),
      parcelWeightController: TextEditingController(
        text: _formatRate(profile.parcelWeightKg),
      ),
      insurancePercentController: TextEditingController(
        text: _formatRate(profile.insurancePercent),
      ),
      insuranceFixedController: TextEditingController(
        text: _formatRate(profile.insuranceFixedAmount),
      ),
      domesticDeliveryController: TextEditingController(
        text: _formatRate(profile.domesticDeliveryAmount),
      ),
      additionalExpensesController: TextEditingController(
        text: _formatRate(profile.additionalExpensesAmount),
      ),
      commissionPercentController: TextEditingController(
        text: _formatRate(profile.commissionPercent),
      ),
      commissionFixedController: TextEditingController(
        text: _formatRate(profile.commissionFixedAmount),
      ),
      currency: currency,
      pricePerKgCurrency: expenseCurrency(profile.pricePerKgCurrency),
      packingCurrency: expenseCurrency(profile.packingCurrency),
      insuranceMode:
          const {'none', 'percent', 'fixed'}.contains(profile.insuranceMode)
          ? profile.insuranceMode!
          : 'none',
      insuranceFixedCurrency: expenseCurrency(profile.insuranceFixedCurrency),
      domesticDeliveryCurrency: expenseCurrency(
        profile.domesticDeliveryCurrency,
      ),
      additionalExpensesCurrency: expenseCurrency(
        profile.additionalExpensesCurrency,
      ),
      commissionMode:
          const {
            'none',
            'hidden_margin',
            'percent',
            'fixed',
          }.contains(profile.commissionMode)
          ? profile.commissionMode!
          : (scope == 'client' ? 'hidden_margin' : 'none'),
      commissionBase: const {'goods', 'total'}.contains(profile.commissionBase)
          ? profile.commissionBase!
          : 'goods',
    );
  }

  List<TextEditingController> get controllers => [
    rateController,
    deliveryRateController,
    usdRateController,
    pricePerKgController,
    packingController,
    parcelWeightController,
    insurancePercentController,
    insuranceFixedController,
    domesticDeliveryController,
    additionalExpensesController,
    commissionPercentController,
    commissionFixedController,
  ];

  void copyCommonFrom(_CalculationProfileDraft source) {
    currency = source.currency;
    pricePerKgCurrency = source.pricePerKgCurrency;
    packingCurrency = source.packingCurrency;
    insuranceMode = source.insuranceMode;
    insuranceFixedCurrency = source.insuranceFixedCurrency;
    domesticDeliveryCurrency = source.domesticDeliveryCurrency;
    additionalExpensesCurrency = source.additionalExpensesCurrency;
    rateController.text = source.rateController.text;
    deliveryRateController.text = source.deliveryRateController.text;
    usdRateController.text = source.usdRateController.text;
    pricePerKgController.text = source.pricePerKgController.text;
    packingController.text = source.packingController.text;
    insurancePercentController.text = source.insurancePercentController.text;
    insuranceFixedController.text = source.insuranceFixedController.text;
    domesticDeliveryController.text = source.domesticDeliveryController.text;
    additionalExpensesController.text =
        source.additionalExpensesController.text;
  }

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

class _CalculationScopeSelector extends StatelessWidget {
  final String scope;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _CalculationScopeSelector({
    required this.scope,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _item(
            context,
            value: 'self',
            label: tr(context, ru: 'Для себя', zh: '自用'),
            icon: Icons.person_outline_rounded,
          ),
          _item(
            context,
            value: 'client',
            label: tr(context, ru: 'Для клиента', zh: '客户'),
            icon: Icons.groups_outlined,
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = scope == value;
    return Expanded(
      child: InkWell(
        onTap: enabled && !selected ? () => onChanged(value) : null,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? context.brandPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: SpFinanceUi.bodyStyle.copyWith(
                    color: selected
                        ? context.brandPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftPreviewCard extends StatelessWidget {
  final SpOrganizerCalculationPreview preview;

  const _DraftPreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.brandPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.brandPrimary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: context.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, ru: 'Результат проверки', zh: '检查结果'),
                  style: SpFinanceUi.bodyStyle.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PreviewLine(
            label: tr(context, ru: 'Начислено клиентам', zh: '客户应付'),
            value: _rub(preview.summary.totalDueRub),
            delta: _signedRub(preview.totalDueDeltaRub),
          ),
          const SizedBox(height: 8),
          _PreviewLine(
            label: tr(context, ru: 'Ожидаемая прибыль', zh: '预计利润'),
            value: _rub(preview.summary.totalProfitRub),
            delta: _signedRub(preview.profitDeltaRub),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              context,
              ru: 'Preview не сохранён и не применён.',
              zh: '预览尚未保存或应用。',
            ),
            style: SpFinanceUi.labelStyle.copyWith(color: context.brandPrimary),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ProfileSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.brandPrimary, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: SpFinanceUi.sectionTitleStyle)),
      ],
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final String label;
  final String value;
  final String delta;

  const _PreviewLine({
    required this.label,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: SpFinanceUi.labelStyle)),
        Text(
          value,
          style: SpFinanceUi.bodyStyle.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 8),
        Text(
          delta,
          style: SpFinanceUi.labelStyle.copyWith(
            color: const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String message;

  const _ProfileError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFC2413A).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFC2413A),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: SpFinanceUi.labelStyle)),
        ],
      ),
    );
  }
}

double? _parseRate(String? value) {
  if (value == null) return null;
  return double.tryParse(value.trim().replaceAll(',', '.'));
}

double? _parseOptionalNumber(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return _parseRate(value);
}

String _formatRate(double? value) {
  if (value == null || value <= 0) return '';
  return value
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _rub(double value) {
  final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
  return '$fixed ₽';
}

String _signedRub(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${_rub(value)}';
}
