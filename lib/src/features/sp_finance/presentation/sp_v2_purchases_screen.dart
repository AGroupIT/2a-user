import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../data/sp_v2_models.dart';
import '../data/sp_v2_provider.dart';
import 'sp_finance_ui.dart';
import 'sp_v2_help_sheet.dart';

class SpV2PurchasesScreen extends ConsumerStatefulWidget {
  const SpV2PurchasesScreen({super.key});

  @override
  ConsumerState<SpV2PurchasesScreen> createState() =>
      _SpV2PurchasesScreenState();
}

class _SpV2PurchasesScreenState extends ConsumerState<SpV2PurchasesScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(spV2PurchasesControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spV2PurchasesControllerProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return Stack(
      children: [
        RefreshIndicator(
          color: context.brandPrimary,
          onRefresh: () =>
              ref.read(spV2PurchasesControllerProvider.notifier).load(),
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 16,
              16,
              bottomPad + 20,
            ),
            children: [
              SpPageHeader(
                title: 'Совместные покупки',
                trailing: SpV2HelpButton(
                  onTap: () => showSpV2HelpSheet(context),
                ),
              ),
              const SizedBox(height: 12),
              _SpV2Hero(state: state),
              const SizedBox(height: 14),
              _SearchCreateBar(
                controller: _searchController,
                isLoading: state.isLoading,
                onChanged: _onSearchChanged,
                onCreate: _showCreatePurchaseSheet,
              ),
              const SizedBox(height: 14),
              if (state.error != null && state.purchases.isEmpty)
                EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить СП',
                  message: state.error!,
                )
              else if (state.isLoading && state.purchases.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 42),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.purchases.isEmpty)
                const _SpV2EmptyCard()
              else
                ...state.purchases.map(
                  (purchase) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SpV2PurchaseCard(purchase: purchase),
                  ),
                ),
            ],
          ),
        ),
        ScrollToTopButton(controller: _scrollController),
      ],
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(spV2PurchasesControllerProvider.notifier).search(value);
    });
  }

  Future<void> _showCreatePurchaseSheet() async {
    final created = await showBlurredModalBottomSheet<SpV2Purchase>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreatePurchaseSheet(),
    );
    if (!mounted || created == null) return;
    context.push('/sp-finance/purchases/${created.id}');
  }
}

class _SpV2Hero extends StatelessWidget {
  final SpV2PurchasesState state;

  const _SpV2Hero({required this.state});

  @override
  Widget build(BuildContext context) {
    final active = state.purchases
        .where(
          (purchase) =>
              purchase.status != 'completed' && purchase.status != 'cancelled',
        )
        .length;
    final items = state.purchases.fold<int>(
      0,
      (sum, purchase) => sum + purchase.stats.itemsCount,
    );

    return SpAnimatedHeroSurface(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.groups_2_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Совместные покупки',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy',
                    fontSize: 23,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Ведите клиентов, товары, выкуп, треки, оплаты и отправки в одном процессе.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SpHeroChip(
                      icon: Icons.playlist_add_check_rounded,
                      label: '$active активных',
                    ),
                    SpHeroChip(
                      icon: Icons.shopping_bag_rounded,
                      label: '$items товаров',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCreateBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onCreate;

  const _SearchCreateBar({
    required this.controller,
    required this.isLoading,
    required this.onChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: SpFinanceUi.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: SpFinanceUi.inputDecoration(
                context,
                hintText: 'Найти СП по названию',
                prefixIcon: Icons.search_rounded,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: context.brandPrimary,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: isLoading ? null : onCreate,
              borderRadius: BorderRadius.circular(18),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpV2PurchaseCard extends StatelessWidget {
  final SpV2Purchase purchase;

  const _SpV2PurchaseCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/sp-finance/purchases/${purchase.id}'),
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: SpFinanceUi.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.brandPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: context.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Gilroy',
                            fontSize: 20,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusPill(
                          label: purchase.statusLabel,
                          isActive: purchase.isAcceptingItems,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(
                    icon: Icons.person_rounded,
                    label: '${purchase.stats.customersCount} клиентов',
                  ),
                  _MetricChip(
                    icon: Icons.shopping_bag_rounded,
                    label: '${purchase.stats.itemsCount} товаров',
                  ),
                  _MetricChip(
                    icon: Icons.local_shipping_rounded,
                    label: '${purchase.stats.linkedTracksCount} треков',
                  ),
                  _MetricChip(
                    icon: purchase.currency == 'RUB'
                        ? Icons.currency_ruble_rounded
                        : Icons.currency_yuan_rounded,
                    label: purchase.currency == 'RUB' ? 'Рубли' : 'Юани',
                  ),
                  _MetricChip(
                    icon: Icons.payments_rounded,
                    label: formatter.format(purchase.stats.totalDueRub),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool isActive;

  const _StatusPill({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? context.brandPrimary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Gilroy',
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.025)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.brandPrimary, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpV2EmptyCard extends StatelessWidget {
  const _SpV2EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        children: [
          Icon(
            Icons.add_business_rounded,
            color: context.brandPrimary,
            size: 38,
          ),
          const SizedBox(height: 12),
          const Text(
            'Создайте первую совместную покупку',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Совместная покупка теперь начинается до сборки: сначала клиенты и товары, потом выкуп, треки, расчёт и отправки.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePurchaseSheet extends ConsumerStatefulWidget {
  const _CreatePurchaseSheet();

  @override
  ConsumerState<_CreatePurchaseSheet> createState() =>
      _CreatePurchaseSheetState();
}

class _CreatePurchaseSheetState extends ConsumerState<_CreatePurchaseSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purchaseRateController = TextEditingController();
  String _currency = 'CNY';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text =
        'СП от ${DateFormat('dd.MM.yyyy').format(DateTime.now())}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _purchaseRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        bottom: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 58,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E5ED),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SpAnimatedHeroSurface(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.add_business_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Новая СП',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Создайте процесс, а товары добавите внутри.',
                              style: TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontFamily: 'Gilroy',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  children: [
                    SpCurrencySelector(
                      value: _currency,
                      onChanged: (value) => setState(() => _currency = value),
                    ),
                    const SizedBox(height: 10),
                    SpInfoNotice(
                      title: 'На что влияет валюта',
                      message: _currency == 'CNY'
                          ? 'Цены выкупа и цены для клиента будут вводиться в юанях. Чтобы финансы и оплаты считались в рублях, укажите курс ¥ → ₽.'
                          : 'Цены выкупа и цены для клиента будут вводиться сразу в рублях. Курс юаня для этой СП не нужен.',
                      icon: _currency == 'CNY'
                          ? Icons.currency_yuan_rounded
                          : Icons.currency_ruble_rounded,
                    ),
                    if (_currency == 'CNY') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _purchaseRateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: SpFinanceUi.inputDecoration(
                          context,
                          labelText: 'Курс юаня',
                          hintText: 'Например: 12.80',
                          suffixText: '₽ за ¥',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleController,
                      decoration: SpFinanceUi.inputDecoration(
                        context,
                        labelText: 'Название СП',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: SpFinanceUi.inputDecoration(
                        context,
                        labelText: 'Комментарий',
                        hintText: 'Например: закупка обуви / майский выкуп',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomPadding),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Создать СП'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final purchase = await ref
          .read(spV2PurchasesControllerProvider.notifier)
          .createPurchase(
            CreateSpV2PurchaseInput(
              title: title,
              description: _descriptionController.text.trim(),
              currency: _currency,
              purchaseRate: _currency == 'CNY'
                  ? _readDouble(_purchaseRateController.text)
                  : null,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(purchase);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double? _readDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}
