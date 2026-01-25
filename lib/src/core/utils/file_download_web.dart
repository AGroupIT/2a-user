// TODO: Migrate to package:web when Flutter ecosystem fully supports it
// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// Web implementation - downloads file using HTML anchor element
Future<bool> downloadFileImpl({
  required Uint8List bytes,
  required String fileName,
  GlobalKey? shareButtonKey,
}) async {
  try {
    // Create blob from bytes
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Create anchor element and trigger download
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();

    // Cleanup
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    return true;
  } catch (e) {
    return false;
  }
}
