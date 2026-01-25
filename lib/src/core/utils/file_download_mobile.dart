import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile implementation - saves to temp and shares
Future<bool> downloadFileImpl({
  required Uint8List bytes,
  required String fileName,
  GlobalKey? shareButtonKey,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);

    // Get share position from button key (for iPad)
    Rect? sharePositionOrigin;
    if (shareButtonKey != null) {
      final renderBox = shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        sharePositionOrigin = Rect.fromLTWH(
          position.dx,
          position.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
      }
    }

    final result = await Share.shareXFiles(
      [XFile(tempFile.path)],
      sharePositionOrigin: sharePositionOrigin,
    );

    return result.status == ShareResultStatus.success;
  } catch (e) {
    return false;
  }
}
