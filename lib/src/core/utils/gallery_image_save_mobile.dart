import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';

import 'file_download_mobile.dart';

Future<bool> saveImageToGalleryImpl({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    // У Linux нет системной фотогалереи и официальной реализации Gal.
    if (Platform.isLinux) {
      return downloadFileImpl(bytes: bytes, fileName: fileName);
    }

    final hasAccess = await Gal.hasAccess();
    if (!hasAccess && !await Gal.requestAccess()) {
      return false;
    }

    final nameWithoutExtension = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    await Gal.putImageBytes(
      bytes,
      name: nameWithoutExtension.isEmpty
          ? '2a_payment_qr'
          : nameWithoutExtension,
    );
    return true;
  } catch (_) {
    return false;
  }
}
