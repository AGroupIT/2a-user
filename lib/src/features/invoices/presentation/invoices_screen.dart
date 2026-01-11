import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/auto_refresh_service.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_pill.dart';
import '../../clients/application/client_codes_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
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
      error: (_, __) => <InvoiceStatus>[],
    );

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить счета',
        message: e.toString(),
      ),
      data: (items) {
        final filtered = _applyFilters(items);

        return RefreshIndicator(
          onRefresh: onRefresh,
          color: const Color(0xFFfe3301),
          child: ListView(
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
              Container(
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
                ),
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Ничего не найдено',
                  message: 'Попробуйте изменить фильтры или строку поиска.',
                )
              else
                ...filtered.map(
                  (inv) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InvoiceTile(item: inv, clientCode: clientCode),
                  ),
                ),
            ],
          ),
        );
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
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFfe3301),
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
        ),
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
                children: widget.items.map((item) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedValue = item.value;
                      });
                      widget.onChanged(item.value);
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedValue == item.value
                            ? const Color(0xFFfe3301).withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedValue == item.value
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedValue == item.value
                              ? const Color(0xFFfe3301)
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
                color: const Color(0xFFfe3301),
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

  /// Расчёт стоимости тарифа = вес × baseCost (или объём × 250)
  double _calculateTariffCost() {
    final baseCost = item.tariffBaseCost ?? 0;
    final isByWeight = item.calculationMethod?.toLowerCase() == 'byweight';
    if (isByWeight) {
      return item.weight * baseCost;
    } else {
      return item.volume * 250;
    }
  }

  /// Расчёт общей стоимости упаковки
  double _calculatePackagingCost() {
    // Если есть готовая сумма из API
    if (item.packagingCostTotal != null && item.packagingCostTotal! > 0) {
      return item.packagingCostTotal!;
    }
    // Иначе считаем: сумма стоимости упаковок × кол-во мест
    double sum = 0;
    for (final pkg in item.packagings) {
      sum += pkg.cost;
    }
    return sum * item.placesCount;
  }

  /// Расчёт Доставки USD по формуле из админа:
  /// Доставка = тариф + упаковка + перевалка + страховка - скидка
  double _calculateDeliveryCostUsd() {
    // Если API вернул готовое значение - используем его
    if (item.deliveryCostUsd > 0) {
      return item.deliveryCostUsd;
    }
    // Иначе считаем по формуле
    final tariffCost = _calculateTariffCost();
    final packagingCost = _calculatePackagingCost();
    final transshipment = item.transshipmentCost ?? 0;
    final insurance = item.insuranceCost ?? 0;
    final discount = item.discount ?? 0;
    return tariffCost + packagingCost + transshipment + insurance - discount;
  }

  /// Расчёт К оплате RUB = Доставка USD × Курс
  double _calculateTotalRub() {
    // Если API вернул готовое значение - используем его
    if (item.totalCostRub > 0) {
      return item.totalCostRub;
    }
    // Иначе считаем по формуле
    final deliveryUsd = _calculateDeliveryCostUsd();
    final rate = item.rate ?? 0;
    return deliveryUsd * rate;
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
            Text(
              df.format(item.sendDate),
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 4),
            Text(
              '${money.format(totalRub.round())} ₽',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFFfe3301),
              ),
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
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _goToPayment(context),
                    child: const Text('Оплатить'),
                  ),
                ),
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
      isScrollControlled: true,
      useSafeArea: false,
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
    final totalRub = _calculateTotalRub();
    final message =
        'Хочу оплатить счёт ${item.invoiceNumber} на сумму ${money.format(totalRub.round())} ₽';

    // Переходим на страницу поддержки с сообщением
    context.push('/support', extra: message);
  }
}

/// Лист с детальной информацией о счёте (только просмотр)
class _InvoiceDetailSheet extends StatelessWidget {
  final InvoiceItem item;
  final String clientCode;
  final VoidCallback onPay;

  const _InvoiceDetailSheet({
    required this.item,
    required this.clientCode,
    required this.onPay,
  });

