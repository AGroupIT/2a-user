import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import 'sp_organizer_export_models.dart';

Uint8List buildSpOrganizerPurchaseXlsx(
  SpOrganizerPurchaseExport export, {
  required String languageCode,
}) {
  final excel = xls.Excel.createExcel();
  final summarySheet = excel[languageCode == 'zh' ? '汇总' : 'Сводка'];
  final itemsSheet = excel[languageCode == 'zh' ? '商品' : 'Товары'];

  void summaryRow(String ru, String zh, Object? value) {
    summarySheet.appendRow([
      xls.TextCellValue(languageCode == 'zh' ? zh : ru),
      _cellValue(value, 'text'),
    ]);
  }

  summaryRow('Закупка', '采购', export.purchase['title']?.toString() ?? '');
  summaryRow('Статус', '状态', export.purchase['statusLabel']?.toString() ?? '');
  summaryRow('Валюта', '币种', export.purchase['currency']?.toString() ?? '');
  summaryRow(
    'Товаров',
    '商品数',
    export.summary['itemsCount'] ?? export.totalRows,
  );
  summaryRow('Клиентов', '客户数', export.summary['customersCount'] ?? 0);
  summaryRow('К оплате, ₽', '应付, ₽', export.summary['totalDueRub'] ?? 0);
  summaryRow('Оплачено, ₽', '已付, ₽', export.summary['paidRub'] ?? 0);
  summaryRow(
    'Расчётная прибыль, ₽',
    '预计利润, ₽',
    export.summary['totalProfitRub'] ?? 0,
  );

  itemsSheet.appendRow(
    export.columns
        .map((column) => xls.TextCellValue(column.labelFor(languageCode)))
        .toList(growable: false),
  );
  for (final row in export.rows) {
    final values = export.columns
        .map((column) => _cellValue(row[column.key], column.type))
        .toList(growable: false);
    assert(values.length == export.columns.length);
    itemsSheet.appendRow(values);
  }
  for (var index = 0; index < export.columns.length; index += 1) {
    final label = export.columns[index].labelFor(languageCode);
    final width = (label.length + 4).clamp(12, 28).toDouble();
    itemsSheet.setColumnWidth(index, width);
  }
  summarySheet.setColumnWidth(0, 26);
  summarySheet.setColumnWidth(1, 28);

  excel.delete('Sheet1');
  final bytes = excel.encode();
  if (bytes == null || bytes.isEmpty) {
    throw StateError('SP export workbook encoding failed');
  }
  return Uint8List.fromList(bytes);
}

xls.CellValue _cellValue(Object? value, String type) {
  if (value == null) return xls.TextCellValue('');
  if (type == 'integer') {
    if (value is num) return xls.IntCellValue(value.toInt());
    final parsed = int.tryParse(value.toString());
    return parsed == null
        ? xls.TextCellValue(value.toString())
        : xls.IntCellValue(parsed);
  }
  if (type == 'money' || type == 'decimal') {
    if (value is num) return xls.DoubleCellValue(value.toDouble());
    final parsed = double.tryParse(value.toString().replaceAll(',', '.'));
    return parsed == null
        ? xls.TextCellValue(value.toString())
        : xls.DoubleCellValue(parsed);
  }
  return xls.TextCellValue(value.toString());
}
