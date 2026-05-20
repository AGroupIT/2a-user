import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/locale_text.dart';
import 'blurred_media_backdrop.dart';

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
  static const _dismissDistance = 100.0;
  static const _defaultScaleTolerance = 1.05;

  final _transformationController = TransformationController();
  double _swipeDy = 0;

  bool get _isAtDefaultScale =>
      _transformationController.value.getMaxScaleOnAxis() <=
      _defaultScaleTolerance;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isAtDefaultScale) return;
    setState(() {
      _swipeDy += details.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_swipeDy.abs() > _dismissDistance) {
      widget.onClose();
      return;
    }

    setState(() {
      _swipeDy = 0;
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

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
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              child: Transform.translate(
                offset: Offset(0, _swipeDy),
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
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
          ),
        ),
      ),
    );
  }
}
