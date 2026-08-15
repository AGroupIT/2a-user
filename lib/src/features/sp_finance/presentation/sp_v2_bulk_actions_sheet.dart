import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_toast.dart';
import '../data/sp_v2_models.dart';
import '../data/sp_v2_provider.dart';
import 'sp_finance_ui.dart';

enum _BulkAction { status, customer, purchase, archive }

class SpV2BulkActionsSheet extends ConsumerStatefulWidget {
  final SpV2Purchase purchase;

  const SpV2BulkActionsSheet({super.key, required this.purchase});

  @override
  ConsumerState<SpV2BulkActionsSheet> createState() =>
      _SpV2BulkActionsSheetState();
}

class _SpV2BulkActionsSheetState extends ConsumerState<SpV2BulkActionsSheet> {
  late final Future<SpV2BulkOptions> _optionsFuture;
  final _archiveReasonController = TextEditingController();
  _BulkAction _action = _BulkAction.status;
  int _sourceCustomerId = -1;
  String? _targetStatus;
  int? _targetCustomerId;
  int? _targetPurchaseId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _optionsFuture = ref
        .read(spV2RepositoryProvider)
        .getBulkOptions(widget.purchase.id);
  }

  @override
  void dispose() {
    _archiveReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      bottom: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: FutureBuilder<SpV2BulkOptions>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _BulkLoadError(onClose: () => Navigator.of(context).pop());
            }
            final options = snapshot.data!;
            _ensureTargets(options);
            final selectedItems = _selectedItems();
            final affectedItems = _affectedItems(selectedItems);
            final canApply =
                affectedItems.isNotEmpty &&
                affectedItems.length <= options.maxItems &&
                affectedItems.every((item) => item.updatedAt != null) &&
                _hasTarget();

            return Column(
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
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.brandPrimary,
                          context.brandPrimary.withValues(alpha: 0.78),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.done_all_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Массовые действия',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Gilroy',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Одна атомарная команда без частичного применения',
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
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottomInset),
                    children: [
                      _SectionLabel('Какие товары'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _sourceCustomerId,
                        isExpanded: true,
                        decoration: SpFinanceUi.inputDecoration(
                          context,
                          labelText: 'Область действия',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: -1,
                            child: Text(
                              'Вся закупка · ${widget.purchase.items.length}',
                            ),
                          ),
                          ..._sourceCustomers().map(
                            (customer) => DropdownMenuItem(
                              value: customer.id,
                              child: Text(
                                '${customer.fullName} · ${_itemsCountFor(customer.id)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(
                                () => _sourceCustomerId = value ?? -1,
                              ),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel('Что сделать'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActionChoice(
                            label: 'Статус',
                            icon: Icons.flag_rounded,
                            selected: _action == _BulkAction.status,
                            onTap: () =>
                                setState(() => _action = _BulkAction.status),
                          ),
                          _ActionChoice(
                            label: 'Клиент',
                            icon: Icons.person_rounded,
                            selected: _action == _BulkAction.customer,
                            onTap: () =>
                                setState(() => _action = _BulkAction.customer),
                          ),
                          _ActionChoice(
                            label: 'Закупка',
                            icon: Icons.drive_file_move_rounded,
                            selected: _action == _BulkAction.purchase,
                            onTap: () =>
                                setState(() => _action = _BulkAction.purchase),
                          ),
                          _ActionChoice(
                            label: 'В архив',
                            icon: Icons.archive_rounded,
                            selected: _action == _BulkAction.archive,
                            destructive: true,
                            onTap: () =>
                                setState(() => _action = _BulkAction.archive),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTargetField(options),
                      const SizedBox(height: 14),
                      _BulkPreview(
                        items: affectedItems,
                        maxItems: options.maxItems,
                      ),
                      if (affectedItems.any(
                        (item) => item.updatedAt == null,
                      )) ...[
                        const SizedBox(height: 10),
                        const _InlineWarning(
                          'Обновите экран: часть товаров не содержит версии для безопасного атомарного изменения.',
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    10,
                    18,
                    18 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || !canApply
                          ? null
                          : () => _apply(options, affectedItems),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _action == _BulkAction.archive
                                  ? Icons.archive_rounded
                                  : Icons.check_rounded,
                            ),
                      label: Text(_buttonLabel(affectedItems.length)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _action == _BulkAction.archive
                            ? const Color(0xFFDC2626)
                            : context.brandPrimary,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildTargetField(SpV2BulkOptions options) {
    switch (_action) {
      case _BulkAction.status:
        if (options.statuses.isEmpty) {
          return const _InlineWarning(
            'Справочник статусов пока недоступен. Изменение статуса отключено.',
          );
        }
        return DropdownButtonFormField<String>(
          key: const ValueKey('bulk-target-status'),
          initialValue: _targetStatus,
          isExpanded: true,
          decoration: SpFinanceUi.inputDecoration(
            context,
            labelText: 'Новый статус',
          ),
          items: options.statuses
              .map(
                (status) => DropdownMenuItem(
                  value: status.code,
                  child: Text(status.nameRu),
                ),
              )
              .toList(growable: false),
          onChanged: _isSaving
              ? null
              : (value) => setState(() => _targetStatus = value),
        );
      case _BulkAction.customer:
        if (options.customers.isEmpty) {
          return const _InlineWarning('Нет доступных активных клиентов.');
        }
        return DropdownButtonFormField<int>(
          key: const ValueKey('bulk-target-customer'),
          initialValue: _targetCustomerId,
          isExpanded: true,
          decoration: SpFinanceUi.inputDecoration(
            context,
            labelText: 'Перенести клиенту',
          ),
          items: options.customers
              .map(
                (customer) => DropdownMenuItem(
                  value: customer.id,
                  child: Text(customer.name),
                ),
              )
              .toList(growable: false),
          onChanged: _isSaving
              ? null
              : (value) => setState(() => _targetCustomerId = value),
        );
      case _BulkAction.purchase:
        if (options.purchases.isEmpty) {
          return const _InlineWarning(
            'Нет другой активной закупки, которая принимает товары.',
          );
        }
        return DropdownButtonFormField<int>(
          key: const ValueKey('bulk-target-purchase'),
          initialValue: _targetPurchaseId,
          isExpanded: true,
          decoration: SpFinanceUi.inputDecoration(
            context,
            labelText: 'Перенести в закупку',
          ),
          items: options.purchases
              .map(
                (purchase) => DropdownMenuItem(
                  value: purchase.id,
                  child: Text(purchase.title, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: _isSaving
              ? null
              : (value) => setState(() => _targetPurchaseId = value),
        );
      case _BulkAction.archive:
        return TextField(
          controller: _archiveReasonController,
          enabled: !_isSaving,
          maxLength: 2000,
          maxLines: 2,
          decoration: SpFinanceUi.inputDecoration(
            context,
            labelText: 'Причина (необязательно)',
            hintText: 'Например: клиент отказался',
          ),
        );
    }
  }

  void _ensureTargets(SpV2BulkOptions options) {
    _targetStatus ??= options.statuses.firstOrNull?.code;
    _targetCustomerId ??= options.customers.firstOrNull?.id;
    _targetPurchaseId ??= options.purchases.firstOrNull?.id;
  }

  List<SpV2Customer> _sourceCustomers() {
    final customers = <int, SpV2Customer>{};
    for (final item in widget.purchase.items) {
      final customer = item.customer;
      if (customer != null) customers[customer.id] = customer;
    }
    final result = customers.values.toList()
      ..sort((left, right) => left.fullName.compareTo(right.fullName));
    return result;
  }

  int _itemsCountFor(int customerId) => widget.purchase.items
      .where((item) => item.customer?.id == customerId)
      .length;

  List<SpV2Item> _selectedItems() {
    if (_sourceCustomerId < 0) return widget.purchase.items;
    return widget.purchase.items
        .where((item) => item.customer?.id == _sourceCustomerId)
        .toList(growable: false);
  }

  List<SpV2Item> _affectedItems(List<SpV2Item> selected) {
    return selected
        .where((item) {
          return switch (_action) {
            _BulkAction.status => item.status != _targetStatus,
            _BulkAction.customer => item.customer?.id != _targetCustomerId,
            _BulkAction.purchase || _BulkAction.archive => true,
          };
        })
        .toList(growable: false);
  }

  bool _hasTarget() {
    return switch (_action) {
      _BulkAction.status => _targetStatus != null,
      _BulkAction.customer => _targetCustomerId != null,
      _BulkAction.purchase => _targetPurchaseId != null,
      _BulkAction.archive => true,
    };
  }

  String _buttonLabel(int count) {
    if (count == 0) return 'Нет изменений';
    return switch (_action) {
      _BulkAction.status => 'Изменить статус · $count',
      _BulkAction.customer => 'Перенести клиенту · $count',
      _BulkAction.purchase => 'Перенести в закупку · $count',
      _BulkAction.archive => 'Архивировать · $count',
    };
  }

  Future<void> _apply(SpV2BulkOptions options, List<SpV2Item> items) async {
    if (_isSaving) return;
    if (items.isEmpty ||
        items.length > options.maxItems ||
        items.any((item) => item.updatedAt == null)) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      if (_action == _BulkAction.archive) {
        final confirmed = await showSpFinanceConfirmationSheet(
          context: context,
          icon: Icons.archive_rounded,
          title: 'Убрать товары из активной закупки?',
          message:
              'Будет архивировано товаров: ${items.length}. Данные, оплаты, фото и связи не удаляются.',
          confirmLabel: 'В архив',
          destructive: true,
        );
        if (!mounted || confirmed != true) return;
      }
      final result = await ref
          .read(spV2RepositoryProvider)
          .applyBulkItemUpdates(
            widget.purchase.id,
            operation: switch (_action) {
              _BulkAction.status => 'status',
              _BulkAction.customer => 'customer',
              _BulkAction.purchase => 'purchase',
              _BulkAction.archive => 'archive',
            },
            targetStatus: _action == _BulkAction.status ? _targetStatus : null,
            targetCustomerId: _action == _BulkAction.customer
                ? _targetCustomerId
                : null,
            targetPurchaseId: _action == _BulkAction.purchase
                ? _targetPurchaseId
                : null,
            archiveReason: _action == _BulkAction.archive
                ? _archiveReasonController.text.trim()
                : null,
            items: items
                .map(
                  (item) => SpV2BulkItemUpdate(
                    id: item.id,
                    expectedUpdatedAt: item.updatedAt!,
                  ),
                )
                .toList(growable: false),
          );
      if (!mounted) return;
      AppToast.show(context, 'Обновлено товаров: ${result.updatedCount}');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      AppToast.show(context, _bulkErrorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: SpFinanceUi.sectionTitleStyle.copyWith(fontSize: 16),
    );
  }
}

class _ActionChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionChoice({
    required this.label,
    required this.icon,
    required this.selected,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = destructive
        ? const Color(0xFFDC2626)
        : context.brandPrimary;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : activeColor,
      ),
      label: Text(label),
      selectedColor: activeColor,
      backgroundColor: activeColor.withValues(alpha: 0.08),
      side: BorderSide(
        color: activeColor.withValues(alpha: selected ? 0 : 0.18),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontFamily: 'Gilroy',
        fontWeight: FontWeight.w800,
      ),
      showCheckmark: false,
    );
  }
}

class _BulkPreview extends StatelessWidget {
  final List<SpV2Item> items;
  final int maxItems;

  const _BulkPreview({required this.items, required this.maxItems});

  @override
  Widget build(BuildContext context) {
    final dueRub = items.fold<double>(0, (sum, item) => sum + item.totalDueRub);
    final tracks = items.fold<int>(0, (sum, item) => sum + item.tracks.length);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.cardDecoration(
        color: context.brandPrimary.withValues(alpha: 0.045),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Предпросмотр',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PreviewChip(
                icon: Icons.inventory_2_rounded,
                label: '${items.length} товаров',
                warning: items.length > maxItems,
              ),
              _PreviewChip(
                icon: Icons.payments_outlined,
                label: '${dueRub.toStringAsFixed(2)} ₽',
              ),
              _PreviewChip(
                icon: Icons.local_shipping_outlined,
                label: '$tracks треков',
              ),
            ],
          ),
          if (items.length > maxItems) ...[
            const SizedBox(height: 10),
            Text(
              'За одну команду можно изменить не более $maxItems товаров. Выберите одного клиента.',
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontFamily: 'Gilroy',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool warning;

  const _PreviewChip({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFB45309) : context.brandPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Gilroy',
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  final String message;

  const _InlineWarning(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontFamily: 'Gilroy',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkLoadError extends StatelessWidget {
  final VoidCallback onClose;

  const _BulkLoadError({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Не удалось загрузить варианты массовых действий',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onClose, child: const Text('Закрыть')),
          ],
        ),
      ),
    );
  }
}

String _bulkErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final code = data['code'];
      if (code == 'SP_BULK_ITEMS_STALE') {
        return 'Данные изменились после предпросмотра. Обновите экран и повторите.';
      }
      if (code == 'SP_BULK_TARGET_INVALID') {
        return 'Выбранный клиент, статус или закупка больше недоступны.';
      }
      if (code == 'SP_BULK_ITEMS_ARCHIVED') {
        return 'В выборке есть архивные товары. Обновите экран.';
      }
    }
  }
  return 'Не удалось выполнить массовое действие';
}
