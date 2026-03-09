// ignore_for_file: deprecated_member_use
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_config.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../photos/domain/photo_item.dart';
import '../../photos/presentation/photo_viewer_screen.dart';
import '../data/sp_models.dart';
import '../data/sp_provider.dart';

/// Показывает стилизованный SnackBar в едином дизайне приложения
void _showStyledSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => messenger.hideCurrentSnackBar(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFE53935) : context.brandPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
      duration: const Duration(seconds: 3),
    ),
  );
}

class SpTrackEditScreen extends ConsumerStatefulWidget {
  final int trackId;
  final int assemblyId;

  const SpTrackEditScreen({
    super.key,
    required this.trackId,
    required this.assemblyId,
  });

  @override
  ConsumerState<SpTrackEditScreen> createState() => _SpTrackEditScreenState();
}

class _SpTrackEditScreenState extends ConsumerState<SpTrackEditScreen> {
  late TextEditingController _participantController;
  late TextEditingController _supplierPriceController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _purchaseRateController;
  late TextEditingController _clientPriceController;
  late TextEditingController _netWeightController;
  late TextEditingController _additionalExpensesController;
  late TextEditingController _noteController;

  SpTrack? _track;
  SpAssembly? _assembly;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _participantController = TextEditingController();
    _supplierPriceController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _purchaseRateController = TextEditingController();
    _clientPriceController = TextEditingController();
    _netWeightController = TextEditingController();
    _additionalExpensesController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _participantController.dispose();
    _supplierPriceController.dispose();
    _purchasePriceController.dispose();
    _purchaseRateController.dispose();
    _clientPriceController.dispose();
    _netWeightController.dispose();
    _additionalExpensesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _loadTrack() {
    final state = ref.read(spAssembliesControllerProvider);
    final assembly = state.assemblies.firstWhere(
      (a) => a.id == widget.assemblyId,
      orElse: () => throw Exception('Assembly not found'),
    );

    final track = assembly.tracks.firstWhere(
      (t) => t.id == widget.trackId,
      orElse: () => throw Exception('Track not found'),
    );

    setState(() {
      _track = track;
      _assembly = assembly;
      _participantController.text = track.spParticipantName ?? '';
      _supplierPriceController.text = track.supplierPriceYuan?.toStringAsFixed(2) ?? '';
      _purchasePriceController.text = track.purchasePriceYuan?.toStringAsFixed(2) ?? '';
      _purchaseRateController.text = track.purchaseRate?.toStringAsFixed(4) ?? '';
      _clientPriceController.text = track.clientPriceYuan?.toStringAsFixed(2) ?? '';
      _netWeightController.text = track.netWeightKg?.toStringAsFixed(3) ?? '';
      _additionalExpensesController.text = track.additionalExpensesRub?.toStringAsFixed(2) ?? '';
      _noteController.text = track.note ?? '';
    });
  }

  /// Рассчитывает стоимость доставки для трека автоматически
  /// Формула: netWeight × (totalDeliveryCost / totalNetWeight)
  double? _calculateShippingCost() {
    if (_assembly == null) return null;

    // Текущий вес трека (из поля ввода)
    final currentNetWeight = double.tryParse(_netWeightController.text);
    if (currentNetWeight == null || currentNetWeight <= 0) return null;

    // Проверяем, что у всех треков заполнен чистый вес
    bool allTracksHaveWeight = true;
    double totalNetWeight = 0;

    for (final track in _assembly!.tracks) {
      double? trackWeight;
      if (track.id == widget.trackId) {
        // Для текущего трека берём значение из поля ввода
        trackWeight = currentNetWeight;
      } else {
        trackWeight = track.netWeightKg;
      }

      if (trackWeight == null || trackWeight <= 0) {
        allTracksHaveWeight = false;
        break;
      }
      totalNetWeight += trackWeight;
    }

    if (!allTracksHaveWeight || totalNetWeight <= 0) return null;

    // Общая стоимость доставки сборки
    // Сначала берём totalShippingCostRub, если нет - считаем из счетов
    double totalDeliveryCost = _assembly!.totalShippingCostRub ?? 0;
    if (totalDeliveryCost == 0 && _assembly!.invoices.isNotEmpty) {
      for (final invoice in _assembly!.invoices) {
        totalDeliveryCost += invoice.deliveryCostRub;
      }
    }

    if (totalDeliveryCost <= 0) return null;

    // Стоимость за кг
    final costPerKg = totalDeliveryCost / totalNetWeight;

    // Стоимость доставки для данного трека
    return currentNetWeight * costPerKg;
  }

