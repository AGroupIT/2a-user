import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../domain/garage_models.dart';
import 'garage_ui.dart';

class GarageRequestStatusProgress extends StatefulWidget {
  final GarageRequest request;
  final List<GarageRequestStatusDefinition> statuses;

  const GarageRequestStatusProgress({
    super.key,
    required this.request,
    required this.statuses,
  });

  @override
  State<GarageRequestStatusProgress> createState() =>
      _GarageRequestStatusProgressState();
}

class _GarageRequestStatusProgressState
    extends State<GarageRequestStatusProgress> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final definitions = _definitions(widget.statuses);
    final currentStatus = canonicalGarageRequestStatus(
      widget.request.status,
      order: widget.request.order,
    );
    final currentIndex = definitions.indexWhere(
      (definition) => definition.code == currentStatus,
    );
    final statusDates = _statusDates(widget.request);
    final lastReachedIndex = _lastReachedIndex(
      definitions,
      statusDates,
      currentIndex,
    );
    final currentDefinition = definitions
        .where((definition) => definition.code == currentStatus)
        .firstOrNull;
    final currentColor =
        garageStatusColorFromHex(currentDefinition?.color) ??
        garageStatusColor(currentStatus);
    final currentLabel = currentDefinition?.nameRu.trim().isNotEmpty == true
        ? currentDefinition!.nameRu
        : garageStatusLabel(currentStatus);
    final currentDate = statusDates[currentStatus];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var index = 0; index < definitions.length; index++) ...[
              Expanded(
                child: Container(
                  key: ValueKey(
                    'garage-status-segment-${definitions[index].code}',
                  ),
                  height: 7,
                  decoration: BoxDecoration(
                    color: _segmentColor(
                      context,
                      index: index,
                      currentIndex: currentIndex,
                      lastReachedIndex: lastReachedIndex,
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (index != definitions.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 11),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('garage-status-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: currentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: currentColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.flag_rounded,
                      color: currentColor,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Текущий статус',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Gilroy',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentLabel,
                          key: const ValueKey('garage-current-status-label'),
                          style: TextStyle(
                            color: currentColor,
                            fontFamily: 'Gilroy',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (_expanded && currentDate != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _formatStatusDate(currentDate),
                            key: const ValueKey('garage-current-status-date'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'Gilroy',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: currentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      for (var index = 0; index < definitions.length; index++)
                        _StatusStageRow(
                          definition: definitions[index],
                          changedAt: statusDates[definitions[index].code],
                          state: _stageState(
                            index: index,
                            currentIndex: currentIndex,
                            lastReachedIndex: lastReachedIndex,
                          ),
                          isLast: index == definitions.length - 1,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StatusStageRow extends StatelessWidget {
  final GarageRequestStatusDefinition definition;
  final DateTime? changedAt;
  final _StatusStageState state;
  final bool isLast;

  const _StatusStageRow({
    required this.definition,
    required this.changedAt,
    required this.state,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final future = state == _StatusStageState.future;
    final current = state == _StatusStageState.current;
    final color =
        garageStatusColorFromHex(definition.color) ??
        garageStatusColor(definition.code);
    return Opacity(
      key: ValueKey('garage-status-stage-${definition.code}'),
      opacity: future ? 0.42 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: current
                        ? color
                        : state == _StatusStageState.completed
                        ? color.withValues(alpha: 0.13)
                        : const Color(0xFFE4E7EC),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current
                          ? color
                          : state == _StatusStageState.completed
                          ? color.withValues(alpha: 0.45)
                          : const Color(0xFFC9CED6),
                    ),
                  ),
                  child: Icon(
                    current
                        ? Icons.circle
                        : state == _StatusStageState.completed
                        ? Icons.check_rounded
                        : Icons.circle_outlined,
                    size: current ? 8 : 13,
                    color: current
                        ? Colors.white
                        : state == _StatusStageState.completed
                        ? color
                        : AppColors.textSecondary,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 25,
                    color: state == _StatusStageState.completed
                        ? color.withValues(alpha: 0.28)
                        : const Color(0xFFE4E7EC),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      definition.nameRu,
                      style: TextStyle(
                        color: future
                            ? AppColors.textSecondary
                            : current
                            ? color
                            : AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        fontWeight: current ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    changedAt == null
                        ? future
                              ? 'Предстоит'
                              : 'Дата не зафиксирована'
                        : _formatStatusDate(changedAt!),
                    key: ValueKey(
                      'garage-status-stage-${definition.code}-date',
                    ),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
}

enum _StatusStageState { completed, current, future }

List<GarageRequestStatusDefinition> _definitions(
  List<GarageRequestStatusDefinition> statuses,
) {
  if (statuses.isEmpty) {
    return canonicalGarageRequestStatusOrder
        .map(
          (code) => GarageRequestStatusDefinition(
            code: code,
            nameRu: garageStatusLabel(code),
            color: null,
            sortOrder: canonicalGarageRequestStatusOrder.indexOf(code),
          ),
        )
        .toList(growable: false);
  }
  final definitions =
      statuses
          .where(
            (definition) =>
                canonicalGarageRequestStatuses.contains(definition.code),
          )
          .toList(growable: false)
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  return definitions;
}

Map<String, DateTime> _statusDates(GarageRequest request) {
  final dates = <String, DateTime>{};
  if (request.createdAt != null) {
    dates['draft'] = request.createdAt!;
  }
  if (request.submittedAt != null) {
    dates['new'] = request.submittedAt!;
  }
  for (final event in request.statusHistory) {
    final changedAt = event.changedAt;
    if (changedAt == null) continue;
    dates[canonicalGarageRequestStatus(event.status)] = changedAt;
  }
  if (request.cancelledAt != null) {
    dates['cancelled'] = request.cancelledAt!;
  }
  return dates;
}

int _lastReachedIndex(
  List<GarageRequestStatusDefinition> definitions,
  Map<String, DateTime> statusDates,
  int currentIndex,
) {
  if (currentIndex >= 0) return currentIndex;
  var lastReached = -1;
  for (var index = 0; index < definitions.length; index++) {
    if (statusDates.containsKey(definitions[index].code)) {
      lastReached = index;
    }
  }
  return lastReached;
}

Color _segmentColor(
  BuildContext context, {
  required int index,
  required int currentIndex,
  required int lastReachedIndex,
}) {
  if (index == currentIndex) return context.brandPrimary;
  if (index < currentIndex || (currentIndex < 0 && index <= lastReachedIndex)) {
    return context.brandPrimary.withValues(alpha: 0.55);
  }
  return const Color(0xFFE4E7EC);
}

_StatusStageState _stageState({
  required int index,
  required int currentIndex,
  required int lastReachedIndex,
}) {
  if (index == currentIndex) return _StatusStageState.current;
  if (index < currentIndex || (currentIndex < 0 && index <= lastReachedIndex)) {
    return _StatusStageState.completed;
  }
  return _StatusStageState.future;
}

String _formatStatusDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
