import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../core/utils/error_utils.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../referral/data/referral_provider.dart';
import '../data/invoices_provider.dart';
import '../domain/invoice_item.dart';

String _localizeMarket(String market) {
  switch (market.trim()) {
    case '19公里':
      return 'Южные ворота';
    case '柳布利诺':
      return 'Люблино';
    default:
      return market;
  }
}

/// Парсит HEX цвет из строки
Color? _parseHexColor(String? hexString) {
  if (hexString == null || hexString.isEmpty) return null;
  try {
    String hex = hexString.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return null;
  }
}

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String? _selectedStatusCode; // null = "Все"
  String _query = '';

  final GlobalKey _invoicesListKey = GlobalKey();
  final GlobalKey _filtersKey = GlobalKey();
  final GlobalKey _firstInvoiceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  List<InvoiceItem> _applyFilters(List<InvoiceItem> items) {
    final q = _query.trim().toLowerCase();
    return items.where((inv) {
      // Фильтр по статусу (сравниваем по коду статуса)
      final statusOk =
          _selectedStatusCode == null || inv.status == _selectedStatusCode;
      final queryOk = q.isEmpty
          ? true
          : inv.invoiceNumber.toLowerCase().contains(q) ||
                inv.tariffName?.toLowerCase().contains(q) == true;
      return statusOk && queryOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message:
            'Чтобы увидеть счета, сначала выберите или добавьте код клиента.',
      );
    }

    final invoicesAsync = ref.watch(invoicesListProvider(clientCode));
    final statusesAsync = ref.watch(invoiceStatusesProvider);
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);

    Future<void> onRefresh() async {
      ref.invalidate(invoicesListProvider(clientCode));
      ref.invalidate(invoiceStatusesProvider);
      await ref.read(invoicesListProvider(clientCode).future);
    }

    final List<InvoiceStatus> dbStatuses = statusesAsync.when(
      data: (statuses) => statuses,
      loading: () => <InvoiceStatus>[],
      error: (_, _) => <InvoiceStatus>[],
    );

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final errorInfo = ErrorUtils.getErrorInfo(e);
        return EmptyState(
          icon: errorInfo.icon,
          title: errorInfo.title,
          message: errorInfo.message,
        );
      },
      data: (items) {
        final filtered = _applyFilters(items);

        final filtersContainer = Container(
          key: _filtersKey,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: _Filters(
            selectedStatusCode: _selectedStatusCode,
            statuses: dbStatuses,
            query: _query,
            onStatusChanged: (code) => setState(() => _selectedStatusCode = code),
            onQueryChanged: (v) => setState(() => _query = v),
          ),
        );

        return TutorialScreenWrapper(
          screenKey: 'invoices',
          steps: [
            TutorialStep(
              icon: Icons.receipt_long_rounded,
              title: 'Счета на оплату',
              description: 'Счёт выставляется после взвешивания посылок на складе в России. Здесь указан точный итог к оплате.',
              targetKey: _invoicesListKey,
            ),
            TutorialStep(
              icon: Icons.info_rounded,
              title: 'Статус счёта',
              description: '«Требует оплаты» — необходимо оплатить, посылка ждёт. «Оплачен» — посылка уже передана в доставку.',
              targetKey: _firstInvoiceKey,
            ),
            TutorialStep(
              icon: Icons.filter_alt_rounded,
              title: 'Фильтр и поиск',
              description: 'Фильтруйте счета по статусу или ищите по номеру. Актуально когда счетов накопилось много.',
              targetKey: _filtersKey,
            ),
            TutorialStep(
              icon: Icons.payment_rounded,
              title: 'Оплатить счёт',
              description: 'Нажмите на счёт → откроется карточка с деталями. Кнопка «Оплатить» переводит на экран оплаты картой или USDT.',
              targetKey: _firstInvoiceKey,
            ),
            TutorialStep(
              icon: Icons.redeem_rounded,
              title: 'Бонусные килограммы',
              description: 'Если у вас есть бонусный вес из реферальной программы — нажмите «Применить бонус» перед оплатой. Он вычтется из суммы счёта.',
              targetKey: _firstInvoiceKey,
            ),
          ],
          child: RefreshIndicator(
          onRefresh: onRefresh,
          color: context.brandPrimary,
          child: ListView(
            key: _invoicesListKey,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, bottomPad + 16),
            children: [
              Text(
                'Счета',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              filtersContainer,
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Ничего не найдено',
                  message: 'Попробуйте изменить фильтры или строку поиска.',
                )
              else
                ...filtered.asMap().entries.map((entry) {
                  final index = entry.key;
                  final inv = entry.value;
                  final invoiceTile = _InvoiceTile(item: inv, clientCode: clientCode);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: index == 0
                        ? KeyedSubtree(key: _firstInvoiceKey, child: invoiceTile)
                        : invoiceTile,
                  );
                }),
            ],
          ),
        ));
      },
    );
  }
}

