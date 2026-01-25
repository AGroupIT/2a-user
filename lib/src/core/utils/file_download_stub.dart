import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// Stub implementation - should never be called
Future<bool> downloadFileImpl({
  required Uint8List bytes,
  required String fileName,
  GlobalKey? shareButtonKey,
}) async {
  throw UnimplementedError('Cannot download file on this platform');
}
