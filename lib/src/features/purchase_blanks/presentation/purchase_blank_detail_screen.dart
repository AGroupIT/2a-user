import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/sheet_handle.dart';
import '../data/purchase_blank_model.dart';
import '../data/purchase_blanks_provider.dart';
import 'widgets/blank_item_card.dart';
import 'widgets/blank_item_form.dart';
import 'widgets/blank_status_badge.dart';

class PurchaseBlankDetailScreen extends ConsumerStatefulWidget {
  final int blankId;

  const PurchaseBlankDetailScreen({super.key, required this.blankId});

  @override
  ConsumerState<PurchaseBlankDetailScreen> createState() =>
      _PurchaseBlankDetailScreenState();
}

class _PurchaseBlankDetailScreenState
    extends ConsumerState<PurchaseBlankDetailScreen> {
  bool _showAddForm = false;
  int? _editingItemId;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(purchaseBlankDetailProvider(widget.blankId));

    return detailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Ошибка загрузки: $e'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(
                  purchaseBlankDetailProvider(widget.blankId)),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
      data: (blank) {
        if (blank == null) {
          return const Center(
            child: Text('Бланк не найден'),
          );
        }
        return _buildContent(context, blank);
      },
    );
  }

  Widget _buildContent(BuildContext context, PurchaseBlank blank) {
    final theme = Theme.of(context);
    final isEditable = blank.status.isEditableByClient;
    final isCancellable = blank.status.isCancellableByClient;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(purchaseBlankDetailProvider(widget.blankId));
      },
      color: context.brandPrimary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 100),
        children: [
          // ── Заголовок ────────────────────────────────
          _buildHeaderSection(context, theme, blank),
          const SizedBox(height: 20),

          // ── Финансовая информация ────────────────────
          _buildFinanceSection(context, theme, blank),
          const SizedBox(height: 20),

          // ── Список товаров ───────────────────────────
          _buildItemsHeader(context, theme, blank, isEditable),
          const SizedBox(height: 10),

          ...blank.items.map((item) {
            if (_editingItemId == item.id) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BlankItemForm(
                  existingItem: item,
                  onSave: ({
                    required String productName,
                    required String productUrl,
                    String? characteristics,
                    required int quantity,
                    required double unitPrice,
                    List<Uint8List>? newPhotos,
                    List<String>? newPhotoNames,
                  }) async {
                    await _updateItem(
                      blank.id,
                      item.id,
                      productName: productName,
                      productUrl: productUrl,
                      characteristics: characteristics,
                      quantity: quantity,
                      unitPrice: unitPrice,
                      newPhotos: newPhotos,
                      newPhotoNames: newPhotoNames,
                    );
                  },
                  onCancel: () => setState(() => _editingItemId = null),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BlankItemCard(
                item: item,
                isEditable: isEditable,
                onEdit: () => setState(() => _editingItemId = item.id),
                onDelete: () => _deleteItem(blank.id, item.id),
              ),
            );
          }),

          // ── Форма добавления товара ──────────────────
          if (_showAddForm && isEditable) ...[
            BlankItemForm(
              onSave: ({
                required String productName,
                required String productUrl,
                String? characteristics,
                required int quantity,
                required double unitPrice,
                List<Uint8List>? newPhotos,
                List<String>? newPhotoNames,
              }) async {
                await _addItem(
                  blank.id,
                  productName: productName,
                  productUrl: productUrl,
                  characteristics: characteristics,
                  quantity: quantity,
                  unitPrice: unitPrice,
                  newPhotos: newPhotos,
                  newPhotoNames: newPhotoNames,
                );
              },
              onCancel: () => setState(() => _showAddForm = false),
            ),
            const SizedBox(height: 16),
          ],

          // ── Пустое состояние товаров ─────────────────
          if (blank.items.isEmpty && !_showAddForm)
            _buildEmptyItemsState(context, isEditable),

          // ── Кнопки действий ──────────────────────────
          if (isEditable) ...[
            const SizedBox(height: 16),
            _buildActionButtons(context, blank, isCancellable),
          ] else if (!blank.status.isFinal) ...[
            const SizedBox(height: 16),
            _buildReadOnlyNotice(context, blank, isCancellable),
          ],

          // ── Сноска ──────────────────────────────────
          if (!isEditable && !blank.status.isFinal) ...[
            const SizedBox(height: 20),
            Text(
              'Бланк на рассмотрении. Редактирование невозможно.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Заголовок ──────────────────────────────────────────────

  Widget _buildHeaderSection(
      BuildContext context, ThemeData theme, PurchaseBlank blank) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: context.brandPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Бланк #${blank.id}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Создан: ${dateFormat.format(blank.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              BlankStatusBadge(status: blank.status),
            ],
          ),
          if (blank.employeeComment != null &&
              blank.employeeComment!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.comment_rounded,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      blank.employeeComment!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Финансовая секция ──────────────────────────────────────

  Widget _buildFinanceSection(
      BuildContext context, ThemeData theme, PurchaseBlank blank) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Финансовая информация',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Строки данных
          _FinanceRow(
            label: 'Комиссия за выкуп',
            value: blank.commissionPercent != null
                ? '${blank.commissionPercent!.toStringAsFixed(1)}%'
                : '—',
            isEmpty: blank.commissionPercent == null,
          ),
          _FinanceRow(
            label: 'Курс USD/CNY',
            value: blank.usdToCny != null
                ? blank.usdToCny!.toStringAsFixed(4)
                : '—',
            isEmpty: blank.usdToCny == null,
          ),
          _FinanceRow(
            label: 'Курс USD/RUB',
            value: blank.usdToRub != null
                ? blank.usdToRub!.toStringAsFixed(2)
                : '—',
            isEmpty: blank.usdToRub == null,
          ),
          const Divider(height: 20),
          _FinanceRow(
            label: 'Итого (¥)',
            value: blank.totalAmountCny != null
                ? '¥${blank.totalAmountCny!.toStringAsFixed(2)}'
                : (blank.clientTotalCny > 0
                    ? '≈ ¥${blank.clientTotalCny.toStringAsFixed(2)}'
                    : '—'),
            isEmpty: blank.totalAmountCny == null && blank.clientTotalCny == 0,
            isTotal: true,
          ),
          _FinanceRow(
            label: 'Итого (₽)',
            value: blank.totalAmountRub != null
                ? '₽${blank.totalAmountRub!.toStringAsFixed(0)}'
                : '—',
            isEmpty: blank.totalAmountRub == null,
            isTotal: true,
          ),

          // Сноска
          const SizedBox(height: 10),
          Text(
            '* Данные, отмеченные прочерком, заполняются сотрудником компании',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── Заголовок списка товаров ───────────────────────────────

  Widget _buildItemsHeader(BuildContext context, ThemeData theme,
      PurchaseBlank blank, bool isEditable) {
    return Row(
      children: [
        Text(
          'Товары (${blank.itemsCount})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (isEditable && !_showAddForm)
          GestureDetector(
            onTap: () => setState(() {
              _showAddForm = true;
              _editingItemId = null;
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded,
                      size: 16, color: context.brandPrimary),
                  const SizedBox(width: 4),
                  Text(
                    'Добавить',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Пустое состояние товаров ───────────────────────────────

  Widget _buildEmptyItemsState(BuildContext context, bool isEditable) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Нет товаров',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEditable
                ? 'Добавьте первый товар в бланк'
                : 'Товары ещё не добавлены',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
          if (isEditable) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => setState(() => _showAddForm = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить товар'),
              style: TextButton.styleFrom(
                foregroundColor: context.brandPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Кнопки действий (черновик) ─────────────────────────────

  Widget _buildActionButtons(
      BuildContext context, PurchaseBlank blank, bool isCancellable) {
    return Column(
      children: [
        // Отправить
        if (blank.items.isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _submitBlank(blank.id),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text(
                'Отправить бланк',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        if (isCancellable) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _cancelBlank(blank.id),
              icon: const Icon(Icons.cancel_rounded, size: 18),
              label: const Text(
                'Отменить бланк',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Кнопки для не-черновика ────────────────────────────────

  Widget _buildReadOnlyNotice(
      BuildContext context, PurchaseBlank blank, bool isCancellable) {
    if (!isCancellable) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () => _cancelBlank(blank.id),
        icon: const Icon(Icons.cancel_rounded, size: 18),
        label: const Text(
          'Отменить бланк',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ── Действия ──────────────────────────────────────────────

  Future<void> _addItem(
    int blankId, {
    required String productName,
    required String productUrl,
    String? characteristics,
    required int quantity,
    required double unitPrice,
    List<Uint8List>? newPhotos,
    List<String>? newPhotoNames,
  }) async {
    final notifier = ref.read(purchaseBlanksProvider.notifier);
    final item = await notifier.addItem(
      blankId,
      productName: productName,
      productUrl: productUrl,
      characteristics: characteristics,
      quantity: quantity,
      unitPrice: unitPrice,
    );

    if (item != null && newPhotos != null) {
      // Загружаем фото по одному
      for (int i = 0; i < newPhotos.length; i++) {
        await notifier.uploadItemPhoto(
          blankId,
          item.id,
          newPhotos[i].toList(),
          newPhotoNames?[i] ?? 'photo_$i.jpg',
        );
      }
    }

    if (mounted) {
      setState(() => _showAddForm = false);
      ref.invalidate(purchaseBlankDetailProvider(widget.blankId));
    }
  }

  Future<void> _updateItem(
    int blankId,
    int itemId, {
    required String productName,
    required String productUrl,
    String? characteristics,
    required int quantity,
    required double unitPrice,
    List<Uint8List>? newPhotos,
    List<String>? newPhotoNames,
  }) async {
    final notifier = ref.read(purchaseBlanksProvider.notifier);
    await notifier.updateItem(
      blankId,
      itemId,
      productName: productName,
      productUrl: productUrl,
      characteristics: characteristics,
      quantity: quantity,
      unitPrice: unitPrice,
    );

    if (newPhotos != null) {
      for (int i = 0; i < newPhotos.length; i++) {
        await notifier.uploadItemPhoto(
          blankId,
          itemId,
          newPhotos[i].toList(),
          newPhotoNames?[i] ?? 'photo_$i.jpg',
        );
      }
    }

    if (mounted) {
      setState(() => _editingItemId = null);
      ref.invalidate(purchaseBlankDetailProvider(widget.blankId));
    }
  }

  Future<void> _deleteItem(int blankId, int itemId) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
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
                const SheetHandle(),
                const SizedBox(height: 12),
                Text(
                  'Удалить товар?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Это действие нельзя отменить',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await ref
          .read(purchaseBlanksProvider.notifier)
          .deleteItem(blankId, itemId);
      ref.invalidate(purchaseBlankDetailProvider(widget.blankId));
    }
  }

  Future<void> _submitBlank(int blankId) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
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
                const SheetHandle(),
                const SizedBox(height: 12),
                Text(
                  'Отправить бланк?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'После отправки редактирование будет невозможно. '
                  'Бланк будет передан сотруднику для обработки.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('Отправить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      final success =
          await ref.read(purchaseBlanksProvider.notifier).submitBlank(blankId);
      if (mounted) {
        ref.invalidate(purchaseBlankDetailProvider(widget.blankId));
        if (success) {
          _showSnackBar('Бланк отправлен на обработку');
        } else {
          _showSnackBar('Ошибка отправки бланка', isError: true);
        }
      }
    }
  }

  Future<void> _cancelBlank(int blankId) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
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
                const SheetHandle(),
                const SizedBox(height: 12),
                Text(
                  'Отменить бланк?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Это действие нельзя отменить',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Нет'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Отменить бланк'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      final success =
          await ref.read(purchaseBlanksProvider.notifier).cancelBlank(blankId);
      if (mounted) {
        ref.invalidate(purchaseBlankDetailProvider(widget.blankId));
        if (success) {
          _showSnackBar('Бланк отменён');
        } else {
          _showSnackBar('Ошибка отмены', isError: true);
        }
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
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
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFE53935) : context.brandPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ── Строка финансовых данных ─────────────────────────────────

class _FinanceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmpty;
  final bool isTotal;

  const _FinanceRow({
    required this.label,
    required this.value,
    this.isEmpty = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color:
                  isTotal ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: FontWeight.w700,
              color: isEmpty
                  ? Colors.grey.shade400
                  : (isTotal
                      ? context.brandPrimary
                      : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
