import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/sheet_handle.dart';
import '../application/notifications_controller.dart';
import '../domain/notification_item.dart';

/// Интервал polling (30 секунд)
const _kPollingInterval = Duration(seconds: 30);

/// Notifier для фильтра типа уведомлений
class _SelectedFilterNotifier extends Notifier<NotificationType?> {
  @override
  NotificationType? build() => null;

  void set(NotificationType? value) => state = value;
}

/// Выбранный фильтр типа уведомлений
final _selectedFilterProvider =
    NotifierProvider<_SelectedFilterNotifier, NotificationType?>(
      _SelectedFilterNotifier.new,
    );

class NotificationsSheet extends ConsumerStatefulWidget {
  final String clientCode;
  final ValueChanged<String> onNavigate;
  final ScrollController? controller;

  const NotificationsSheet({
    super.key,
    required this.clientCode,
    required this.onNavigate,
    this.controller,
  });

  @override
  ConsumerState<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(_kPollingInterval, (_) {
      if (!mounted) return;
      debugPrint('🔔 Polling notifications...');
      ref
          .read(notificationsControllerProvider(widget.clientCode).notifier)
          .refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(
      notificationsControllerProvider(widget.clientCode),
    );
    final selectedFilter = ref.watch(_selectedFilterProvider);

    return SafeArea(
      child: Column(
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Уведомления',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: itemsAsync.value?.any((n) => !n.isRead) == true
                      ? () => ref
                            .read(
                              notificationsControllerProvider(
                                widget.clientCode,
                              ).notifier,
                            )
                            .markAllRead()
                      : null,
                  child: const Text('Прочитать всё'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Фильтры по типам
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Все',
                  isSelected: selectedFilter == null,
                  onTap: () =>
                      ref.read(_selectedFilterProvider.notifier).set(null),
                ),
                const SizedBox(width: 8),
                ...NotificationType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: type.displayName,
                      icon: type.icon,
                      isSelected: selectedFilter == type,
                      onTap: () =>
                          ref.read(_selectedFilterProvider.notifier).set(type),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text('Ошибка загрузки: $e', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref
                            .read(
                              notificationsControllerProvider(
                                widget.clientCode,
                              ).notifier,
                            )
                            .refresh(),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) => _buildItemsList(context, items, selectedFilter),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    List<NotificationItem> items,
    NotificationType? selectedFilter,
  ) {
    // Фильтруем по выбранному типу
    final filteredItems = selectedFilter != null
        ? items.where((n) => n.type == selectedFilter).toList()
        : items;

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selectedFilter?.icon ?? Icons.notifications_off_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              selectedFilter != null
                  ? 'Нет уведомлений типа "${selectedFilter.displayName}"'
                  : 'Пока нет уведомлений',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = filteredItems[i];
        return _NotificationTile(
          item: item,
          onTap: () async {
            await ref
                .read(
                  notificationsControllerProvider(widget.clientCode).notifier,
                )
                .markRead(item.id);
            final route = item.route;
            if (route == null) return;
            widget.onNavigate(route);
          },
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.brandPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? context.brandPrimary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM, HH:mm', 'ru');
    final time = df.format(item.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? Colors.grey.withValues(alpha: 0.05)
                : context.brandSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: item.isRead
                ? null
                : Border.all(
                    color: context.brandSecondary.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.brandSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.type.icon,
                      color: context.brandSecondary,
                      size: 22,
                    ),
                  ),
                  if (!item.isRead)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: CircleAvatar(
                        radius: 6,
                        backgroundColor: context.brandPrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Тип уведомления
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.brandSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.type.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Показываем изменение статуса если есть
                    if (item.oldStatus != null && item.newStatus != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _StatusBadge(status: item.oldStatus!, isOld: true),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ),
                          _StatusBadge(status: item.newStatus!, isOld: false),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isOld;

  const _StatusBadge({required this.status, required this.isOld});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOld
            ? Colors.grey.shade200
            : const Color(0xFF4CAF50).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOld ? Colors.grey.shade600 : const Color(0xFF2E7D32),
        ),
      ),
    );
  }
}
