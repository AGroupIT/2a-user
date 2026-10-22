import 'package:twoalogisticcabineuser/src/core/media/authenticated_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/locale_text.dart';
import 'blurred_media_backdrop.dart';
import 'app_cached_media_image.dart';
import 'media_image_viewport.dart';

void showFullscreenImageOverlay({
  required BuildContext context,
  required String imageUrl,
  required String fileName,
  required VoidCallback onDownload,
}) {
  late OverlayEntry imageOverlay;
  imageOverlay = OverlayEntry(
    builder: (context) => _FullscreenImageOverlay(
      imageUrl: imageUrl,
      fileName: fileName,
      onDownload: onDownload,
      onClose: imageOverlay.remove,
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(imageOverlay);
}

class _FullscreenImageOverlay extends StatefulWidget {
  final String imageUrl;
  final String fileName;
  final VoidCallback onDownload;
  final VoidCallback onClose;

  const _FullscreenImageOverlay({
    required this.imageUrl,
    required this.fileName,
    required this.onDownload,
    required this.onClose,
  });

  @override
  State<_FullscreenImageOverlay> createState() =>
      _FullscreenImageOverlayState();
}

class _FullscreenImageOverlayState extends State<_FullscreenImageOverlay> {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
      ),
      child: Material(
        color: Colors.transparent,
        child: BlurredMediaBackdrop(
          imageUrl: widget.imageUrl,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: widget.onClose,
              ),
              title: Text(
                widget.fileName,
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: tr(context, ru: 'Скачать', zh: '下载'),
                  onPressed: widget.onDownload,
                ),
              ],
            ),
            body: MediaImageViewport(
              imageKey: widget.imageUrl,
              onDismiss: widget.onClose,
              child: AuthenticatedCachedImage(
                imageUrl: widget.imageUrl,
                memCacheWidth: 3072,
                memCacheHeight: 3072,
                fit: BoxFit.contain,
                placeholder: (context, url) => AppCachedMediaImage(
                  url: widget.imageUrl,
                  thumbnailSize: 720,
                  memCacheWidth: 720,
                  memCacheHeight: 720,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr(
                          context,
                          ru: 'Не удалось загрузить изображение',
                          zh: '无法加载图片',
                        ),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
