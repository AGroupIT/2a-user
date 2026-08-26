import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class XlsxEmbeddedImage {
  final Uint8List bytes;
  final String extension;
  final int column;
  final int row;
  final int widthPixels;
  final int heightPixels;
  final int columnOffsetPixels;
  final int rowOffsetPixels;

  const XlsxEmbeddedImage({
    required this.bytes,
    required this.extension,
    required this.column,
    required this.row,
    this.widthPixels = 88,
    this.heightPixels = 66,
    this.columnOffsetPixels = 4,
    this.rowOffsetPixels = 4,
  });
}

Uint8List embedImagesIntoFirstXlsxSheet(
  List<int> workbookBytes,
  List<XlsxEmbeddedImage> images,
) {
  if (images.isEmpty) return Uint8List.fromList(workbookBytes);

  final source = ZipDecoder().decodeBytes(workbookBytes);
  final result = Archive();
  for (final file in source.files) {
    if (!file.isFile) continue;
    final content = file.content as List<int>;
    result.addFile(ArchiveFile(file.name, content.length, content));
  }

  _replaceTextFile(
    result,
    'xl/worksheets/sheet1.xml',
    (xml) => xml.contains('<drawing ')
        ? xml
        : xml.replaceFirst(
            '</worksheet>',
            '<drawing r:id="rIdTrackExportImages"/></worksheet>',
          ),
  );
  _replaceTextFile(result, '[Content_Types].xml', (xml) {
    var updated = xml;
    if (!updated.contains('Extension="png"')) {
      updated = updated.replaceFirst(
        '</Types>',
        '<Default Extension="png" ContentType="image/png"/></Types>',
      );
    }
    if (!updated.contains('Extension="jpeg"')) {
      updated = updated.replaceFirst(
        '</Types>',
        '<Default Extension="jpeg" ContentType="image/jpeg"/></Types>',
      );
    }
    if (!updated.contains('Extension="webp"')) {
      updated = updated.replaceFirst(
        '</Types>',
        '<Default Extension="webp" ContentType="image/webp"/></Types>',
      );
    }
    if (!updated.contains('/xl/drawings/drawing1.xml')) {
      updated = updated.replaceFirst(
        '</Types>',
        '<Override PartName="/xl/drawings/drawing1.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>'
            '</Types>',
      );
    }
    return updated;
  });

  const sheetRelsPath = 'xl/worksheets/_rels/sheet1.xml.rels';
  final existingRels = result.findFile(sheetRelsPath);
  final relsXml = existingRels == null
      ? '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rIdTrackExportImages" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" '
            'Target="../drawings/drawing1.xml"/>'
            '</Relationships>'
      : utf8
            .decode(existingRels.content as List<int>)
            .replaceFirst(
              '</Relationships>',
              '<Relationship Id="rIdTrackExportImages" '
                  'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" '
                  'Target="../drawings/drawing1.xml"/>'
                  '</Relationships>',
            );
  _putTextFile(result, sheetRelsPath, relsXml);

  final drawing = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
  );
  final drawingRels = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );

  for (var index = 0; index < images.length; index++) {
    final image = images[index];
    final imageId = index + 1;
    final extension = switch (image.extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };
    final fileName = 'track_export_$imageId.$extension';
    result.addFile(
      ArchiveFile('xl/media/$fileName', image.bytes.length, image.bytes),
    );
    drawingRels.write(
      '<Relationship Id="rId$imageId" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
      'Target="../media/$fileName"/>',
    );
    drawing.write(_drawingAnchor(image, imageId));
  }

  drawing.write('</xdr:wsDr>');
  drawingRels.write('</Relationships>');
  _putTextFile(result, 'xl/drawings/drawing1.xml', drawing.toString());
  _putTextFile(
    result,
    'xl/drawings/_rels/drawing1.xml.rels',
    drawingRels.toString(),
  );

  return Uint8List.fromList(ZipEncoder().encode(result)!);
}

String _drawingAnchor(XlsxEmbeddedImage image, int imageId) {
  const emuPerPixel = 9525;
  return '<xdr:oneCellAnchor>'
      '<xdr:from><xdr:col>${image.column}</xdr:col>'
      '<xdr:colOff>${image.columnOffsetPixels * emuPerPixel}</xdr:colOff>'
      '<xdr:row>${image.row}</xdr:row>'
      '<xdr:rowOff>${image.rowOffsetPixels * emuPerPixel}</xdr:rowOff></xdr:from>'
      '<xdr:ext cx="${image.widthPixels * emuPerPixel}" cy="${image.heightPixels * emuPerPixel}"/>'
      '<xdr:pic><xdr:nvPicPr><xdr:cNvPr id="$imageId" name="Фото $imageId"/>'
      '<xdr:cNvPicPr/></xdr:nvPicPr><xdr:blipFill><a:blip r:embed="rId$imageId"/>'
      '<a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
      '<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic>'
      '<xdr:clientData/></xdr:oneCellAnchor>';
}

void _replaceTextFile(
  Archive archive,
  String path,
  String Function(String xml) transform,
) {
  final file = archive.findFile(path);
  if (file == null) {
    throw StateError('В XLSX отсутствует обязательный файл $path');
  }
  _putTextFile(
    archive,
    path,
    transform(utf8.decode(file.content as List<int>)),
  );
}

void _putTextFile(Archive archive, String path, String content) {
  final bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(path, bytes.length, bytes));
}