  /// Перевод метода расчёта
  String _translateCalculationMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'byweight':
        return 'По весу';
      case 'byvolume':
        return 'По объёму';
      default:
        return method ?? '';
    }
  }

  /// Расчёт стоимости тарифа = вес × baseCost (или объём × 250)
  double _calculateTariffCost() {
    final baseCost = item.tariffBaseCost ?? 0;
    final isByWeight = item.calculationMethod?.toLowerCase() == 'byweight';
    if (isByWeight) {
      return item.weight * baseCost;
    } else {
      return item.volume * 250;
    }
  }

  /// Расчёт общей стоимости упаковки
  double _calculatePackagingCost() {
    // Если есть готовая сумма из API
    if (item.packagingCostTotal != null && item.packagingCostTotal! > 0) {
      return item.packagingCostTotal!;
    }
    // Иначе считаем: сумма стоимости упаковок × кол-во мест
    double sum = 0;
    for (final pkg in item.packagings) {
      sum += pkg.cost;
    }
    return sum * item.placesCount;
  }

  /// Расчёт Доставки USD по формуле из админа:
  /// Доставка = тариф + упаковка + перевалка + страховка - скидка
  double _calculateDeliveryCostUsd() {
    // Если API вернул готовое значение - используем его
    if (item.deliveryCostUsd > 0) {
      return item.deliveryCostUsd;
    }
    // Иначе считаем по формуле
    final tariffCost = _calculateTariffCost();
    final packagingCost = _calculatePackagingCost();
    final transshipment = item.transshipmentCost ?? 0;
    final insurance = item.insuranceCost ?? 0;
    final discount = item.discount ?? 0;
    return tariffCost + packagingCost + transshipment + insurance - discount;
  }

  /// Расчёт К оплате RUB = Доставка USD × Курс
  double _calculateTotalRub() {
    // Если API вернул готовое значение - используем его
    if (item.totalCostRub > 0) {
      return item.totalCostRub;
    }
    // Иначе считаем по формуле
    final deliveryUsd = _calculateDeliveryCostUsd();
    final rate = item.rate ?? 0;
    return deliveryUsd * rate;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    final money = NumberFormat.decimalPattern('ru');
    final statusColor = _parseHexColor(item.statusColor);

    final deliveryCostUsd = _calculateDeliveryCostUsd();
    final totalRub = _calculateTotalRub();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                    _buildSection('Основная информация', [
                      _buildInfoRow('Код клиента', clientCode),
                      _buildInfoRow('Дата', df.format(item.sendDate)),
                      if (item.tariffName != null)
                        _buildInfoRow(
                          'Тариф',
                          '${item.tariffName!}${item.tariffBaseCost != null ? ' (\$${item.tariffBaseCost!.toStringAsFixed(2)}/кг)' : ''}',
                        ),
                      if (item.calculationMethod != null)
                        _buildInfoRow(
                          'Метод расчёта',
                          _translateCalculationMethod(item.calculationMethod),
                        ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSection('Габариты и вес', [
                      _buildInfoRow('Кол-во мест', '${item.placesCount}'),
                      _buildInfoRow(
                        'Вес',
                        '${item.weight.toStringAsFixed(2)} кг',
                      ),
                      _buildInfoRow(
                        'Объём',
                        '${item.volume.toStringAsFixed(3)} м³',
                      ),
                      _buildInfoRow(
                        'Плотность',
                        '${item.density.toStringAsFixed(2)} кг/м³',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    // Упаковки (множественное значение)
                    if (item.packagings.isNotEmpty) ...[
                      _buildSection('Упаковка', [
                        ...item.packagings.map(
                          (p) => _buildInfoRow(
                            p.name,
                            '\$${p.cost.toStringAsFixed(2)}',
                          ),
                        ),
                        if (item.packagings.length > 1) ...[
                          const Divider(height: 16),
                          _buildInfoRow(
                            'Всего за упаковку',
                            '\$${(item.packagings.fold<double>(0, (sum, p) => sum + p.cost) * item.placesCount).toStringAsFixed(2)}',
                          ),
                        ],
                      ]),
                      const SizedBox(height: 20),
                    ],
                    _buildSection('Стоимость', [
                      // Перевалка
                      if (item.transshipmentCost != null &&
                          item.transshipmentCost! > 0)
                        _buildInfoRow(
                          'Перевалка',
                          '\$${item.transshipmentCost!.toStringAsFixed(2)}',
                        ),
                      // Страховка
                      if (item.insuranceCost != null && item.insuranceCost! > 0)
                        _buildInfoRow(
                          'Страховка',
                          '\$${item.insuranceCost!.toStringAsFixed(2)}',
                        ),
                      // Скидка
                      if (item.discount != null && item.discount! > 0)
                        _buildInfoRow(
                          'Скидка',
                          '-\$${item.discount!.toStringAsFixed(2)}',
                        ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Доставка, \$',
                        '\$${deliveryCostUsd.toStringAsFixed(2)}',
                      ),
                      if (item.rate != null && item.rate! > 0)
                        _buildInfoRow(
                          'Курс',
                          '${item.rate!.toStringAsFixed(2)} ₽',
                        ),
                      _buildInfoRow(
                        'К оплате',
                        '${money.format(totalRub.round())} ₽',
                        isTotal: true,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    // Кнопка оплаты
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onPay,
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

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
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
                    ? const Color(0xFFfe3301)
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
