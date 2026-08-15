import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import 'sp_finance_ui.dart';

enum SpPurchaseCreationStage { forming, inTransit, delivered }

class SpPurchaseCreationTimelineValue {
  final SpPurchaseCreationStage stage;
  final DateTime startedAt;
  final DateTime? dispatchedFromChinaAt;
  final DateTime? completedAt;

  const SpPurchaseCreationTimelineValue({
    required this.stage,
    required this.startedAt,
    this.dispatchedFromChinaAt,
    this.completedAt,
  });

  factory SpPurchaseCreationTimelineValue.initial([DateTime? now]) {
    final value = now ?? DateTime.now();
    return SpPurchaseCreationTimelineValue(
      stage: SpPurchaseCreationStage.forming,
      startedAt: _calendarDate(value),
    );
  }

  factory SpPurchaseCreationTimelineValue.fromExisting({
    required String status,
    DateTime? startedAt,
    DateTime? dispatchedFromChinaAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final stage = spPurchaseCreationStageForStatus(status);
    final started = _calendarDate(
      startedAt ?? createdAt ?? updatedAt ?? DateTime.now(),
    );
    final dispatched = stage.index >= SpPurchaseCreationStage.inTransit.index
        ? _calendarDate(dispatchedFromChinaAt ?? updatedAt ?? started)
        : null;
    final completed = stage == SpPurchaseCreationStage.delivered
        ? _calendarDate(completedAt ?? updatedAt ?? dispatched ?? started)
        : null;
    return SpPurchaseCreationTimelineValue(
      stage: stage,
      startedAt: started,
      dispatchedFromChinaAt: dispatched,
      completedAt: completed,
    );
  }

  String get backendStatus => switch (stage) {
    SpPurchaseCreationStage.forming => 'open',
    SpPurchaseCreationStage.inTransit => 'in_transit',
    SpPurchaseCreationStage.delivered => 'completed',
  };

  bool get canGoBack => stage != SpPurchaseCreationStage.forming;
  bool get canAdvance => stage != SpPurchaseCreationStage.delivered;

  SpPurchaseCreationTimelineValue advance([DateTime? now]) {
    final today = _calendarDate(now ?? DateTime.now());
    return switch (stage) {
      SpPurchaseCreationStage.forming => SpPurchaseCreationTimelineValue(
        stage: SpPurchaseCreationStage.inTransit,
        startedAt: startedAt,
        dispatchedFromChinaAt: _latestDate(today, startedAt),
      ),
      SpPurchaseCreationStage.inTransit => SpPurchaseCreationTimelineValue(
        stage: SpPurchaseCreationStage.delivered,
        startedAt: startedAt,
        dispatchedFromChinaAt: dispatchedFromChinaAt,
        completedAt: _latestDate(today, dispatchedFromChinaAt ?? startedAt),
      ),
      SpPurchaseCreationStage.delivered => this,
    };
  }

  SpPurchaseCreationTimelineValue retreat() {
    return switch (stage) {
      SpPurchaseCreationStage.forming => this,
      SpPurchaseCreationStage.inTransit => SpPurchaseCreationTimelineValue(
        stage: SpPurchaseCreationStage.forming,
        startedAt: startedAt,
      ),
      SpPurchaseCreationStage.delivered => SpPurchaseCreationTimelineValue(
        stage: SpPurchaseCreationStage.inTransit,
        startedAt: startedAt,
        dispatchedFromChinaAt: dispatchedFromChinaAt,
      ),
    };
  }

  SpPurchaseCreationTimelineValue withStartedAt(DateTime value) {
    return SpPurchaseCreationTimelineValue(
      stage: stage,
      startedAt: _calendarDate(value),
      dispatchedFromChinaAt: dispatchedFromChinaAt,
      completedAt: completedAt,
    );
  }

  SpPurchaseCreationTimelineValue withDispatchedAt(DateTime value) {
    return SpPurchaseCreationTimelineValue(
      stage: stage,
      startedAt: startedAt,
      dispatchedFromChinaAt: _calendarDate(value),
      completedAt: completedAt,
    );
  }

  SpPurchaseCreationTimelineValue withCompletedAt(DateTime value) {
    return SpPurchaseCreationTimelineValue(
      stage: stage,
      startedAt: startedAt,
      dispatchedFromChinaAt: dispatchedFromChinaAt,
      completedAt: _calendarDate(value),
    );
  }
}

SpPurchaseCreationStage spPurchaseCreationStageForStatus(String status) {
  return switch (status) {
    'in_transit' => SpPurchaseCreationStage.inTransit,
    'arrived_msk' ||
    'sorting' ||
    'calculating' ||
    'collecting_payments' ||
    'shipping_to_customers' ||
    'completed' => SpPurchaseCreationStage.delivered,
    _ => SpPurchaseCreationStage.forming,
  };
}

class SpPurchaseLifecycleSummary extends StatelessWidget {
  final SpPurchaseCreationStage currentStage;
  final DateTime? startedAt;
  final DateTime? dispatchedFromChinaAt;
  final DateTime? completedAt;

