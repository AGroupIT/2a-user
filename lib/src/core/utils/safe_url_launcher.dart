import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const _allowedExternalSchemes = {
  'http',
  'https',
  'tel',
  'mailto',
  'tg',
  'whatsapp',
};

/// Opens only real external URLs/deep-links.
///
/// Android throws FileUriExposedException when a local `file://`/sandbox path is
/// passed to url_launcher. Chat/markdown content can contain uploaded local
/// paths while a message is still being prepared, so local paths are ignored
/// instead of being handed to the platform intent layer.
Future<bool> launchSafeExternalUrl(String? value) async {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;

  final uri = Uri.tryParse(raw);
  if (uri == null || !_allowedExternalSchemes.contains(uri.scheme)) {
    debugPrint('[SafeUrlLauncher] Ignored non-external URL: $raw');
    return false;
  }

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