  // Цена поставщика (руб) = цена поставщика (юань) × курс
  double? _calculateSupplierPriceRub() {
    final supplierPriceYuan = double.tryParse(_supplierPriceController.text);
    final rate = double.tryParse(_purchaseRateController.text);

    if (supplierPriceYuan != null && rate != null) {
      return supplierPriceYuan * rate;
    }
    return null;
  }

  // Себестоимость = цена выкупа × курс
  double? _calculateCostPrice() {
    final purchasePrice = double.tryParse(_purchasePriceController.text);
    final rate = double.tryParse(_purchaseRateController.text);

    if (purchasePrice != null && rate != null) {
      return purchasePrice * rate;
    }
    return null;
  }

  // Цена для участника (руб) = цена участника (юань) × курс
  double? _calculateClientPriceRub() {
    final clientPriceYuan = double.tryParse(_clientPriceController.text);
    final rate = double.tryParse(_purchaseRateController.text);

    if (clientPriceYuan != null && rate != null) {
      return clientPriceYuan * rate;
    }
    return null;
  }

  // Итого к оплате = цена участника (руб) + доставка + дополнительные расходы
  double? _calculateTotalRub() {
    final clientPriceRub = _calculateClientPriceRub();
    // Используем авто-расчёт доставки если доступен
    final shippingCostRub = _calculateShippingCost() ?? _track?.shippingCostRub ?? 0;
    // Дополнительные расходы
    final additionalExpenses = double.tryParse(_additionalExpensesController.text) ?? 0;

    if (clientPriceRub != null) {
      return clientPriceRub + shippingCostRub + additionalExpenses;
    }
    return null;
  }

  // Получить текущую стоимость доставки (авто или сохранённую)
  double? _getShippingCost() {
    return _calculateShippingCost() ?? _track?.shippingCostRub;
  }

  // Прибыль = цена участника (руб) - себестоимость
  double? _calculateProfit() {
    final clientPriceRub = _calculateClientPriceRub();
    final costPrice = _calculateCostPrice();

    if (clientPriceRub != null && costPrice != null) {
      return clientPriceRub - costPrice;
    }
    return null;
  }

  Future<void> _saveTrack() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final update = SpTrackUpdate(
        spParticipantName: _participantController.text.isNotEmpty ? _participantController.text : null,
        supplierPriceYuan: double.tryParse(_supplierPriceController.text),
        purchasePriceYuan: double.tryParse(_purchasePriceController.text),
        purchaseRate: double.tryParse(_purchaseRateController.text),
        clientPriceYuan: double.tryParse(_clientPriceController.text),
        netWeightKg: double.tryParse(_netWeightController.text),
        additionalExpensesRub: double.tryParse(_additionalExpensesController.text),
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      );

      final success = await ref
          .read(spTrackEditControllerProvider.notifier)
          .updateTrack(widget.trackId, update);

      if (!mounted) return;