  const SpPurchaseLifecycleSummary({
    super.key,
    required this.currentStage,
    this.startedAt,
    this.dispatchedFromChinaAt,
    this.completedAt,
  });

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Создана', startedAt),
      ('Отправлена', dispatchedFromChinaAt),
      ('Получена', completedAt),
    ];
    return Semantics(
      label: 'Этапы и даты закупки',
      child: Row(
        key: const Key('sp-purchase-lifecycle-summary'),
        children: [
          for (var index = 0; index < stages.length; index++) ...[
            Expanded(
              child: _LifecycleSummaryStage(
                label: stages[index].$1,
                date: stages[index].$2,
                active: index <= currentStage.index,
              ),
            ),
            if (index < stages.length - 1)
              Container(
                width: 10,
                height: 2,
                color: index < currentStage.index
                    ? context.brandPrimary.withValues(alpha: 0.38)
                    : const Color(0xFFE1E5ED),
              ),
          ],
        ],
      ),
    );
  }
}

class _LifecycleSummaryStage extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool active;

  const _LifecycleSummaryStage({
    required this.label,
    required this.date,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.10)
                : const Color(0xFFF1F3F6),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? accent : const Color(0xFFD9DEE7),
            ),
          ),
          child: Icon(
            active ? Icons.check_rounded : Icons.more_horiz_rounded,
            size: 14,
            color: active ? accent : const Color(0xFFADB4C0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? AppColors.textPrimary : const Color(0xFFADB4C0),
            fontFamily: 'Gilroy',
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          date == null ? '—' : DateFormat('dd.MM.yy').format(date!),
          maxLines: 1,
          style: TextStyle(
            color: active ? AppColors.textSecondary : const Color(0xFFB8BEC8),
            fontFamily: 'Gilroy',
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class SpPurchaseStatusDatesEditor extends StatelessWidget {
  final SpPurchaseCreationTimelineValue value;
  final ValueChanged<SpPurchaseCreationTimelineValue> onChanged;

  const SpPurchaseStatusDatesEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sp-purchase-status-dates'),
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.cardDecoration(color: const Color(0xFFFBFCFE)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: context.brandPrimary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Статус и даты',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Можно сразу создать СП на нужном этапе',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TimelineRow(
            step: 0,
            currentStep: value.stage.index,
            title: 'Формируется',
            dateLabel: 'Дата создания',
            date: value.startedAt,
            enabled: true,
            showConnector: true,
            onDateTap: () => _pickStartedAt(context),
          ),
          _TimelineRow(
            step: 1,
            currentStep: value.stage.index,
            title: 'В пути',
            dateLabel: 'Дата отправки со склада',
            date: value.dispatchedFromChinaAt,
            enabled: value.stage.index >= 1,
            showConnector: true,
            onDateTap: () => _pickDispatchedAt(context),
          ),
          _TimelineRow(
            step: 2,
            currentStep: value.stage.index,
            title: 'Доставлена',
            dateLabel: 'Дата получения',
            date: value.completedAt,
            enabled: value.stage.index >= 2,
            showConnector: false,
            onDateTap: () => _pickCompletedAt(context),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('sp-purchase-status-back'),
                  onPressed: value.canGoBack
                      ? () => onChanged(value.retreat())
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Назад'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brandPrimary,
                    minimumSize: const Size.fromHeight(46),
                    side: BorderSide(
                      color: context.brandPrimary.withValues(alpha: 0.22),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('sp-purchase-status-next'),
                  onPressed: value.canAdvance
                      ? () => onChanged(value.advance())
                      : null,
                  icon: Icon(
                    value.stage == SpPurchaseCreationStage.forming
                        ? Icons.local_shipping_outlined
                        : Icons.inventory_2_outlined,
                    size: 18,
                  ),
                  label: Text(switch (value.stage) {
                    SpPurchaseCreationStage.forming => 'Отправить',
                    SpPurchaseCreationStage.inTransit => 'Доставить',
                    SpPurchaseCreationStage.delivered => 'Доставлена',
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brandPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE8EBF0),
                    disabledForegroundColor: AppColors.textSecondary,
                    minimumSize: const Size.fromHeight(46),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartedAt(BuildContext context) async {
    final date = await _pickDate(
      context,
      initialDate: value.startedAt,
      firstDate: DateTime(2000),
      lastDate:
          value.dispatchedFromChinaAt ??
          value.completedAt ??
          DateTime(2100, 12, 31),
    );
    if (!context.mounted || date == null) return;
    onChanged(value.withStartedAt(date));
  }

  Future<void> _pickDispatchedAt(BuildContext context) async {
    final current = value.dispatchedFromChinaAt;
    if (current == null) return;
    final date = await _pickDate(
      context,
      initialDate: current,
      firstDate: value.startedAt,
      lastDate: value.completedAt ?? DateTime(2100, 12, 31),
    );
    if (!context.mounted || date == null) return;
    onChanged(value.withDispatchedAt(date));
  }

  Future<void> _pickCompletedAt(BuildContext context) async {
    final current = value.completedAt;
    if (current == null) return;
    final date = await _pickDate(
      context,
      initialDate: current,
      firstDate: value.dispatchedFromChinaAt ?? value.startedAt,
      lastDate: DateTime(2100, 12, 31),
    );
    if (!context.mounted || date == null) return;
    onChanged(value.withCompletedAt(date));
  }

  Future<DateTime?> _pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: context.brandPrimary),
        ),
        child: child!,
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final int step;
  final int currentStep;
  final String title;
  final String dateLabel;
  final DateTime? date;
  final bool enabled;
  final bool showConnector;
  final VoidCallback onDateTap;

  const _TimelineRow({
    required this.step,
    required this.currentStep,
    required this.title,
    required this.dateLabel,
    required this.date,
    required this.enabled,
    required this.showConnector,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = step == currentStep;
    final isCompleted = step < currentStep;
    final accent = context.brandPrimary;
    final markerColor = enabled ? accent : const Color(0xFFD9DEE7);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: enabled
                        ? accent.withValues(alpha: isCurrent ? 1 : 0.10)
                        : const Color(0xFFF0F2F5),
                    shape: BoxShape.circle,
                    border: Border.all(color: markerColor, width: 1.5),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : _stageIcon(step),
                    size: 15,
                    color: isCurrent
                        ? Colors.white
                        : enabled
                        ? accent
                        : const Color(0xFFADB4C0),
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: step < currentStep
                          ? accent.withValues(alpha: 0.35)
                          : const Color(0xFFE3E6EC),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: enabled
                          ? AppColors.textPrimary
                          : const Color(0xFFADB4C0),
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: enabled ? Colors.white : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      key: Key('sp-purchase-date-$step'),
                      onTap: enabled ? onDateTap : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: enabled
                                ? const Color(0xFFE1E5ED)
                                : const Color(0xFFE8EBF0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 17,
                              color: enabled ? accent : const Color(0xFFB8BEC8),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateLabel,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Gilroy',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    date == null
                                        ? 'Не указана'
                                        : DateFormat(
                                            'dd.MM.yyyy',
                                          ).format(date!),
                                    style: TextStyle(
                                      color: enabled
                                          ? AppColors.textPrimary
                                          : const Color(0xFFADB4C0),
                                      fontFamily: 'Gilroy',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: enabled
                                  ? const Color(0xFF9BA2AE)
                                  : const Color(0xFFC7CCD4),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
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

  IconData _stageIcon(int step) => switch (step) {
    0 => Icons.add_shopping_cart_rounded,
    1 => Icons.local_shipping_outlined,
    _ => Icons.inventory_2_outlined,
  };
}

DateTime _calendarDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _latestDate(DateTime left, DateTime right) {
  return left.isBefore(right) ? right : left;
}
