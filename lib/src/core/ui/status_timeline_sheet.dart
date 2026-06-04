import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';

import '../models/status_timeline_entry.dart';
import 'app_colors.dart';
import 'sheet_handle.dart';

class StatusTimelineStatus {
  final String code;
  final String name;
  final Color? color;
  final int sortOrder;

  const StatusTimelineStatus({
    required this.code,
    required this.name,
    this.color,
    this.sortOrder = 0,
  });
}

Future<void> showStatusTimelineSheet({
  required BuildContext context,
  required String title,
  required String currentStatusCode,
  required String currentStatusName,
  required Color? currentStatusColor,
  required List<StatusTimelineEntry> history,
  required List<StatusTimelineStatus> statuses,
}) {
  return showBlurredModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => StatusTimelineSheet(
      title: title,
      currentStatusCode: currentStatusCode,
      currentStatusName: currentStatusName,
      currentStatusColor: currentStatusColor,
      history: history,
      statuses: statuses,
    ),
  );
}

class StatusTimelineSheet extends StatelessWidget {
  final String title;
  final String currentStatusCode;
  final String currentStatusName;
  final Color? currentStatusColor;
  final List<StatusTimelineEntry> history;
  final List<StatusTimelineStatus> statuses;

  const StatusTimelineSheet({
    super.key,
    required this.title,
    required this.currentStatusCode,
    required this.currentStatusName,
    required this.currentStatusColor,
    required this.history,
    required this.statuses,
  });

  @override
  Widget build(BuildContext context) {
    final sortedStatuses = [...statuses]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final statusByCode = {
      for (final status in sortedStatuses) status.code: status,
    };
    final entries = _normalizedHistory();

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2F2F2F),
                      fontFamily: 'Gilroy',
                      fontSize: 22,
                      height: 26 / 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CurrentStatusCard(
                    text: currentStatusName,
                    color: currentStatusColor ?? context.brandPrimary,
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle('Хронология статусов'),
                  const SizedBox(height: 10),
                  if (entries.isEmpty)
                    const _EmptyText(
                      'История изменения статуса пока не записана.',
                    )
                  else
                    ...entries.map(
                      (entry) => _TimelineRow(
                        entry: entry,
                        status: statusByCode[entry.statusCode],
                        fallbackName: entry.statusCode == currentStatusCode
                            ? currentStatusName
                            : entry.statusCode,
                        fallbackColor: entry.statusCode == currentStatusCode
                            ? currentStatusColor
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<StatusTimelineEntry> _normalizedHistory() {
    final entries = history
        .where((entry) => entry.statusCode.trim().isNotEmpty)
        .toList(growable: true);
    entries.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    final hasCurrent = entries.any(
      (entry) => entry.statusCode == currentStatusCode,
    );
    if (!hasCurrent && currentStatusCode.trim().isNotEmpty) {
      entries.insert(
        0,
        StatusTimelineEntry(
          statusCode: currentStatusCode,
          description: 'Текущий статус',
        ),
      );
    }

    return entries;
  }
}

class _CurrentStatusCard extends StatelessWidget {
  final String text;
  final Color color;

  const _CurrentStatusCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.radio_button_checked_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF2F2F2F),
                fontFamily: 'Gilroy',
                fontSize: 18,
                height: 22 / 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2F2F2F),
        fontFamily: 'Gilroy',
        fontSize: 18,
        height: 22 / 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final StatusTimelineEntry entry;
  final StatusTimelineStatus? status;
  final String fallbackName;
  final Color? fallbackColor;

  const _TimelineRow({
    required this.entry,
    required this.status,
    required this.fallbackName,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = status?.color ?? fallbackColor ?? context.brandPrimary;
    final dateText = entry.createdAt == null
        ? null
        : DateFormat('dd.MM.yyyy HH:mm', 'ru').format(entry.createdAt!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.circle_rounded, color: color, size: 12),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status?.name ?? fallbackName,
                  style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.description!.trim(),
                    style: const TextStyle(
                      color: Color(0x99000000),
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      height: 18 / 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                if (dateText != null || entry.createdByName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (dateText != null) dateText,
                      if (entry.createdByName?.trim().isNotEmpty == true)
                        entry.createdByName!.trim(),
                    ].join(' • '),
                    style: const TextStyle(
                      color: Color(0x66000000),
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      height: 16 / 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0x99000000),
        fontFamily: 'Gilroy',
        fontSize: 14,
        height: 18 / 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
