import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_pill.dart';
import '../../clients/application/client_codes_controller.dart';
import '../data/fake_invoices_repository.dart';
import '../domain/invoice_item.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _status = 'Все';
  String _query = '';

  static const List<String> _allStatuses = [
    'Все',
    'Не оплачен',
    'Оплачен',
    'Частично оплачен',
  ];

  List<InvoiceItem> _applyFilters(List<InvoiceItem> items) {
    final q = _query.trim().toLowerCase();
    return items.where((inv) {
      final statusOk = _status == 'Все' ? true : inv.status == _status;
      final queryOk = q.isEmpty
          ? true
          : inv.invoiceNumber.toLowerCase().contains(q) ||
                inv.deliveryType?.toLowerCase().contains(q) == true ||
                inv.tariffType?.toLowerCase().contains(q) == true;
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
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить счета',
        message: e.toString(),
      ),
      data: (items) {
        final filtered = _applyFilters(items);

        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            topPad * 0.7 + 6,
            16,
            bottomPad + 16,
          ),
          children: [
            Text(
              'Счета',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
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
                status: _status,
                statuses: _allStatuses,
                query: _query,
                onStatusChanged: (v) => setState(() => _status = v),
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
                  child: _InvoiceTile(
                    item: inv,
                    clientCode: clientCode,
                    clientName: 'Клиент $clientCode',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Filters extends StatefulWidget {
  final String status;
  final List<String> statuses;
  final String query;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onQueryChanged;

  const _Filters({
    required this.status,
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
        _CustomDropdown<String>(
          value: widget.status,
          label: 'Статус',
          items: widget.statuses
              .map((s) => _DropdownItem(value: s, label: s))
              .toList(),
          onChanged: (v) => v != null ? widget.onStatusChanged(v) : null,
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
    final selectedLabel = widget.items
        .firstWhere(
          (item) => item.value == _selectedValue,
          orElse: () => _DropdownItem(value: _selectedValue, label: 'N/A'),
        )
        .label;

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
  final String clientName;

  const _InvoiceTile({
    required this.item,
    required this.clientCode,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    final money = NumberFormat.decimalPattern('ru');

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
                StatusPill(text: item.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              df.format(item.sendDate),
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 4),
            Text(
              '${money.format(item.totalCostRub.round())} ₽',
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
                    onPressed: () => _openInvoiceSheet(context),
                    child: const Text('Открыть'),
                  ),
                ),
                if (item.status == 'Требует оплаты') ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _showPayment(context),
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

  void _openInvoiceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _InvoiceFormSheet(
        item: item,
        clientCode: clientCode,
        clientName: clientName,
        onPay: () => _showPayment(context),
      ),
    );
  }

  void _showPayment(BuildContext context) {
    final money = NumberFormat.decimalPattern('ru');

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Оплата счёта',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 16),
                Text(
                  'Счёт: ${item.invoiceNumber}',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  'Сумма к оплате: ${money.format(item.totalCostRub.round())} ₽',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFfe3301),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Функция оплаты в разработке'),
                      ),
                    );
                  },
                  child: const Text('Перейти к оплате'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InvoiceFormSheet extends StatefulWidget {
  final InvoiceItem item;
  final String clientCode;
  final String clientName;
  final VoidCallback onPay;

  const _InvoiceFormSheet({
    required this.item,
    required this.clientCode,
    required this.clientName,
    required this.onPay,
  });

  @override
  State<_InvoiceFormSheet> createState() => _InvoiceFormSheetState();
}

class _InvoiceFormSheetState extends State<_InvoiceFormSheet> {
  late final TextEditingController _numberCtrl;
  late final TextEditingController _clientCodeCtrl;
  late final TextEditingController _clientNameCtrl;
  late final TextEditingController _tariffCostCtrl;
  late final TextEditingController _insuranceCtrl;
  late final TextEditingController _uvCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _deliveryCostCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _volumeCtrl;

  late String _tariffType;
  late String _deliveryType;
  late DateTime _sendDate;
  late int _placesCount;
  late double _weight;
  late double _volume;
  late bool _calcByDensity;
  double _packagingCost = 0;
  final Set<String> _selectedPackaging = <String>{};

  double _totalUsd = 0;
  double _totalRub = 0;

  static const List<String> _tariffOptions = <String>[
    'Спец. тариф',
    'Сборный груз',
    'Крупный ОПТ',
  ];

  static const List<String> _deliveryOptions = <String>[
    'Авто',
    'Авиа',
    'Ж/Д',
  ];

  static const List<_PackagingOption> _packagingCatalog = <_PackagingOption>[
    _PackagingOption(label: 'Коробка', price: 3.5),
    _PackagingOption(label: 'Картонные уголки', price: 2.2),
    _PackagingOption(label: 'Пузырчатая пленка', price: 1.8),
    _PackagingOption(label: 'Деревянная обрешетка', price: 9.0),
    _PackagingOption(label: 'Паллет', price: 12.0),
  ];

  @override
  void initState() {
    super.initState();
    _numberCtrl = TextEditingController(text: widget.item.invoiceNumber);
    _clientCodeCtrl = TextEditingController(text: widget.clientCode);
    _clientNameCtrl = TextEditingController(text: widget.clientName);

    _tariffType = widget.item.tariffType ?? _tariffOptions.first;
    _deliveryType = widget.item.deliveryType ?? _deliveryOptions.first;
    _sendDate = widget.item.sendDate;
    _placesCount = widget.item.placesCount;
    _weight = widget.item.weight;
    _volume = widget.item.volume;
    _calcByDensity = true;

    final guessedDeliveryCost = (widget.item.totalCostUsd ?? 0) -
        (widget.item.tariffCost ?? 0) -
        (widget.item.insuranceCost ?? 0) -
        (widget.item.packagingCost ?? 0) -
        (widget.item.uvCost ?? 0);

    _tariffCostCtrl = TextEditingController(
      text: _format(widget.item.tariffCost ?? 0),
    );
    _insuranceCtrl = TextEditingController(
      text: _format(widget.item.insuranceCost ?? 0),
    );
    _uvCtrl = TextEditingController(
      text: _format(widget.item.uvCost ?? 0),
    );
    _discountCtrl = TextEditingController(text: '0');
    _deliveryCostCtrl = TextEditingController(
      text: _format(guessedDeliveryCost.clamp(0, double.infinity)),
    );
    _rateCtrl = TextEditingController(
      text: _format(widget.item.rate ?? 95),
    );
    _weightCtrl = TextEditingController(text: _format(_weight));
    _volumeCtrl = TextEditingController(text: _format(_volume));

    for (final p in widget.item.packagingTypes) {
      _selectedPackaging.add(p);
    }
    _recalcPackaging();
    _recalcTotals();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _clientCodeCtrl.dispose();
    _clientNameCtrl.dispose();
    _tariffCostCtrl.dispose();
    _insuranceCtrl.dispose();
    _uvCtrl.dispose();
    _discountCtrl.dispose();
    _deliveryCostCtrl.dispose();
    _rateCtrl.dispose();
    _weightCtrl.dispose();
    _volumeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = _volume <= 0 ? 0.0 : _weight / _volume;
    final topPadding = MediaQuery.of(context).viewPadding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            margin: EdgeInsets.only(top: topPadding + 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Счёт',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  _twoColumns(
                    _buildField('Номер', _numberCtrl, textInputAction: TextInputAction.next),
                    _buildField('Код клиента', _clientCodeCtrl, enabled: false),
                  ),
                  const SizedBox(height: 10),
                  _buildField('Клиент', _clientNameCtrl, enabled: false),
                  const SizedBox(height: 14),
                  _twoColumns(
                    _dropdown(
                      label: 'Тариф',
                      value: _tariffType,
                      items: _tariffOptions,
                      onChanged: (v) => setState(() => _tariffType = v),
                    ),
                    _dropdown(
                      label: 'Тип доставки',
                      value: _deliveryType,
                      items: _deliveryOptions,
                      onChanged: (v) => setState(() => _deliveryType = v),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _twoColumns(
                    _buildNumberField('Стоимость тарифа, \$', _tariffCostCtrl),
                    _buildDateField(context),
                  ),
                  const SizedBox(height: 14),
                  _twoColumns(
                    _buildStepper('Кол-во мест', _placesCount, (v) {
                      setState(() => _placesCount = v);
                      _recalcTotals();
                    }),
                    _buildToggle(),
                  ),
                  const SizedBox(height: 12),
                  _twoColumns(
                    _buildNumberField('Вес, кг', _weightCtrl, onChanged: () {
                      _weight = _parse(_weightCtrl.text);
                      _autoDeliveryCost();
                      _recalcTotals();
                    }),
                    _buildNumberField('Объём, м³', _volumeCtrl, onChanged: () {
                      _volume = _parse(_volumeCtrl.text);
                      _autoDeliveryCost();
                      _recalcTotals();
                    }),
                  ),
                  const SizedBox(height: 10),
                  _infoRow('Плотность', '${density.toStringAsFixed(2)} кг/м³'),
                  const SizedBox(height: 18),
                  const Text('Упаковка (множественный выбор)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _packagingCatalog.map((p) {
                      final selected = _selectedPackaging.contains(p.label);
                      return FilterChip(
                        label: Text('${p.label} • ${_format(p.price)}\$'),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            v ? _selectedPackaging.add(p.label) : _selectedPackaging.remove(p.label);
                            _recalcPackaging();
                            _recalcTotals();
                          });
                        },
                        selectedColor: const Color(0x1Afe3301),
                        checkmarkColor: const Color(0xFFfe3301),
                        labelStyle: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? const Color(0xFFfe3301) : Colors.black87,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  _infoRow('Стоимость упаковки', '${_format(_packagingCost)} \$'),
                  const SizedBox(height: 18),
                  const Text('Стоимость и доп. услуги', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _twoColumns(
                    _buildNumberField('Стоимость доставки, \$', _deliveryCostCtrl, onChanged: _recalcTotals),
                    _buildNumberField('Страховка, \$', _insuranceCtrl, onChanged: _recalcTotals),
                  ),
                  const SizedBox(height: 12),
                  _twoColumns(
                    _buildNumberField('Перевалка, \$', _uvCtrl, onChanged: _recalcTotals),
                    _buildNumberField('Скидка, \$', _discountCtrl, onChanged: _recalcTotals),
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField('Курс USD → RUB', _rateCtrl, onChanged: _recalcTotals),
                  const SizedBox(height: 18),
                  _infoRow('Итог, \$', '${_format(_totalUsd)} \$'),
                  _infoRow('К оплате, ₽', NumberFormat.decimalPattern('ru').format(_totalRub.round())),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Счёт сохранён (черновик)')),
                            );
                          },
                          child: const Text('Сохранить'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onPay();
                          },
                          child: const Text('Оплатить'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool enabled = true, TextInputAction? textInputAction}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      textInputAction: textInputAction,
      decoration: _inputDecoration(label),
    );
  }

  Widget _buildNumberField(String label, TextEditingController ctrl, {VoidCallback? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
      decoration: _inputDecoration(label),
      onChanged: (_) => onChanged?.call(),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
    );
  }

  Widget _buildDateField(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _sendDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => _sendDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: _boxDecoration(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Дата отправки', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                const SizedBox(height: 2),
                Text(df.format(_sendDate), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const Icon(Icons.calendar_month_rounded, color: Color(0xFFfe3301)),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({required String label, required String value, required List<String> items, required ValueChanged<String> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: _boxDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFfe3301)),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: items
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildStepper(String label, int value, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: _boxDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              const SizedBox(height: 2),
              Text('$value', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: const Color(0xFFfe3301),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFFfe3301),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Расчёт доставки', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('По плотности'),
                selected: _calcByDensity,
                selectedColor: const Color(0x1Afe3301),
                labelStyle: TextStyle(
                  color: _calcByDensity ? const Color(0xFFfe3301) : Colors.black87,
                  fontWeight: _calcByDensity ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (v) {
                  setState(() => _calcByDensity = true);
                  _autoDeliveryCost();
                  _recalcTotals();
                },
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('По весу'),
                selected: !_calcByDensity,
                selectedColor: const Color(0x1Afe3301),
                labelStyle: TextStyle(
                  color: !_calcByDensity ? const Color(0xFFfe3301) : Colors.black87,
                  fontWeight: !_calcByDensity ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (v) {
                  setState(() => _calcByDensity = false);
                  _autoDeliveryCost();
                  _recalcTotals();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF666666))),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _twoColumns(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFfe3301), width: 1.3),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    );
  }

  double _parse(String text) {
    final normalized = text.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  String _format(double value) {
    return value.toStringAsFixed(2);
  }

  void _recalcPackaging() {
    _packagingCost = _packagingCatalog
        .where((p) => _selectedPackaging.contains(p.label))
        .fold(0.0, (sum, p) => sum + p.price);
  }

  void _autoDeliveryCost() {
    final measure = _calcByDensity
        ? (_volume > 0 ? _weight / _volume : 0)
        : _weight;
    final suggested = (measure * 2.5).clamp(0.0, double.infinity);
    _deliveryCostCtrl.text = _format(suggested);
  }

  void _recalcTotals() {
    final tariff = _parse(_tariffCostCtrl.text);
    final delivery = _parse(_deliveryCostCtrl.text);
    final insurance = _parse(_insuranceCtrl.text);
    final uv = _parse(_uvCtrl.text);
    final discount = _parse(_discountCtrl.text);
    final rate = _parse(_rateCtrl.text);

    final subtotal = tariff + delivery + insurance + uv + _packagingCost;
    _totalUsd = (subtotal - discount).clamp(0, double.infinity);
    _totalRub = (_totalUsd * rate).clamp(0, double.infinity);
    setState(() {});
  }
}

class _PackagingOption {
  final String label;
  final double price;

  const _PackagingOption({required this.label, required this.price});
}
