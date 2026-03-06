// TODO: Update to ShowcaseView.get() API when showcaseview 6.0.0 is released
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/auto_refresh_service.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../core/utils/error_utils.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../referral/data/referral_provider.dart';
import '../data/invoices_provider.dart';
import '../domain/invoice_item.dart';

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

class _InvoicesScreenState extends ConsumerState<InvoicesScreen>
    with AutoRefreshMixin {
  String? _selectedStatusCode; // null = "Все"
  String _query = '';

  // Showcase keys
  final _showcaseKeyFilters = GlobalKey();
  final _showcaseKeySearch = GlobalKey();
  final _showcaseKeyInvoiceItem = GlobalKey();

  bool _showcaseStarted = false;
  bool _allSkipped = false;
  List<ShowcaseBlock> _currentRunBlocks = [];

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
  }

  void _startShowcaseIfNeeded(BuildContext showcaseContext) {
    if (_showcaseStarted) return;
    if (!TickerMode.of(showcaseContext)) return;

    final pairs = [
      (_showcaseKeyFilters, ShowcaseBlock.invoicesFilters),
      (_showcaseKeySearch, ShowcaseBlock.invoicesFilters),
      (_showcaseKeyInvoiceItem, ShowcaseBlock.invoicesItem),
    ];

    final visible = pairs
        .where((p) => p.$1.currentContext != null && ref.read(showcaseBlockProvider(p.$2)))
        .toList();

    if (visible.isEmpty) {
      _showcaseStarted = false;
      return;
    }

    _showcaseStarted = true;
    _currentRunBlocks = visible.map((p) => p.$2).toSet().toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(showcasePendingBlocksProvider.notifier).setBlocks(_currentRunBlocks);
      startShowCaseSafe(showcaseContext, visible.map((p) => p.$1).toList());
    });
  }

  void _onShowcaseComplete() {
    for (final block in _currentRunBlocks) {
      ref.read(showcaseServiceProvider).markBlockAsSeen(block);
      ref.invalidate(showcaseBlockProvider(block));
    }
    _currentRunBlocks = [];
  }

  void _skipAllShowcases() {
    setState(() => _allSkipped = true);
    ref.read(showcaseServiceProvider).markAllBlocksSeen();
    for (final block in ShowcaseBlock.values) {
      ref.invalidate(showcaseBlockProvider(block));
    }
  }

  void _setupAutoRefresh() {
    startAutoRefresh(() {
      final clientCode = ref.read(activeClientCodeProvider);
      if (clientCode != null) {
        ref.invalidate(invoicesListProvider(clientCode));
        ref.invalidate(invoiceStatusesProvider);
      }
    });
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
    final shouldShowFilters = !_allSkipped && ref.watch(showcaseBlockProvider(ShowcaseBlock.invoicesFilters));
    final shouldShowItem = !_allSkipped && ref.watch(showcaseBlockProvider(ShowcaseBlock.invoicesItem));
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);

    Future<void> onRefresh() async {
      ref.invalidate(invoicesListProvider(clientCode));
      ref.invalidate(invoiceStatusesProvider);
      await ref.read(invoicesListProvider(clientCode).future);
    }

    // Собираем список статусов для фильтра
    final List<InvoiceStatus> dbStatuses = statusesAsync.when(
      data: (statuses) => statuses,
      loading: () => <InvoiceStatus>[],
      error: (_, _) => <InvoiceStatus>[],
    );

    return ShowcaseWrapper(
      onComplete: _onShowcaseComplete,
      onSkipAll: _skipAllShowcases,
      child: Builder(
        builder: (showcaseContext) {

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

              // Запускаем showcase когда данные загружены
              if (filtered.isNotEmpty) {
                _startShowcaseIfNeeded(showcaseContext);
              }

              return RefreshIndicator(
                onRefresh: onRefresh,
                color: context.brandPrimary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topPad * 0.7 + 6,
                    16,
                    bottomPad + 16,
                  ),
                  children: [
                    Text(
                      'Счета',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Builder(
                      builder: (_) {
                        final filtersContainer = Container(
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
                            onStatusChanged: (code) =>
                                setState(() => _selectedStatusCode = code),
                            onQueryChanged: (v) => setState(() => _query = v),
                            showcaseSearchKey: shouldShowFilters ? _showcaseKeySearch : null,
                          ),
                        );
                        return shouldShowFilters
                            ? Showcase(
                                key: _showcaseKeyFilters,
                                title: '💳 Фильтр по статусу оплаты',
                                description: 'Быстрая фильтрация счетов по состоянию:\n• Все - показать все счета\n• Ожидает оплаты - неоплаченные счета\n• Оплачен - успешно оплаченные\n• Частично оплачен - требуется доплата\n• Просрочен - истёк срок оплаты\n\nВыберите статус из выпадающего списка для фильтрации.',
                                targetBorderRadius: BorderRadius.circular(20),
                                targetPadding: getShowcaseTargetPadding(),
                                tooltipPosition: TooltipPosition.bottom,
                                tooltipBackgroundColor: Colors.white,
                                textColor: Colors.black87,
                                titleTextStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                                descTextStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                                child: filtersContainer,
                              )
                            : filtersContainer;
                      },
                    ),
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

                  // Первый элемент оборачиваем в Showcase (только если туториал ещё не показан)
                  if (index == 0 && shouldShowItem) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Showcase(
                        key: _showcaseKeyInvoiceItem,
                        title: '📄 Карточка счёта',
                        description: 'Полная информация о счёте на оплату:\n• Номер счёта и дата выставления\n• Текущий статус оплаты (цветной индикатор)\n• Общая сумма к оплате\n• Название тарифа и услуг\n• Дата последнего обновления\n\nНажмите на карточку для просмотра деталей:\n• Подробный состав услуг\n• История изменений статуса\n• Возможность скачать PDF счёт\n• Реквизиты для оплаты',
                        targetBorderRadius: BorderRadius.circular(18),
                        targetPadding: getShowcaseTargetPadding(),
                        tooltipPosition: TooltipPosition.bottom,
                        tooltipBackgroundColor: Colors.white,
                        textColor: Colors.black87,
                        titleTextStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                        descTextStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                        child: invoiceTile,
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: invoiceTile,
                  );
                }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Filters extends StatefulWidget {
  final String? selectedStatusCode;
  final List<InvoiceStatus> statuses;
  final String query;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String> onQueryChanged;
  final GlobalKey? showcaseSearchKey;

  const _Filters({
    required this.selectedStatusCode,
    required this.statuses,
    required this.query,
    required this.onStatusChanged,
    required this.onQueryChanged,
    this.showcaseSearchKey,
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

    // Оборачиваем в Showcase если ключ передан
    if (widget.showcaseSearchKey != null) {
      searchField = Showcase(
        key: widget.showcaseSearchKey!,
        title: '🔍 Поиск по номеру счёта',
        description:
            'Быстрый поиск конкретного счёта:\n• Введите полный или частичный номер\n• Поиск работает в реальном времени\n• Нажмите ✕ справа для очистки\n\nНапример: "INV-2024-001" или просто "001".',
        targetBorderRadius: BorderRadius.circular(14),
        targetPadding: getShowcaseTargetPadding(),
        tooltipPosition: TooltipPosition.bottom,
        tooltipBackgroundColor: Colors.white,
        textColor: Colors.black87,
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
        descTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
        child: searchField,
      );
    }

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
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
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

class _InvoiceTile extends StatelessWidget {
  final InvoiceItem item;
  final String clientCode;

  const _InvoiceTile({required this.item, required this.clientCode});

  /// К оплате RUB = totalCostUsd × clientRubRate
  double _calculateTotalRub() {
    if (item.totalCostRub > 0) return item.totalCostRub;
    final rate = item.clientRubRate ?? 0;
    return item.totalCostUsd * rate;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    final money = NumberFormat.decimalPattern('ru');
    final statusColor = _parseHexColor(item.statusColor);
    final totalRub = _calculateTotalRub();

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                const SizedBox(width: 12),
                StatusPill(
                  text: item.statusName ?? item.status,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (item.sendDate != null)
              Text(
                df.format(item.sendDate!),
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.totalCostUsd > 0)
                  Text(
                    '\$${money.format(item.totalCostUsd.round())}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: context.brandPrimary,
                    ),
                  ),
                if (item.totalCostUsd > 0 && totalRub > 0)
                  const SizedBox(width: 10),
                if (totalRub > 0)
                  Text(
                    '${money.format(totalRub.round())} ₽',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF333333),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openInvoiceDetailSheet(context),
                    child: const Text('Открыть'),
                  ),
                ),
                if (item.status.toLowerCase() != 'paid') ...[
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
          ],
        ),
      ),
    );
  }

  void _openInvoiceDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _InvoiceDetailSheet(
        item: item,
        clientCode: clientCode,
        onPay: () {
          Navigator.pop(sheetContext);
          _goToPayment(context);
        },
      ),
    );
  }

  void _goToPayment(BuildContext context) {
    final money = NumberFormat.decimalPattern('ru');

    final buffer = StringBuffer();
    buffer.writeln('💳 **Запрос на оплату счёта**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔢 Номер: ${item.invoiceNumber}');
    buffer.writeln('📊 Статус: ${item.statusName ?? item.status}');
    buffer.writeln('');
    buffer.writeln('💵 **Итого: \$${money.format(item.totalCostUsd.round())}**');

    final message = buffer.toString();

    context.push('/payment-chat', extra: {
      'message': message,
      'invoiceId': item.id,
      'invoiceNumber': item.invoiceNumber,
      'amount': item.totalCostUsd,
    });
  }
}

