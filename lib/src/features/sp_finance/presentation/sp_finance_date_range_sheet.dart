import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import 'sp_finance_ui.dart';

Future<DateTimeRange?> showSpFinanceDateRangeSheet({
  required BuildContext context,
  required String title,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  DateTime? initialCalendarDate,
  String? subtitle,
  String startLabel = 'Дата начала',
  String endLabel = 'Дата окончания',
  String cancelText = 'Отмена',
  String confirmText = 'Применить',
}) {
  return showSpFinanceModalSheet<DateTimeRange>(
    context: context,
    builder: (context) => SpFinanceDateRangeSheet(
      title: title,
      subtitle: subtitle,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateRange,
      initialCalendarDate: initialCalendarDate,
      startLabel: startLabel,
      endLabel: endLabel,
      cancelText: cancelText,
      confirmText: confirmText,
    ),
  );
}

class SpFinanceDateRangeSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialDateRange;
  final DateTime? initialCalendarDate;
  final String startLabel;
  final String endLabel;
  final String cancelText;
  final String confirmText;

  SpFinanceDateRangeSheet({
    super.key,
    required this.title,
    required this.firstDate,
    required this.lastDate,
    required this.startLabel,
    required this.endLabel,
    required this.cancelText,
    required this.confirmText,
    this.subtitle,
    this.initialDateRange,
    this.initialCalendarDate,
  }) : assert(!lastDate.isBefore(firstDate));

  @override
  State<SpFinanceDateRangeSheet> createState() =>
      _SpFinanceDateRangeSheetState();
}

class _SpFinanceDateRangeSheetState extends State<SpFinanceDateRangeSheet> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _calendarDate;
  bool _selectingEnd = false;

  @override
  void initState() {
    super.initState();
    final initialStart = widget.initialDateRange?.start;
    final initialEnd = widget.initialDateRange?.end;
    _start = initialStart == null ? null : _clampDate(initialStart);
    _end = initialEnd == null ? null : _clampDate(initialEnd);
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      _end = _start;
    }
    _calendarDate = _clampDate(
      widget.initialCalendarDate ?? _start ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SpFinanceModalSurface(
      key: const ValueKey('sp-finance-date-range-sheet'),
      icon: Icons.date_range_rounded,
      title: widget.title,
      subtitle:
          widget.subtitle ?? 'Сначала выберите начало, затем окончание периода',
      contentPadding: EdgeInsets.zero,
      maxHeightFactor: 1,
      body: SingleChildScrollView(
        key: const ValueKey('sp-date-range-scroll'),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _DateSelectionCard(
                      key: const ValueKey('sp-date-range-start'),
                      label: widget.startLabel,
                      date: _start,
                      selected: !_selectingEnd,
                      onTap: () => setState(() => _selectingEnd = false),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: _DateSelectionCard(
                      key: const ValueKey('sp-date-range-end'),
                      label: widget.endLabel,
                      date: _end,
                      selected: _selectingEnd,
                      onTap: () => setState(() => _selectingEnd = true),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: SpFinanceUi.cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: _calendarTheme(context),
                  child: CalendarDatePicker(
                    key: ValueKey(
                      '${_calendarDate.millisecondsSinceEpoch}-$_selectingEnd',
                    ),
                    initialDate: _calendarDate,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    currentDate: DateTime.now(),
                    onDateChanged: _selectDate,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: Color(0xFFE1E5ED)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(widget.cancelText),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const ValueKey('sp-date-range-confirm'),
              onPressed: _start == null || _end == null ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: context.brandPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE1E5ED),
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(widget.confirmText),
            ),
          ),
        ],
      ),
    );
  }

  ThemeData _calendarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: context.brandPrimary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: Colors.white,
        headerForegroundColor: AppColors.textPrimary,
        weekdayStyle: TextStyle(
          fontFamily: 'Gilroy',
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
        dayStyle: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700),
        yearStyle: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800),
      ),
    );
  }

  void _selectDate(DateTime date) {
    final selected = DateUtils.dateOnly(date);
    setState(() {
      _calendarDate = selected;
      if (!_selectingEnd || _start == null) {
        _start = selected;
        if (_end != null && selected.isAfter(_end!)) {
          _end = null;
        }
        _selectingEnd = true;
        return;
      }

      if (selected.isBefore(_start!)) {
        _start = selected;
        _end = null;
        _selectingEnd = true;
        return;
      }

      _end = selected;
      _selectingEnd = false;
    });
  }

  DateTime _clampDate(DateTime date) {
    final selected = DateUtils.dateOnly(date);
    final first = DateUtils.dateOnly(widget.firstDate);
    final last = DateUtils.dateOnly(widget.lastDate);
    if (selected.isBefore(first)) return first;
    if (selected.isAfter(last)) return last;
    return selected;
  }

  void _submit() {
    Navigator.of(context).pop(DateTimeRange(start: _start!, end: _end!));
  }
}

class _DateSelectionCard extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool selected;
  final VoidCallback onTap;

  const _DateSelectionCard({
    super.key,
    required this.label,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.brandPrimary.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? context.brandPrimary.withValues(alpha: 0.35)
                  : const Color(0xFFE1E5ED),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date == null
                    ? 'Выберите'
                    : DateFormat('dd.MM.yyyy').format(date!),
                maxLines: 1,
                style: TextStyle(
                  color: date == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