      if (success) {
        _showStyledSnackBar(context, 'Трек сохранён');
        context.pop();
      } else {
        final error = ref.read(spTrackEditControllerProvider).error;
        _showStyledSnackBar(context, error ?? 'Ошибка сохранения', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openPhotoViewer(int index) {
    if (_track?.photos == null || _track!.photos!.isEmpty) return;

    // Конвертируем SpPhoto в PhotoItem
    final photoItems = _track!.photos!.map((photo) {
      return PhotoItem(
        id: photo.id,
        url: photo.url,
        date: photo.createdAt,
        trackingNumber: _track!.trackNumber,
      );
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          item: photoItems[index],
          allPhotos: photoItems,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_track == null) {
      _loadTrack();
    }

    final supplierPriceRub = _calculateSupplierPriceRub();
    final costPrice = _calculateCostPrice();
    final clientPriceRub = _calculateClientPriceRub();
    final totalRub = _calculateTotalRub();
    final profit = _calculateProfit();

    return TutorialScreenWrapper(
      screenKey: 'sp_track_edit',
      steps: const [
        TutorialStep(
          icon: Icons.person_pin_rounded,
          title: 'Участник СП',
          description: 'Укажите имя участника, которому принадлежит этот трек. Имя отображается в расчётах сборки.',
        ),
        TutorialStep(
          icon: Icons.currency_yuan_rounded,
          title: 'Цена и вес',
          description: 'Введите стоимость товара в юанях и чистый вес. По этим данным считается доля в сборке.',
        ),
        TutorialStep(
          icon: Icons.save_rounded,
          title: 'Сохранить',
          description: 'Нажмите «Сохранить» внизу страницы — данные обновятся в сборке для всех участников.',
        ),
      ],
      child: Scaffold(
            body: _track == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    children: [
                      // Заголовок
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          _track!.trackNumber,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),

                      // 1. Имя участника
                      Builder(
                        builder: (_) {
                          final w = _buildCard(
                            title: 'Участник СП',
                            child: TextField(
                              controller: _participantController,
                              decoration: InputDecoration(
                                labelText: 'Имя участника',
                                hintText: 'Введите имя участника',
                                prefixIcon: const Icon(Icons.person_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          );
                          return w;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Комментарий (всегда показываем, редактируемый)
                      _buildCard(
                        title: 'Комментарий',
                        child: TextField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Введите комментарий к треку...',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 48),
                              child: Icon(Icons.comment_rounded),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. О товаре
                      if (_track!.productInfo != null)
                        ...[
                          _buildProductInfoSection(),
                          const SizedBox(height: 16),
                        ],

                      // 4. Фото отчёт
                      if (_track!.photos != null && _track!.photos!.isNotEmpty)
                        ...[
                          _buildPhotoSection(),
                          const SizedBox(height: 16),
                        ],

                      // 4. Вес и доставка
                      _buildWeightSection(),
                      const SizedBox(height: 16),

                      // 5-8. Цены в юанях и курс
                      Builder(
                        builder: (_) {
                          final w = _buildCard(
                          title: 'Цены в юанях',
                          child: Column(
                            children: [
                              // 5. Цена поставщика
                              TextField(
                                controller: _supplierPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Цена поставщика',
                                  hintText: '0.00',
                                  suffixText: '¥',
                                  prefixIcon: const Icon(Icons.store_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),

                              // 6. Цена выкупа
                              TextField(
                                controller: _purchasePriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Цена выкупа (со скидкой)',
                                  hintText: '0.00',
                                  suffixText: '¥',
                                  prefixIcon: const Icon(Icons.shopping_cart_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),

                              // 7. Цена участника
                              TextField(
                                controller: _clientPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Цена для участника',
                                  hintText: '0.00',
                                  suffixText: '¥',
                                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),

                              // 8. Курс юаня
                              TextField(
                                controller: _purchaseRateController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Курс юаня (¥→₽)',
                                  hintText: '0.0000',
                                  prefixIcon: const Icon(Icons.currency_exchange_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        );
                          return w;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 9-14. Расчётные цены в рублях
                      Builder(
                        builder: (_) {
                          final w = _buildCard(
                          title: 'Расчёт в рублях',
                          child: Column(
                            children: [
                              // 9. Цена поставщика (руб)
                              _buildCalculatedRow(
                                icon: Icons.store_rounded,
                                label: 'Цена поставщика',
                                value: supplierPriceRub,
                                color: Colors.grey,
                              ),

                              // 10. Цена выкупа / Себестоимость (руб)
                              _buildCalculatedRow(
                                icon: Icons.shopping_cart_rounded,
                                label: 'Себестоимость (цена выкупа)',
                                value: costPrice,
                                color: Colors.orange,
                              ),

                              // 11. Цена для участника (руб)
                              _buildCalculatedRow(
                                icon: Icons.account_balance_wallet_rounded,
                                label: 'Цена для участника',
                                value: clientPriceRub,
                                color: Colors.blue,
                              ),

                              // 12. Стоимость доставки (руб)
                              _buildCalculatedRow(
                                icon: Icons.local_shipping_rounded,
                                label: 'Стоимость доставки',
                                value: _getShippingCost(),
                                color: Colors.purple,
                              ),

                              // 12a. Дополнительные расходы (руб)
                              _buildCalculatedRow(
                                icon: Icons.add_shopping_cart_rounded,
                                label: 'Дополнительные расходы',
                                value: double.tryParse(_additionalExpensesController.text),
                                color: Colors.deepOrange,
                              ),

                              // 13. Итого к оплате (руб)
                              _buildCalculatedRow(
                                icon: Icons.receipt_long_rounded,
                                label: 'Итого к оплате',
                                value: totalRub,
                                color: Colors.teal,
                                isHighlighted: true,
                              ),

                              // 14. Прибыль (руб)
                              _buildCalculatedRow(
                                icon: profit != null && profit > 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                label: 'Прибыль',
                                value: profit,
                                color: profit != null && profit > 0 ? Colors.green : Colors.red,
                                isHighlighted: true,
                                isLast: true,
                              ),
                            ],
                          ),
                        );
                          return w;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Кнопка сохранения
                      Builder(
                        builder: (_) {
                          final w = FilledButton.icon(
                            onPressed: _isLoading ? null : _saveTrack,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(_isLoading ? 'Сохранение...' : 'Сохранить'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          );
                          return w;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
          ));
  }

  Widget _buildCard({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSection() {
    final theme = Theme.of(context);
    final netWeight = double.tryParse(_netWeightController.text);

    // Сначала пробуем рассчитать автоматически, если не получается - берём сохранённое значение
    final calculatedShipping = _calculateShippingCost();
    final shippingCost = calculatedShipping ?? _track?.shippingCostRub;
    final isAutoCalculated = calculatedShipping != null;

    // Расчёт стоимости за кг (если есть доставка и вес)
    double? costPerKg;
    if (shippingCost != null && shippingCost > 0 && netWeight != null && netWeight > 0) {
      costPerKg = shippingCost / netWeight;
    }

    // Проверяем, у скольких треков не заполнен вес
    int tracksWithoutWeight = 0;
    if (_assembly != null && calculatedShipping == null) {
      for (final track in _assembly!.tracks) {
        final trackWeight = track.id == widget.trackId
            ? netWeight
            : track.netWeightKg;
        if (trackWeight == null || trackWeight <= 0) {
          tracksWithoutWeight++;
        }
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вес и доставка',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            // Чистый вес (редактируемое поле)
            TextField(
              controller: _netWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Чистый вес (кг)',
                hintText: '0.000',
                suffixText: 'кг',
                prefixIcon: const Icon(Icons.scale_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Дополнительные расходы (редактируемое поле)
            TextField(
              controller: _additionalExpensesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Дополнительные расходы',
                hintText: '0.00',
                suffixText: '₽',
                prefixIcon: const Icon(Icons.add_shopping_cart_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
            ),

            // Стоимость доставки (если рассчитана)
            if (shippingCost != null && shippingCost > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping_rounded, color: Colors.purple.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Стоимость доставки',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              if (isAutoCalculated)
                                Text(
                                  'рассчитано автоматически',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.purple.shade400,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${shippingCost.toStringAsFixed(2)} ₽',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (costPerKg != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.price_change_rounded, color: Colors.purple.shade400, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Цена за кг',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.purple.shade600,
                              ),
                            ),
                          ),
                          Text(
                            '${costPerKg.toStringAsFixed(2)} ₽/кг',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Подсказка если доставка не рассчитана
            if (shippingCost == null || shippingCost == 0) ...[
              const SizedBox(height: 12),
              if (tracksWithoutWeight > 0)
                Text(
                  'Для расчёта доставки заполните вес у всех треков (осталось: $tracksWithoutWeight)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Text(
                  'Укажите чистый вес для расчёта стоимости доставки',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Фото отчёт',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_track!.photos!.length} фото',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _track!.photos!.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final photo = _track!.photos![index];
                  final fullUrl = ApiConfig.getMediaUrl(photo.thumbnailUrl ?? photo.url);
                  return GestureDetector(
                    onTap: () => _openPhotoViewer(index),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: fullUrl,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                        // Иконка для открытия просмотра
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.open_in_full_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите на фото для просмотра, скачивания или отправки',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfoSection() {
    final theme = Theme.of(context);
    final productInfo = _track!.productInfo!;
    final hasImage = productInfo.imageUrl != null && productInfo.imageUrl!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'О товаре',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // Название товара
            if (productInfo.title != null && productInfo.title!.isNotEmpty)
              _buildInfoRow(
                icon: Icons.label_rounded,
                label: 'Название',
                value: productInfo.title!,
              ),

            // Количество
            _buildInfoRow(
              icon: Icons.numbers_rounded,
              label: 'Количество',
              value: '${productInfo.quantity} шт.',
            ),

            // Фото товара
            if (hasImage) ...[
              const SizedBox(height: 12),
              Text(
                'Фото товара',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openProductPhotoViewer(),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: ApiConfig.getMediaUrl(productInfo.imageUrl!),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Нажмите на фото для просмотра, скачивания или отправки',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openProductPhotoViewer() {
    if (_track?.productInfo?.imageUrl == null) return;

    final photoItem = PhotoItem(
      url: _track!.productInfo!.imageUrl!,
      date: DateTime.now(),
      trackingNumber: _track!.trackNumber,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          item: photoItem,
        ),
      ),
    );
  }

  Widget _buildCalculatedRow({
    required IconData icon,
    required String label,
    required double? value,
    required Color color,
    bool isHighlighted = false,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    if (value == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isHighlighted
                ? color.withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: isHighlighted
                ? Border.all(color: color.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(2)} ₽',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                  color: isHighlighted ? color : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const SizedBox(height: 8),
      ],
    );
  }
}
