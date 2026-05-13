import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/ui/app_colors.dart';
import '../../data/purchase_blank_model.dart';
import '../purchase_blank_ui.dart';

/// Карточка товара в бланке
class BlankItemCard extends StatelessWidget {
  final PurchaseBlankItem item;
  final bool isEditable;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BlankItemCard({
    super.key,
    required this.item,
    this.isEditable = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PurchaseBlankUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Номер
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.orderNumber}',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      height: 15 / 13,
                      fontWeight: FontWeight.w700,
                      color: context.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Название + ссылка
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          color: PurchaseBlankUi.textColor,
                          fontFamily: 'Gilroy',
                          fontSize: 15,
                          height: 18 / 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.productUrl.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () => _openUrl(item.productUrl),
                          child: Text(
                            item.productUrl,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 12,
                              height: 14 / 12,
                              color: Colors.blue.shade600,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Кнопки редактирования
                if (isEditable)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: Colors.grey,
                    ),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Редактировать'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Удалить',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Фото ──────────────────────────────────────
          if (item.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: item.photoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: ApiConfig.getMediaUrl(item.photoUrls[i]),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey.shade100,
                        child: const Icon(
                          Icons.image_rounded,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey.shade100,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // ── Характеристики ────────────────────────────
          if (item.characteristics != null &&
              item.characteristics!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.characteristics!,
                  style: const TextStyle(
                    color: PurchaseBlankUi.mutedTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    height: 15 / 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],

          // ── Цена и количество ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                _InfoChip(label: 'Кол-во', value: '${item.quantity} шт.'),
                const SizedBox(width: 8),
                _InfoChip(
                  label: 'Цена',
                  value: '¥${item.unitPrice.toStringAsFixed(2)}',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  label: 'Итого',
                  value: '¥${item.totalPrice.toStringAsFixed(2)}',
                  highlighted: true,
                ),
              ],
            ),
          ),

          // ── Данные сотрудника ──────────────────────────
          if (item.hasEmployeeData) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Row(
                children: [
                  if (item.trackNumber != null) ...[
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.trackNumber!,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        height: 14 / 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (item.commission != null) ...[
                    Text(
                      'Комиссия: ¥${item.commission!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        height: 14 / 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (item.itemTotal != null)
                    Text(
                      'Итог: ¥${item.itemTotal!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 13,
                        height: 15 / 13,
                        fontWeight: FontWeight.w700,
                        color: context.brandPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Трек и комиссия заполняются сотрудником',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 11,
                      height: 13 / 11,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _InfoChip({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: highlighted
              ? context.brandPrimary.withValues(alpha: 0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 10,
                height: 12 / 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 15 / 13,
                fontWeight: FontWeight.w700,
                color: highlighted
                    ? context.brandPrimary
                    : PurchaseBlankUi.textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
