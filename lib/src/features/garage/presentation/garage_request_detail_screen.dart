import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_toast.dart';
import '../application/garage_providers.dart';
import '../domain/garage_models.dart';
import 'garage_conversation_card.dart';
import 'garage_invoice_card.dart';
import 'garage_media_image.dart';
import 'garage_order_composition_card.dart';
import 'garage_payment_sheet.dart';
import 'garage_translated_text.dart';
import 'garage_ui.dart';

class GarageRequestDetailScreen extends ConsumerStatefulWidget {
  final int requestId;

  const GarageRequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<GarageRequestDetailScreen> createState() =>
      _GarageRequestDetailScreenState();
}

class _GarageRequestDetailScreenState
    extends ConsumerState<GarageRequestDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _selections = <int, GarageOfferSelection>{};
  int? _selectionOfferId;
  GarageOfferCalculation? _calculation;
  Timer? _calculationDebounce;
  int _calculationRevision = 0;
  bool _calculating = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _calculationDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(garageRequestProvider(widget.requestId));
    await ref.read(garageRequestProvider(widget.requestId).future);
  }

  void _prepareSelections(GarageRequest request) {
    final offer = request.currentOffer;
    if (offer == null || offer.id == _selectionOfferId) return;
    _calculationDebounce?.cancel();
    _calculationRevision++;
    _selectionOfferId = offer.id;
    _selections.clear();
    for (final item in request.order?.items ?? const <GarageOrderItem>[]) {
      if (item.selectedOptionId <= 0) continue;
      _selections[item.selectedOptionId] = GarageOfferSelection(
        requestItemId: item.requestItemId,
        optionId: item.selectedOptionId,
        quantity: item.quantity,
      );
    }
    _calculation = null;
    _calculating = false;
  }

  void _scheduleCalculation(GarageRequest request) {
    _calculationDebounce?.cancel();
    final revision = ++_calculationRevision;
    setState(() {
      _calculation = null;
      _calculating = false;
    });
    final offer = request.currentOffer;
    if (offer == null || !_selectionValid(offer)) return;
    _calculationDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _calculate(request, revision: revision),
    );
  }

  Future<GarageOfferCalculation?> _calculate(
    GarageRequest request, {
    int? revision,
    bool showError = false,
  }) async {
    final offer = request.currentOffer;
    if (offer == null || _working) return null;
    if (!_selectionValid(offer)) {
      if (showError) {
        _show('Выберите хотя бы одну запчасть', error: true);
      }
      return null;
    }
    _calculationDebounce?.cancel();
    final activeRevision = revision ?? ++_calculationRevision;
    final selections = _selections.values.toList(growable: false);
    setState(() => _calculating = true);
    try {
      final calculation = await ref
          .read(garageRepositoryProvider)
          .calculateOffer(request.id, offer.id, selections);
      if (!mounted || activeRevision != _calculationRevision) return null;
      setState(() {
        _calculation = calculation;
        _calculating = false;
      });
      return calculation;
    } catch (_) {
      if (!mounted || activeRevision != _calculationRevision) return null;
      setState(() => _calculating = false);
      if (showError) {
        _show('Не удалось рассчитать предложение', error: true);
      }
      return null;
    }
  }

  bool _selectionValid(GarageOffer offer) {
    if (_selections.isEmpty) return false;
    return _selections.values.every(
      (selection) =>
          selection.quantity > 0 &&
          selection.quantity <= 999 &&
          offer
              .optionsFor(selection.requestItemId)
              .any((option) => option.id == selection.optionId),
    );
  }

  Future<void> _accept(GarageRequest request) async {
    final offer = request.currentOffer;
    if (offer == null || _working) return;
    if (_calculation == null) {
      final calculation = await _calculate(request, showError: true);
      if (!mounted || calculation == null) return;
    }
    setState(() => _working = true);
    try {
      final repository = ref.read(garageRepositoryProvider);
      final selections = _selections.values.toList(growable: false);
      late final GarageOrder order;
      if (request.order == null) {
        final accepted = await repository.acceptOffer(
          request.id,
          offer.id,
          selections,
          idempotencyKey: const Uuid().v4(),
        );
        order = accepted.order;
      } else {
        order = await repository.updateOrderSelection(
          request.order!.id,
          selections,
        );
      }
      if (!mounted) return;
      ref.invalidate(garageRequestProvider(request.id));
      ref.invalidate(garageRequestsProvider);
      ref.invalidate(garageOrdersProvider);
      setState(() => _working = false);
      final sent = await showGaragePaymentSheet(
        context: context,
        orderId: order.id,
        orderNumber: order.orderNumber,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      _tabController.animateTo(2);
      if (sent == true) {
        _show('Чек отправлен на проверку');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      _show(
        'Не удалось подтвердить предложение. Обновите страницу и проверьте срок действия.',
        error: true,
      );
    }
  }

  Future<void> _submitDraft(GarageRequest request) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await ref
          .read(garageRepositoryProvider)
          .submitRequest(request.id, idempotencyKey: const Uuid().v4());
      if (!mounted) return;
      ref.invalidate(garageRequestProvider(request.id));
      ref.invalidate(garageRequestsProvider);
      setState(() => _working = false);
      _show('Заявка отправлена');
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      _show('Не удалось отправить заявку', error: true);
    }
  }

  Future<void> _editDraft(GarageRequest request) async {
    await context.push('/garage/requests/${request.id}/edit');
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _cancel(GarageRequest request) async {
    if (_working) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Отменить заявку?'),
            content: const Text(
              'После отмены предложение станет недоступно. История сохранится.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Назад'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Отменить заявку'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      await ref.read(garageRepositoryProvider).cancelRequest(request.id);
      if (!mounted) return;
      ref.invalidate(garageRequestProvider(request.id));
      ref.invalidate(garageRequestsProvider);
      setState(() => _working = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      _show('Не удалось отменить заявку', error: true);
    }
  }

  Future<void> _clone(GarageRequest request) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final clone = await ref
          .read(garageRepositoryProvider)
          .cloneRequest(request.id, idempotencyKey: const Uuid().v4());
      if (!mounted) return;
      ref.invalidate(garageRequestsProvider);
      context.go('/garage/requests/${clone.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      _show('Не удалось создать копию заявки', error: true);
    }
  }

  void _show(String message, {bool error = false}) {
    AppToast.show(context, message, isError: error);
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(garageRequestProvider(widget.requestId));
    final requestStatuses =
        ref.watch(garageRequestStatusesProvider).asData?.value ??
        const <GarageRequestStatusDefinition>[];
    final top = AppLayout.topBarTotalHeight(context);
    final bottom = AppLayout.bottomScrollPadding(context);
    return request.when(
      loading: () => ListView(
        padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 26),
        children: const [
          GaragePageHeader(title: 'Заявка Гаража'),
          SizedBox(height: 12),
          GarageCard(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      error: (error, _) => ListView(
        padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 26),
        children: [
          const GaragePageHeader(title: 'Заявка Гаража'),
          const SizedBox(height: 12),
          GarageEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Заявка не загрузилась',
            subtitle: 'Ссылка могла устареть или соединение прервалось.',
            action: GarageSecondaryButton(
              label: 'Повторить',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(garageRequestProvider(widget.requestId)),
            ),
          ),
        ],
      ),
      data: (value) {
        _prepareSelections(value);
        return Padding(
          padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, 0),
          child: Column(
            children: [
              const GaragePageHeader(title: 'Заявка Гаража'),
              const SizedBox(height: 12),
              _detailTabs(),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _tabBody(
                      bottom: bottom,
                      children: [
                        _summary(value, requestStatuses),
                        const SizedBox(height: 12),
                        _vehicle(value),
                        const SizedBox(height: 14),
                        _actions(value),
                      ],
                    ),
                    _tabBody(
                      bottom: bottom,
                      children: [
                        _items(value),
                        if (value.currentOffer != null) ...[
                          const SizedBox(height: 12),
                          _offer(value, value.currentOffer!),
                        ],
                      ],
                    ),
                    _tabBody(
                      bottom: bottom,
                      children: [
                        if (value.order == null)
                          const GarageEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Счёт ещё не сформирован',
                            subtitle:
                                'Он появится после выбора запчастей и подтверждения покупки.',
                          )
                        else
                          _invoice(value.order!),
                      ],
                    ),
                    _tabBody(
                      bottom: bottom,
                      children: [
                        if (value.order == null)
                          const GarageEmptyState(
                            icon: Icons.shopping_bag_outlined,
                            title: 'Состав заказа пока пуст',
                            subtitle:
                                'Выбранные запчасти появятся здесь после подтверждения покупки.',
                          )
                        else
                          GarageOrderCompositionCard(order: value.order!),
                      ],
                    ),
                    _tabBody(
                      bottom: bottom,
                      children: [GarageConversationCard(request: value)],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailTabs() {
    const tabs = ['Обзор', 'Запчасти', 'Счёт', 'Состав заказа', 'Общение'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                spreadRadius: -12,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: compact,
            tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: EdgeInsets.symmetric(horizontal: compact ? 16 : 6),
            indicator: BoxDecoration(
              gradient: context.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            tabs: [for (final label in tabs) Tab(text: label)],
          ),
        );
      },
    );
  }

  Widget _tabBody({required double bottom, required List<Widget> children}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: context.brandPrimary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 4, 0, bottom + 26),
        children: children,
      ),
    );
  }

  Widget _invoice(GarageOrder order) {
    final embedded = order.invoice;
    if (embedded != null) {
      return GarageInvoiceCard(
        invoice: embedded,
        order: order,
        onPay: _canPayGarageOrder(order, embedded)
            ? () => _payOrder(order)
            : null,
      );
    }
    final invoice = ref.watch(garageInvoiceProvider(order.id));
    return invoice.when(
      loading: () =>
          const GarageCard(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => const GarageCard(
        child: Text(
          'Счёт ещё формируется',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      data: (value) => GarageInvoiceCard(
        invoice: value,
        order: order,
        onPay: _canPayGarageOrder(order, value) ? () => _payOrder(order) : null,
      ),
    );
  }

  Future<void> _payOrder(GarageOrder order) async {
    final sent = await showGaragePaymentSheet(
      context: context,
      orderId: order.id,
      orderNumber: order.orderNumber,
    );
    if (!mounted || sent != true) return;
    _show('Чек отправлен на проверку');
    await _refresh();
  }

  Widget _summary(
    GarageRequest request,
    List<GarageRequestStatusDefinition> requestStatuses,
  ) {
    final status = canonicalGarageRequestStatus(
      request.status,
      order: request.order,
    );
    return GarageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.requestNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GarageStatusChip(
                status: status,
                definition: garageRequestStatusDefinition(
                  requestStatuses,
                  status,
                ),
              ),
            ],
          ),
          if (request.clientComment != null) ...[
            const SizedBox(height: 12),
            Text(
              request.clientComment!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _RequestProgress(status: status, statuses: requestStatuses),
        ],
      ),
    );
  }

  Widget _vehicle(GarageRequest request) {
    final snapshot = request.vehicleSnapshot ?? const <String, dynamic>{};
    final title = [
      snapshot['make'],
      snapshot['model'],
      snapshot['modelYear'],
    ].where((value) => value != null).join(' ');
    return GarageCard(
      child: Row(
        children: [
          Icon(
            Icons.directions_car_filled_rounded,
            color: context.brandPrimary,
            size: 30,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Автомобиль',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title.isEmpty ? 'Автомобиль #${request.vehicleId}' : title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _items(GarageRequest request) {
    return GarageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Позиции · ${request.items.length}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < request.items.length; index++) ...[
            _RequestItemRow(item: request.items[index]),
            if (index != request.items.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _offer(GarageRequest request, GarageOffer offer) {
    final existingOrder = request.order;
    final editable = existingOrder == null
        ? offer.status == 'published' && !offer.isExpired
        : _canEditGarageOrderSelection(existingOrder);
    return GarageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Предложение по запчастям',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (offer.validUntil != null) ...[
            const SizedBox(height: 5),
            Text(
              'Действует до ${_dateTime(offer.validUntil!)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final item in request.items) ...[
            Text(
              item.partName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            if (offer.optionsFor(item.id).isEmpty)
              const Text(
                'Варианты ещё не добавлены',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              Column(
                children: [
                  for (final option in offer.optionsFor(item.id))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GarageOptionChoiceCard(
                        option: option,
                        selected: _selections.containsKey(option.id),
                        quantity: _selections[option.id]?.quantity ?? 1,
                        enabled: editable && !_working,
                        onChanged: (selected) {
                          setState(() {
                            if (selected) {
                              _selections[option.id] = GarageOfferSelection(
                                requestItemId: item.id,
                                optionId: option.id,
                                quantity: 1,
                              );
                            } else {
                              _selections.remove(option.id);
                            }
                          });
                          _scheduleCalculation(request);
                        },
                        onQuantityChanged: (quantity) {
                          final current = _selections[option.id];
                          if (current == null) return;
                          setState(() {
                            _selections[option.id] = current.copyWith(
                              quantity: quantity,
                            );
                          });
                          _scheduleCalculation(request);
                        },
                      ),
                    ),
                ],
              ),
            const Divider(height: 22),
          ],
          if (_calculation != null) ...[
            GarageInfoRow(
              label: 'Товары',
              value: garageMoney(_calculation!.goodsTotalCny, '¥'),
            ),
            GarageInfoRow(
              label: 'Доставка по Китаю',
              value: garageMoney(_calculation!.chinaDeliveryTotalCny, '¥'),
            ),
            if (_calculation!.discountCny > 0)
              GarageInfoRow(
                label: 'Скидка',
                value: '-${garageMoney(_calculation!.discountCny, '¥')}',
              ),
            GarageInfoRow(
              label: 'Итого',
              value:
                  '${garageMoney(_calculation!.totalCny, '¥')} · ${garageMoney(_calculation!.totalRub, '₽')}',
              emphasized: true,
            ),
            const SizedBox(height: 12),
          ] else if (existingOrder != null) ...[
            GarageInfoRow(
              label: 'Текущая сумма заказа',
              value:
                  '${garageMoney(existingOrder.totalCny, '¥')} · ${garageMoney(existingOrder.totalRub, '₽')}',
              emphasized: true,
            ),
            const SizedBox(height: 12),
          ],
          if (_calculating) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 7),
            const Text(
              'Стоимость обновляется автоматически…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (editable) ...[
            GaragePrimaryButton(
              label: existingOrder == null
                  ? 'Купить выбранное'
                  : 'Сохранить и перейти к оплате',
              icon: Icons.shopping_cart_checkout_rounded,
              onPressed: () => _accept(request),
              loading: _working,
            ),
          ] else if (existingOrder != null)
            const Text(
              'Состав и количество зафиксированы после отправки оплаты.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(GarageRequest request) {
    final status = canonicalGarageRequestStatus(
      request.status,
      order: request.order,
    );
    final canCancel = {
      'draft',
      'new',
      'in_progress',
      'pending_confirmation',
    }.contains(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == 'draft') ...[
          GarageSecondaryButton(
            label: 'Редактировать черновик',
            icon: Icons.edit_outlined,
            onPressed: _working ? null : () => _editDraft(request),
          ),
          const SizedBox(height: 10),
          GaragePrimaryButton(
            label: 'Отправить заявку',
            icon: Icons.send_rounded,
            onPressed: request.items.isEmpty
                ? null
                : () => _submitDraft(request),
            loading: _working,
          ),
          const SizedBox(height: 10),
        ],
        if (canCancel)
          GarageSecondaryButton(
            label: 'Отменить заявку',
            icon: Icons.cancel_outlined,
            color: Colors.redAccent,
            onPressed: _working ? null : () => _cancel(request),
          ),
        if (request.status == 'cancelled' ||
            request.status == 'converted_to_order' ||
            status == 'paid') ...[
          GarageSecondaryButton(
            label: 'Создать новую на основе этой',
            icon: Icons.copy_rounded,
            onPressed: _working ? null : () => _clone(request),
          ),
        ],
      ],
    );
  }
}

class _GarageOptionChoiceCard extends StatelessWidget {
  final GaragePartOption option;
  final bool selected;
  final int quantity;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final ValueChanged<int> onQuantityChanged;

  const _GarageOptionChoiceCard({
    required this.option,
    required this.selected,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = '${option.manufacturer} ${option.partNumber}'.trim();
    final translatedTitle = option.manufacturerRu?.trim().isNotEmpty == true
        ? '${option.manufacturerRu!.trim()} ${option.partNumber}'.trim()
        : null;
    return Material(
      color: selected
          ? context.brandPrimary.withValues(alpha: 0.08)
          : const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? () => onChanged(!selected) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? context.brandPrimary : const Color(0xFFE4E7EC),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (option.imageUrls.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: GarageImageStrip(
                    imagePaths: option.imageUrls,
                    keyPrefix: 'garage-option-${option.id}',
                    fallbackFileNamePrefix: 'garage-option-${option.id}',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    key: ValueKey('garage-option-${option.id}-checkbox'),
                    value: selected,
                    onChanged: enabled
                        ? (value) => onChanged(value ?? false)
                        : null,
                    activeColor: context.brandPrimary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GarageTranslatedText(
                          title.isEmpty ? 'Вариант запчасти' : title,
                          translatedText: translatedTitle,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Gilroy',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (option.displayDescription != null) ...[
                          const SizedBox(height: 4),
                          GarageTranslatedText(
                            option.description ?? option.displayDescription!,
                            translatedText: option.descriptionRu,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'Gilroy',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (option.displayEmployeeComment != null) ...[
                          const SizedBox(height: 5),
                          GarageTranslatedText(
                            option.employeeComment ??
                                option.displayEmployeeComment!,
                            translatedText: option.employeeCommentRu,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'Gilroy',
                              fontSize: 12.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Text(
                          garageMoney(option.clientUnitPriceRub, '₽'),
                          style: TextStyle(
                            color: context.brandPrimary,
                            fontFamily: 'Gilroy',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${garageMoney(option.clientUnitPriceCny, '¥')} · ${_optionTypeLabel(option.optionType)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Gilroy',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                'Количество',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Gilroy',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              _GarageQuantityControls(
                                optionId: option.id,
                                quantity: quantity,
                                enabled: enabled,
                                onChanged: onQuantityChanged,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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

class _GarageQuantityControls extends StatelessWidget {
  final int optionId;
  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _GarageQuantityControls({
    required this.optionId,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrease = enabled && quantity > 1;
    final canIncrease = enabled && quantity < 999;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _quantityButton(
          key: ValueKey('garage-option-$optionId-minus'),
          icon: Icons.remove_rounded,
          enabled: canDecrease,
          onTap: () => onChanged(quantity - 1),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '$quantity',
            key: ValueKey('garage-option-$optionId-quantity'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _quantityButton(
          key: ValueKey('garage-option-$optionId-plus'),
          icon: Icons.add_rounded,
          enabled: canIncrease,
          onTap: () => onChanged(quantity + 1),
        ),
      ],
    );
  }

  Widget _quantityButton({
    required Key key,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE9EDF2) : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? AppColors.textPrimary : const Color(0xFFB6BDC8),
        ),
      ),
    );
  }
}

bool _canEditGarageOrderSelection(GarageOrder order) {
  return order.status == 'awaiting_payment' &&
      order.paidAt == null &&
      order.invoice?.status == 'unpaid' &&
      order.invoice?.paidAt == null;
}

bool _canPayGarageOrder(GarageOrder order, GarageInvoice invoice) {
  return order.status == 'awaiting_payment' &&
      {'unpaid', 'awaiting_payment'}.contains(invoice.status);
}

class _RequestItemRow extends StatelessWidget {
  final GarageRequestItem item;

  const _RequestItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${item.orderNumber}',
            style: TextStyle(
              color: context.brandPrimary,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.partName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.partNumber} · ${item.quantity} шт. · ${_preference(item.preference)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestProgress extends StatelessWidget {
  final String status;
  final List<GarageRequestStatusDefinition> statuses;

  const _RequestProgress({required this.status, required this.statuses});

  @override
  Widget build(BuildContext context) {
    final definitions = statuses.isEmpty
        ? canonicalGarageRequestStatusOrder
              .map(
                (code) => GarageRequestStatusDefinition(
                  code: code,
                  nameRu: garageStatusLabel(code),
                  color: null,
                  sortOrder: canonicalGarageRequestStatusOrder.indexOf(code),
                ),
              )
              .toList(growable: false)
        : statuses;
    final index = definitions.indexWhere(
      (definition) => definition.code == status,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var position = 0; position < definitions.length; position++) ...[
            SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: position <= index
                          ? context.brandPrimary
                          : const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    definitions[position].nameRu,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: position <= index
                          ? context.brandPrimary
                          : AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: position == index
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (position != definitions.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

String _preference(GaragePartPreference preference) {
  return switch (preference) {
    GaragePartPreference.original => 'оригинал',
    GaragePartPreference.analog => 'аналог',
    GaragePartPreference.any => 'любой',
    GaragePartPreference.unknown => 'не указано',
  };
}

String _optionTypeLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'original' => 'оригинал',
    'analog' || 'analogue' => 'аналог',
    'used' => 'б/у',
    'oem' => 'OEM',
    final normalized when normalized.isNotEmpty => normalized,
    _ => 'тип не указан',
  };
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}
