import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_export_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_export_xlsx.dart';

void main() {
  final export = SpOrganizerPurchaseExport.fromJson({
    'contractVersion': 1,
    'mode': 'read_only',
    'persisted': false,
    'fileName': 'sp_purchase_17_2026-07-27.xlsx',
    'purchase': {
      'id': 17,
      'title': 'Закупка июля',
      'statusLabel': 'Сбор оплат',
      'currency': 'CNY',
    },
    'summary': {
      'itemsCount': 1,
      'customersCount': 1,
      'totalDueRub': '325',
      'paidRub': 100,
      'totalProfitRub': '65',
    },
    'columns': [
      {
        'key': 'itemId',
        'labelRu': 'ID товара',
        'labelZh': '商品ID',
        'type': 'integer',
      },
      {'key': 'title', 'labelRu': 'Товар', 'labelZh': '商品', 'type': 'text'},
      {
        'key': 'totalDueRub',
        'labelRu': 'К оплате, ₽',
        'labelZh': '应付, ₽',
        'type': 'money',
      },
    ],
    'rows': [
      {
        'itemId': '41',
        'title': '=HYPERLINK("unsafe")',
        'totalDueRub': '325,50',
      },
    ],
    'totalRows': '1',
    'warnings': ['no_private_media_or_payment_requisites'],
  });

  test('server export DTO preserves ordered columns and rows', () {
    expect(export.mode, 'read_only');
    expect(export.persisted, isFalse);
    expect(export.totalRows, 1);
    expect(export.columns.map((column) => column.key), [
      'itemId',
      'title',
      'totalDueRub',
    ]);
    expect(export.columns[1].labelFor('zh'), '商品');
    expect(export.rows.single['itemId'], '41');
  });

  test('xlsx builder emits a workbook for RU and ZH labels', () {
    final ru = buildSpOrganizerPurchaseXlsx(export, languageCode: 'ru');
    final zh = buildSpOrganizerPurchaseXlsx(export, languageCode: 'zh');

    expect(ru.length, greaterThan(500));
    expect(zh.length, greaterThan(500));
    expect(ru.take(2), [0x50, 0x4B]);
    expect(zh.take(2), [0x50, 0x4B]);
  });
}