class _Filters extends StatefulWidget {
  final String? selectedStatusCode;
  final List<InvoiceStatus> statuses;
  final String query;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String> onQueryChanged;

  const _Filters({
    required this.selectedStatusCode,
    required this.statuses,
    required this.query,
    required this.onStatusChanged,
    required this.onQueryChanged,
  });

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _Filters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        _searchController.text != widget.query) {
      _searchController.text = widget.query;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Виджет поля поиска
    Widget searchField = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.brandPrimary, context.brandSecondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.search_rounded,
              color: context.brandPrimary,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF999999),
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      widget.onQueryChanged('');
                    },
                  )
                : null,
            hintText: 'Поиск по номеру счёта',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) {
            setState(() {});
            widget.onQueryChanged(value);
          },
        ),
      ),
    );

    return Column(
      children: [
        searchField,
        const SizedBox(height: 10),
        _CustomDropdown<String?>(
          value: widget.selectedStatusCode,
          label: 'Статус',
          items: [
            const _DropdownItem<String?>(value: null, label: 'Все'),
            ...widget.statuses.map(
              (s) => _DropdownItem<String?>(value: s.code, label: s.nameRu),
            ),
          ],
          onChanged: widget.onStatusChanged,
        ),
      ],
    );
  }
}

class _DropdownItem<T> {
  final T value;
  final String label;
  const _DropdownItem({required this.value, required this.label});
}

class _CustomDropdown<T> extends StatefulWidget {
  final T value;
  final String label;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _CustomDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<_CustomDropdown<T>> {
  late T _selectedValue;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(_CustomDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selectedValue = widget.value;
    }
  }