/// Лист с детальной информацией о счёте (только просмотр)
class _InvoiceDetailSheet extends ConsumerStatefulWidget {
  final InvoiceItem item;
  final String clientCode;
  final VoidCallback onPay;

  const _InvoiceDetailSheet({
    required this.item,
    required this.clientCode,
    required this.onPay,
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

  /// К оплате RUB = totalCostUsd × clientRubRate
  double _calculateTotalRub() {
    if (widget.item.totalCostRub > 0) return widget.item.totalCostRub;
    final rate = widget.item.clientRubRate ?? 0;
    return widget.item.totalCostUsd * rate;
  }

  Future<void> _applyBonusKg(double balance, double maxBonusPercent) async {
    final kg = double.tryParse(_bonusKgCtrl.text.replaceAll(',', '.'));
    if (kg == null || kg <= 0) return;

    final maxKg = (widget.item.weight * maxBonusPercent / 100).clamp(0.0, balance);
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
        '/client/invoices/${widget.item.id}/apply-bonus',
        data: {'bonusKg': kg},
      );
      ref.invalidate(referralProvider);
      _bonusKgCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Применено ${kg.toStringAsFixed(2)} бонусных кг'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
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
    final totalRub = _calculateTotalRub();
    final referralAsync = ref.watch(referralProvider);

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
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  children: [
                    // ── Даты ──
                    _buildSection('Даты', [
                      if (item.sendDate != null)
                        _buildInfoRow(context, 'Дата отправки', df.format(item.sendDate!)),
                      if (item.arrivalDate != null)
                        _buildInfoRow(context, 'Дата прибытия', df.format(item.arrivalDate!)),
                      if (item.paymentDate != null)
                        _buildInfoRow(context, 'Дата оплаты', df.format(item.paymentDate!)),
                    ]),
                    const SizedBox(height: 20),

                    // ── Рынок ──
                    if (item.arrivalMarket != null && item.arrivalMarket!.isNotEmpty) ...[
                      _buildSection('Рынок разгрузки', [
                        _buildInfoRow(context, 'Рынок', item.arrivalMarket!),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // ── Габариты ──
                    _buildSection('Габариты и вес', [
                      _buildInfoRow(context, 'Вес', '${item.weight.toStringAsFixed(2)} кг'),
                      _buildInfoRow(context, 'Объём', '${item.volume.toStringAsFixed(3)} м\u00B3'),
                      _buildInfoRow(context, 'Плотность', '${item.density.toStringAsFixed(2)} кг/м\u00B3'),
                    ]),
                    const SizedBox(height: 20),

                    // ── Фото коробок ──
                    if (item.scalePhotoUrls.isNotEmpty) ...[
                      _buildSection('Фото коробок', [
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.scalePhotoUrls.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ApiConfig.getMediaUrl(item.scalePhotoUrls[index]),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 100,
                                    height: 100,
                                    color: const Color(0xFFEEEEEE),
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // ── Стоимость ──
                    _buildSection('Стоимость', [
                      // Тариф
                      if (item.tariffName != null)
                        _buildInfoRow(context, 'Тариф',
                          '${item.tariffName!}${item.tariffBaseCost != null && item.tariffBaseCost! > 0 ? ' (\$${item.tariffBaseCost!.toStringAsFixed(2)}/кг)' : ''}',
                        ),

                      // Надбавка за фотоотчёт
                      if (item.photoReportCoefficient != null &&
                          item.photoReportCoefficient! > 0 &&
                          item.photoReportCoefficient != 1.0) ...[
                        _buildInfoRow(context, 'Надбавка за фотоотчёт',
                          'x${item.photoReportCoefficient!.toStringAsFixed(2)}'),
                        if (item.totalTracks > 0)
                          _buildInfoRow(context, 'Треки с фото / без',
                            '${item.tracksWithPhoto} / ${item.totalTracks - item.tracksWithPhoto} из ${item.totalTracks}'),
                      ],

                      // Упаковка
                      if (item.packagings.isNotEmpty) ...[
                        const Divider(height: 16),
                        ...item.packagings.map(
                          (p) => _buildInfoRow(context, 'Упаковка: ${p.name}',
                            '\$${p.cost.toStringAsFixed(2)}'),
                        ),
                      ] else if (item.packagingCostTotal != null && item.packagingCostTotal! > 0) ...[
                        const Divider(height: 16),
                        _buildInfoRow(context, 'Упаковка',
                          '\$${item.packagingCostTotal!.toStringAsFixed(2)}'),
                      ],

                      // Разгрузка
                      if (item.transshipmentCost != null && item.transshipmentCost! > 0) ...[
                        const Divider(height: 16),
                        _buildInfoRow(context, 'Разгрузка',
                          '\$${item.transshipmentCost!.toStringAsFixed(2)}'),
                      ],

                      // Страховка
                      if (item.insuranceCost != null && item.insuranceCost! > 0) ...[
                        const Divider(height: 16),
                        _buildInfoRow(context, 'Страховка',
                          '\$${item.insuranceCost!.toStringAsFixed(2)}'),
                      ],

                      // Скидка
                      if (item.discountAmount != null && item.discountAmount! > 0) ...[
                        const Divider(height: 16),
                        _buildInfoRow(context, 'Скидка',
                          '−\$${item.discountAmount!.toStringAsFixed(2)}'),
                      ],

                      const Divider(height: 16),

                      // Итого $
                      _buildInfoRow(context, 'Итого к оплате',
                        '\$${item.totalCostUsd.toStringAsFixed(2)}',
                        isTotal: true,
                      ),

                      // Итого ₽
                      if (totalRub > 0) ...[
                        const SizedBox(height: 4),
                        _buildInfoRow(context, 'Итого к оплате',
                          '${money.format(totalRub.round())} \u20BD',
                          isTotal: true,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),

                    // === Бонусные кг ===
                    if (item.status.toLowerCase() == 'unpaid' ||
                        item.status.toLowerCase() == 'pending')
                      referralAsync.whenOrNull(
                        data: (referral) {
                          final balance = referral.referralKgBalance;
                          final maxBonusPercent = referral.maxBonusPercent;
                          if (balance <= 0 && item.bonusKgApplied <= 0) {
                            return null;
                          }
                          final maxKg = (item.weight * maxBonusPercent / 100).clamp(0.0, balance);
                          final pricePerKg = item.clientPricePerKg ?? item.tariffBaseCost ?? 0;
                          final enteredKg = double.tryParse(_bonusKgCtrl.text.replaceAll(',', '.')) ?? 0;
                          final discount = enteredKg * pricePerKg;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                            'Доступно: ${balance.toStringAsFixed(2)} кг',
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
                                      if (balance > 0) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _bonusKgCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: InputDecoration(
                                                  hintText: 'Кол-во кг (макс ${maxKg.toStringAsFixed(2)})',
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  isDense: true,
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.green.shade300),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.green.shade600, width: 2),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.green.shade300),
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                                    : () => _applyBonusKg(balance, maxBonusPercent),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green.shade600,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                            'Скидка: ~\$${discount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ) ?? const SizedBox.shrink(),

                    // Кнопка оплаты
                    if (item.status.toLowerCase() != 'paid')
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

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool isTotal = false}) {
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
                color: isTotal
                    ? context.brandPrimary
                    : const Color(0xFF333333),
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
