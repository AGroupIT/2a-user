import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/xlsx_image_embedder.dart';

void main() {
  test('добавляет изображение и drawing relationship в xlsx', () {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Треки');
    excel['Треки'].appendRow([TextCellValue('Фото')]);
    final workbook = excel.encode()!;

    final result = embedImagesIntoFirstXlsxSheet(workbook, [
      XlsxEmbeddedImage(
        bytes: Uint8List.fromList(_onePixelPng),
        extension: 'png',
        column: 0,
        row: 1,
      ),
    ]);
    final archive = ZipDecoder().decodeBytes(result);

    expect(archive.findFile('xl/media/track_export_1.png'), isNotNull);
    expect(archive.findFile('xl/drawings/drawing1.xml'), isNotNull);
    final sheetXml = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
    );
    expect(sheetXml, contains('rIdTrackExportImages'));
    expect(sheetXml, contains('xmlns:r='));
  });
}

const _onePixelPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