  void _showMenu() {
    final renderBox =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
    final double menuWidth = renderBox?.size.width ?? 200;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: menuWidth,
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isFirst = index == 0;
                  final isLast = index == widget.items.length - 1;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedValue = item.value;
                      });
                      widget.onChanged(item.value);
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                    },
                    // Добавляем borderRadius для InkWell эффекта
                    borderRadius: BorderRadius.vertical(
                      top: isFirst ? const Radius.circular(14) : Radius.zero,
                      bottom: isLast ? const Radius.circular(14) : Radius.zero,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedValue == item.value
                            ? context.brandPrimary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        // Добавляем borderRadius для первого/последнего элемента
                        borderRadius: BorderRadius.vertical(
                          top: isFirst ? const Radius.circular(14) : Radius.zero,
                          bottom: isLast ? const Radius.circular(14) : Radius.zero,
                        ),
                      ),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedValue == item.value
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedValue == item.value
                              ? context.brandPrimary
                              : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.items.cast<_DropdownItem<T>?>().firstWhere(
      (item) => item?.value == _selectedValue,
      orElse: () => null,
    );
    final selectedLabel = selectedItem?.label ?? 'Все';

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          if (_overlayEntry == null) {
            _showMenu();
          } else {
            _hideMenu();
          }
        },
        child: Container(
          key: _targetKey,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(
                _overlayEntry != null
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: context.brandPrimary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Карточка счёта в списке ──────────────────────────────────────────────────

class _InvoiceTile extends ConsumerStatefulWidget {
  final InvoiceItem item;
  final String clientCode;

  const _InvoiceTile({required this.item, required this.clientCode});

  @override
  ConsumerState<_InvoiceTile> createState() => _InvoiceTileState();
}

class _InvoiceTileState extends ConsumerState<_InvoiceTile> {
  bool _applyingBonus = false;
  bool _isNavigatingToPayment = false;

  bool get _isUnpaid =>
      widget.item.status.toLowerCase() == 'unpaid' ||
      widget.item.status.toLowerCase() == 'pending';

  void _openDetail(BuildContext context, double bonusBalance, double maxBonusPct) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _InvoiceDetailSheet(
        item: widget.item,
        clientCode: widget.clientCode,
        bonusBalance: bonusBalance,
        maxBonusPercent: maxBonusPct,
        onPay: () {
          Navigator.pop(sheetContext);
          _goToPayment(context);
        },
        onBonusApplied: () {
          final clientCode = ref.read(activeClientCodeProvider);
          if (clientCode != null) {
            ref.invalidate(invoicesListProvider(clientCode));
          }
          ref.invalidate(referralProvider);
        },
      ),
    );
  }

  void _goToPayment(BuildContext context) {
    if (_isNavigatingToPayment) return;
    _isNavigatingToPayment = true;

    final item = widget.item;

    // Try Telegram payment first
    final paymentTgUsername = ref.read(paymentTgUsernameProvider).whenOrNull(data: (v) => v);
    if (paymentTgUsername != null && paymentTgUsername.isNotEmpty) {
      final text = Uri.encodeComponent(
        'Добрый день! Хочу оплатить счет ${item.invoiceNumber}',
      );
      final tgUrl = 'tg://resolve?domain=$paymentTgUsername&text=$text';
      final webUrl = 'https://t.me/$paymentTgUsername';

      launchUrl(Uri.parse(tgUrl), mode: LaunchMode.externalApplication).then((_) {
        if (mounted) setState(() => _isNavigatingToPayment = false);
      }).catchError((_) {
        launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication).whenComplete(() {
          if (mounted) setState(() => _isNavigatingToPayment = false);
        });
      });
      return;
    }

    // Fallback: in-app payment chat
    _goToPaymentChat(context);
  }

  void _goToPaymentChat(BuildContext context) {
    final money = NumberFormat.decimalPattern('ru');
    final item = widget.item;
    final buffer = StringBuffer();
    buffer.writeln('💳 **Запрос на оплату счёта**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🆔 ID: ${item.id}');
    buffer.writeln('🔢 Номер: ${item.invoiceNumber}');
    buffer.writeln('📊 Статус: ${item.statusName ?? item.status}');
    buffer.writeln('');
    buffer.writeln('💵 К оплате: \$${money.format(item.totalCostUsd.round())}');
    if (item.totalCostCny > 0) {
      buffer.writeln('🇨🇳 К оплате: ¥${money.format(item.totalCostCny.round())}');
    }
    if (item.totalCostRub > 0) {
      buffer.writeln('🇷🇺 К оплате: ${money.format(item.totalCostRub.round())} ₽');
    }
    if (item.clientRubRate != null || item.clientYuanRate != null) {
      buffer.writeln('');
      if (item.clientRubRate != null) {
        buffer.writeln('📈 Курс \$/₽: ${item.clientRubRate!.toStringAsFixed(2)}');
      }
      if (item.clientYuanRate != null) {
        buffer.writeln('📈 Курс \$/¥: ${item.clientYuanRate!.toStringAsFixed(2)}');
      }
    }

    context.push('/payment-chat', extra: {
      'message': buffer.toString(),
      'invoiceId': item.id,
      'invoiceNumber': item.invoiceNumber,
      'amount': item.totalCostUsd,
      if (item.totalCostCny > 0) 'totalCostCny': item.totalCostCny,
      if (item.totalCostRub > 0) 'totalCostRub': item.totalCostRub,
      if (item.clientRubRate != null) 'clientRubRate': item.clientRubRate,
      if (item.clientYuanRate != null) 'clientYuanRate': item.clientYuanRate,
    }).whenComplete(() {
      if (mounted) setState(() => _isNavigatingToPayment = false);
    });
  }

  Future<void> _quickApplyBonus(double balance, double maxBonusPct) async {
    final item = widget.item;
    final pricePerKg = item.clientPricePerKg ?? item.tariffBaseCost ?? 0;
    if (pricePerKg <= 0) return;

    final maxKg = (item.weight * maxBonusPct / 100).clamp(0.0, balance);
    if (maxKg <= 0) return;

    // Применяем максимально доступное количество кг
    setState(() => _applyingBonus = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/client/invoices/${item.id}/apply-bonus',
        data: {'bonusKg': maxKg},
      );
      ref.invalidate(referralProvider);
      final clientCode = ref.read(activeClientCodeProvider);
      if (clientCode != null) ref.invalidate(invoicesListProvider(clientCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Применено ${maxKg.toStringAsFixed(2)} бонусных кг'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка применения бонуса'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _applyingBonus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final df = DateFormat('dd MMM yyyy', 'ru');
    final money = NumberFormat.decimalPattern('ru');
    final statusColor = _parseHexColor(item.statusColor);
    final referralAsync = ref.watch(referralProvider);

    final double bonusBalance = referralAsync.whenOrNull(data: (r) => r.referralKgBalance) ?? 0;
    final double maxBonusPct = referralAsync.whenOrNull(data: (r) => r.maxBonusPercent) ?? 0;
    final bool hasBonusForThisInvoice =
        _isUnpaid && bonusBalance > 0 && (item.clientPricePerKg ?? item.tariffBaseCost ?? 0) > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Основная информация ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Номер + статус
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        item.invoiceNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusPill(
                      text: item.statusName ?? item.status,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Даты (только непустые)
                ..._buildDateRows(item, df),
                const SizedBox(height: 8),

                // Суммы
                Row(
                  children: [
                    if (item.totalCostUsd > 0) ...[
                      Text(
                        '\$${money.format(item.totalCostUsd.round())}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: context.brandPrimary,
                        ),
                      ),
                    ],
                    if (item.totalCostCny > 0) ...[
                      if (item.totalCostUsd > 0) const SizedBox(width: 10),
                      Text(
                        '¥${money.format(item.totalCostCny.round())}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ],
                    if (item.totalCostRub > 0) ...[
                      if (item.totalCostUsd > 0 || item.totalCostCny > 0)
                        const SizedBox(width: 10),
                      Text(
                        '${money.format(item.totalCostRub.round())} ₽',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Баннер бонусных кг ──
          if (hasBonusForThisInvoice) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.redeem_rounded, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'У вас ${bonusBalance.toStringAsFixed(2)} бонусных кг',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _applyingBonus
                        ? null
                        : () => _openDetail(context, bonusBalance, maxBonusPct),
                    child: Text(
                      'Применить →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Кнопки ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openDetail(context, bonusBalance, maxBonusPct),
                    child: const Text('Открыть'),
                  ),
                ),
                if (_isUnpaid) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _goToPayment(context),
                      child: const Text('Оплатить'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDateRows(InvoiceItem item, DateFormat df) {
    final rows = <Widget>[];

    void addRow(String label, DateTime dt) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              Text(
                '$label: ',
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
              Text(
                df.format(dt),
                style: const TextStyle(fontSize: 12, color: Color(0xFF444444), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (item.createdAt != null) addRow('Создан', item.createdAt!);
    if (item.paidAt != null) addRow('Оплачен', item.paidAt!);

    return rows;
  }
}

// ─── Детальный лист счёта ─────────────────────────────────────────────────────

class _InvoiceDetailSheet extends ConsumerStatefulWidget {
  final InvoiceItem item;
  final String clientCode;
  final double bonusBalance;
  final double maxBonusPercent;
  final VoidCallback onPay;
  final VoidCallback onBonusApplied;

  const _InvoiceDetailSheet({
    required this.item,
    required this.clientCode,
    required this.bonusBalance,
    required this.maxBonusPercent,
    required this.onPay,
    required this.onBonusApplied,
  });

  @override
  ConsumerState<_InvoiceDetailSheet> createState() =>
      _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends ConsumerState<_InvoiceDetailSheet> {
  final _bonusKgCtrl = TextEditingController();
  bool _isApplyingBonus = false;

  @override
  void dispose() {
    _bonusKgCtrl.dispose();
    super.dispose();
  }

  bool get _isUnpaid =>
      widget.item.status.toLowerCase() == 'unpaid' ||
      widget.item.status.toLowerCase() == 'pending';

  Future<void> _applyBonusKg() async {
    final item = widget.item;
    final kg = double.tryParse(_bonusKgCtrl.text.replaceAll(',', '.'));
    if (kg == null || kg <= 0) return;

    final maxKg = (item.weight * widget.maxBonusPercent / 100)
        .clamp(0.0, widget.bonusBalance);
    if (kg > maxKg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Максимум: ${maxKg.toStringAsFixed(2)} кг'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isApplyingBonus = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/client/invoices/${item.id}/apply-bonus',
        data: {'bonusKg': kg},
      );
      _bonusKgCtrl.clear();
      widget.onBonusApplied();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Применено ${kg.toStringAsFixed(2)} бонусных кг'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка применения бонуса'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplyingBonus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final df = DateFormat('dd MMM yyyy', 'ru');
    final money = NumberFormat.decimalPattern('ru');
    final statusColor = _parseHexColor(item.statusColor);
    final pricePerKg = item.clientPricePerKg ?? item.tariffBaseCost ?? 0;
    final maxKg = (item.weight * widget.maxBonusPercent / 100)
        .clamp(0.0, widget.bonusBalance);
    final enteredKg =
        double.tryParse(_bonusKgCtrl.text.replaceAll(',', '.')) ?? 0;
    final bonusDiscount = enteredKg * pricePerKg;
    final showBonusSection =
        _isUnpaid && widget.bonusBalance > 0 && pricePerKg > 0;

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              // Ручка
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Заголовок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.invoiceNumber,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: item.invoiceNumber),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Номер скопирован'),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.copy,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          StatusPill(
                            text: item.statusName ?? item.status,
                            color: statusColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),

              // Контент
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    top: 20,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                  children: [

                    // ══ Основная информация ══════════════════════════════
                    _buildSection('Основная информация', [
                      if (item.createdAt != null)
                        _buildInfoRow(context, 'Дата создания',
                            df.format(item.createdAt!)),
                      if (item.paidAt != null)
                        _buildInfoRow(context, 'Дата оплаты',
                            df.format(item.paidAt!)),
                      if (item.arrivalMarket != null &&
                          item.arrivalMarket!.isNotEmpty)
                        _buildInfoRow(context, 'Рынок прибытия',
                            _localizeMarket(item.arrivalMarket!)),
                    ]),
                    const SizedBox(height: 20),

                    // ══ Информация по коробкам ═══════════════════════════
                    _buildSection('Информация по коробкам', [
                      if (item.placesCount > 0)
                        _buildInfoRow(context, 'Количество мест',
                            '${item.placesCount}'),
                      if (item.weight > 0)
                        _buildInfoRow(context, 'Вес',
                            '${item.weight.toStringAsFixed(2)} кг'),
                      if (item.volume > 0)
                        _buildInfoRow(context, 'Объём',
                            '${item.volume.toStringAsFixed(3)} м³'),
                      if (item.weight > 0 && item.volume > 0)
                        _buildInfoRow(context, 'Плотность',
                            '${(item.weight / item.volume).toStringAsFixed(2)} кг/м³'),
                      if (item.scalePhotoUrls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.scalePhotoUrls.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ApiConfig.getMediaUrl(
                                      item.scalePhotoUrls[index]),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 100,
                                    height: 100,
                                    color: const Color(0xFFEEEEEE),
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 20),

                    // ══ Финансовая информация ════════════════════════════
                    _buildSection('Финансовая информация', [

                      // Коэффициент фотоотчёта
                      if (item.photoReportCoefficient != null &&
                          item.photoReportCoefficient! != 1.0) ...[
                        _buildInfoRow(context, 'Коэф. фотоотчёта',
                            'x${item.photoReportCoefficient!.toStringAsFixed(2)}'),
                        if (item.totalTracks > 0)
                          _buildInfoRow(
                              context,
                              'Треки с фото / без',
                              '${item.tracksWithPhoto} / '
                              '${item.totalTracks - item.tracksWithPhoto} '
                              'из ${item.totalTracks}'),
                      ],

                      // Тариф: базовый
                      if (item.clientPricePerKg != null && item.clientPricePerKg! > 0)
                        _buildInfoRow(context, 'Тариф',
                            '\$${item.clientPricePerKg!.toStringAsFixed(2)}/кг'),

                      // Коэффициент за фото
                      if (item.photoReportCoefficient != null && item.photoReportCoefficient! > 1.0)
                        _buildInfoRow(context, 'Коэфф. фото',
                            '×${item.photoReportCoefficient!.toStringAsFixed(2)}'),

                      // Итоговый тариф с коэффициентом
                      if (item.clientPricePerKgWithPhoto != null && item.clientPricePerKgWithPhoto! > 0 &&
                          item.clientPricePerKgWithPhoto != item.clientPricePerKg)
                        _buildInfoRow(context, 'Итого тариф',
                            '\$${item.clientPricePerKgWithPhoto!.toStringAsFixed(2)}/кг'),

                      // Стоимость доставки
                      if (item.shippingCost != null && item.shippingCost! > 0)
                        _buildInfoRow(context, 'Стоимость доставки',
                            '\$${item.shippingCost!.toStringAsFixed(2)}'),

                      const Divider(height: 20),

                      // Разгрузка
                      if (item.transshipmentCost != null && item.transshipmentCost! > 0)
                        _buildInfoRow(context, 'Разгрузка',
                            '\$${item.transshipmentCost!.toStringAsFixed(2)}'),

                      // Упаковка (детализация или сумма)
                      if (item.packagings.isNotEmpty)
                        ...item.packagings.map(
                          (p) => _buildInfoRow(context,
                              'Упаковка: ${p.name}',
                              '\$${p.cost.toStringAsFixed(2)}'),
                        )
                      else if (item.packagingCostTotal != null &&
                          item.packagingCostTotal! > 0)
                        _buildInfoRow(context, 'Упаковка',
                            '\$${item.packagingCostTotal!.toStringAsFixed(2)}'),

                      // Страховка клиента
                      if (item.insurancePercentClient != null && item.insurancePercentClient! > 0)
                        _buildInfoRow(context, 'Страховка',
                            '${item.insurancePercentClient!.toStringAsFixed(1)}%')
                      else if (item.insurancePercent != null && item.insurancePercent! > 0)
                        _buildInfoRow(context, 'Страховка',
                            '${item.insurancePercent!.toStringAsFixed(1)}%'),

                      // Страховка $ (клиентская сумма)
                      if (item.insuranceCostClient != null && item.insuranceCostClient! > 0)
                        _buildInfoRow(context, 'Страховка',
                            '\$${item.insuranceCostClient!.toStringAsFixed(2)}')
                      else if (item.insuranceCost != null && item.insuranceCost! > 0)
                        _buildInfoRow(context, 'Страховка',
                            '\$${item.insuranceCost!.toStringAsFixed(2)}'),

                      // Скидка
                      if (item.discountAmount != null && item.discountAmount! > 0)
                        _buildInfoRow(context, 'Скидка',
                            '−\$${item.discountAmount!.toStringAsFixed(2)}'),

                      // Применённые бонусные кг
                      if (item.bonusKgApplied > 0)
                        _buildInfoRow(context, 'Оплата бонусами',
                            '−${item.bonusKgApplied.toStringAsFixed(2)} кг'),

                      const Divider(height: 20),

                      // Итого $
                      if (item.totalCostUsd > 0)
                        _buildInfoRow(context, 'К оплате',
                            '\$${item.totalCostUsd.toStringAsFixed(2)}',
                            isTotal: true),

                      // Итого ¥
                      if (item.totalCostCny > 0) ...[
                        const SizedBox(height: 4),
                        _buildInfoRow(context, 'К оплате',
                            '¥${money.format(item.totalCostCny.round())}',
                            isTotal: true),
                      ],

                      // Итого ₽
                      if (item.totalCostRub > 0) ...[
                        const SizedBox(height: 4),
                        _buildInfoRow(context, 'К оплате',
                            '${money.format(item.totalCostRub.round())} ₽',
                            isTotal: true),
                      ],

                      // Курс валют (только если есть)
                      if (item.clientRubRate != null || item.clientYuanRate != null) ...[
                        const Divider(height: 20),
                        if (item.clientRubRate != null)
                          _buildInfoRow(context, 'Курс \$/₽',
                              item.clientRubRate!.toStringAsFixed(2)),
                        if (item.clientYuanRate != null)
                          _buildInfoRow(context, 'Курс \$/¥',
                              item.clientYuanRate!.toStringAsFixed(4)),
                      ],
                    ]),
                    const SizedBox(height: 24),

                    // ══ Бонусные кг ══════════════════════════════════════
                    if (showBonusSection) ...[
                      const Text(
                        'Бонусные кг',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.scale_rounded,
                                    color: Colors.green.shade700, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Доступно: ${widget.bonusBalance.toStringAsFixed(2)} кг',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (item.bonusKgApplied > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Уже применено: ${item.bonusKgApplied.toStringAsFixed(2)} кг',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _bonusKgCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Кол-во кг (макс ${maxKg.toStringAsFixed(2)})',
                                      filled: true,
                                      fillColor: Colors.white,
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.green.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.green.shade600,
                                            width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.green.shade300),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: _isApplyingBonus
                                        ? null
                                        : _applyBonusKg,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                    ),
                                    child: _isApplyingBonus
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Применить'),
                                  ),
                                ),
                              ],
                            ),
                            if (enteredKg > 0 && pricePerKg > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Скидка: ~\$${bonusDiscount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ══ Кнопка оплаты ════════════════════════════════════
                    if (_isUnpaid)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.onPay,
                          child: const Text('Перейти к оплате'),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: isTotal
                    ? const Color(0xFF333333)
                    : const Color(0xFF666666),
                fontSize: isTotal ? 15 : 14,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isTotal ? context.brandPrimary : const Color(0xFF333333),
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
