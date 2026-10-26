import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../../assemblies/domain/box.dart';
import '../data/client_carrier_tracking.dart';

typedef CarrierSectionBuilder =
    Widget Function(BuildContext context, Widget child);

/// Uses the host sheet's existing section surface and brand palette.
class ClientCarrierTrackingPanel extends ConsumerWidget {
  const ClientCarrierTrackingPanel({
    super.key,
    required this.target,
    required this.sectionBuilder,
    this.boxes = const [],
  });

  final ClientCarrierTarget target;
  final List<Box> boxes;
  final CarrierSectionBuilder sectionBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(clientCarrierTrackingProvider(target));
    void refresh() => ref.invalidate(clientCarrierTrackingProvider(target));
    Widget section(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: sectionBuilder(context, child),
    );
    return result.when(
      skipLoadingOnRefresh: false,
      loading: () => section(
        const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ),
      error: (error, _) => section(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ErrorUtils.getErrorInfo(error).getMessage(context),
              style: _secondary,
            ),
            TextButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(tr(context, ru: 'Повторить', zh: '重试')),
            ),
          ],
        ),
      ),
      data: (data) {
        // Also hides the feature when the connection's client visibility is off.
        if (data.shipments.isEmpty) return const SizedBox.shrink();
        final shipments = [...data.shipments]
          ..sort((a, b) {
            int firstBox(ClientCarrierShipment s) => boxes
                .where((b) => s.boxIds.contains(b.id))
                .map((b) => b.number)
                .fold(1 << 30, (a, b) => a < b ? a : b);
            final order = firstBox(a).compareTo(firstBox(b));
            return order != 0 ? order : a.number.compareTo(b.number);
          });
        final trackedIds = shipments.expand((s) => s.boxIds).toSet();
        final missing = <String, List<Box>>{};
        for (final box in boxes.where((b) => !trackedIds.contains(b.id))) {
          (missing[(box.orderNumber ?? '').trim()] ??= []).add(box);
        }
        return section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        ru: 'Этапы доставки по накладным',
                        zh: '按运单查看运输进度',
                      ),
                      style: _secondary,
                    ),
                  ),
                  IconButton(
                    onPressed: refresh,
                    tooltip: tr(context, ru: 'Обновить статусы', zh: '刷新物流状态'),
                    color: context.brandPrimary,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ],
              ),
              if (missing.isNotEmpty ||
                  shipments.any((s) => s.pending || s.tracked < s.places))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    tr(
                      context,
                      ru: 'По части коробок история ещё не получена.',
                      zh: '部分箱子的物流记录尚未获取。',
                    ),
                    style: _secondary,
                  ),
                ),
              for (final shipment in shipments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ShipmentCard(
                    key: ValueKey((target, shipment.id)),
                    shipment: shipment,
                    boxes: boxes
                        .where((b) => shipment.boxIds.contains(b.id))
                        .toList(),
                  ),
                ),
              for (final entry in missing.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    [
                      if (entry.key.isNotEmpty) entry.key,
                      _boxLabel(context, entry.value),
                      tr(
                        context,
                        ru: 'История доставки пока не получена',
                        zh: '尚未获取物流记录',
                      ),
                    ].join(' · '),
                    style: _secondary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

const _secondary = TextStyle(
  fontFamily: 'Gilroy',
  fontSize: 12.5,
  height: 1.3,
  color: AppColors.textSecondary,
  fontWeight: FontWeight.w500,
);

String _boxLabel(BuildContext context, List<Box> boxes) {
  if (boxes.isEmpty) return '';
  final numbers = boxes.map((b) => b.number).toSet().toList()..sort();
  return tr(
    context,
    ru: 'Коробки № ${numbers.join(', ')}',
    zh: '箱号 ${numbers.join('、')}',
  );
}

String carrierTrackingDate(
  String? raw, {
  bool dateOnly = false,
  bool local = false,
}) {
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return '—';
  // Carrier wall-clock dates have no timezone. Never shift a calendar-only event.
  final value = local && !dateOnly ? date.toLocal() : date;
  return DateFormat(dateOnly ? 'dd.MM.yyyy' : 'dd.MM.yyyy HH:mm').format(value);
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({super.key, required this.shipment, required this.boxes});
  final ClientCarrierShipment shipment;
  final List<Box> boxes;

  @override
  Widget build(BuildContext context) {
    final s = shipment;
    final accent = context.brandPrimary;
    final label = s.pending
        ? tr(context, ru: 'Ожидается загрузка истории', zh: '等待加载物流记录')
        : isZh(context)
        ? s.labelZh
        : s.labelRu;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: .04)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey((s.id, s.number)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: accent,
          collapsedIconColor: accent,
          title: Text(
            s.number,
            style: const TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (boxes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(_boxLabel(context, boxes), style: _secondary),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label.isEmpty
                        ? tr(context, ru: 'Статус уточняется', zh: '状态待确认')
                        : label,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    context,
                    ru: 'Прибыло ${s.arrived} из ${s.places} мест',
                    zh: '已到达 ${s.arrived}/${s.places} 件',
                  ),
                  style: _secondary,
                ),
              ],
            ),
          ),
          children: [
            if (!s.pending && s.updatedAt != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr(
                    context,
                    ru: 'Обновлено: ${carrierTrackingDate(s.updatedAt, local: true)}',
                    zh: '更新时间：${carrierTrackingDate(s.updatedAt, local: true)}',
                  ),
                  style: _secondary,
                ),
              ),
            if (s.stale && !s.pending)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr(
                    context,
                    ru: 'Данные давно не обновлялись. Показана последняя полученная история.',
                    zh: '数据较久未更新，当前显示最近获取的物流记录。',
                  ),
                  style: _secondary,
                ),
              ),
            if (s.eta != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr(
                    context,
                    ru: 'Ожидаемое прибытие: ${carrierTrackingDate(s.eta, dateOnly: true)} · прогноз',
                    zh: '预计到达：${carrierTrackingDate(s.eta, dateOnly: true)} · 预测',
                  ),
                  style: _secondary,
                ),
              ),
            const SizedBox(height: 10),
            if (s.events.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr(
                    context,
                    ru: s.pending
                        ? 'Загружаем историю движения груза.'
                        : 'Подробная история пока не получена.',
                    zh: s.pending ? '正在加载货物运输记录。' : '尚未获取详细物流记录。',
                  ),
                  style: _secondary,
                ),
              ),
            for (var i = 0; i < s.events.length; i++)
              _EventRow(event: s.events[i], last: i == s.events.length - 1),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.last});
  final ClientCarrierEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              const SizedBox(height: 4),
              Icon(
                event.forecast
                    ? Icons.schedule_rounded
                    : Icons.check_circle_rounded,
                size: 16,
                color: event.forecast
                    ? AppColors.textSecondary
                    : context.brandPrimary,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 1,
                    color: context.brandPrimary.withValues(alpha: .18),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isZh(context) ? event.labelZh : event.labelRu}${event.forecast ? tr(context, ru: ' · прогноз', zh: ' · 预测') : ''}',
                  style: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  carrierTrackingDate(event.date, dateOnly: event.dateOnly),
                  style: _secondary,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
