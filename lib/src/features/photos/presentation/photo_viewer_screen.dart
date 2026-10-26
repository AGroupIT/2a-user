import '../../../core/network/api_client.dart';
import '../../../core/media/authenticated_video.dart';
import 'package:twoalogisticcabineuser/src/core/media/authenticated_media.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/utils/file_download_helper.dart';
import '../../../core/utils/locale_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../core/ui/media_loading_indicator.dart';
import 'report_video_controls.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

import '../../../core/network/api_config.dart';
import '../../../core/branding/company_branding_provider.dart';
import '../../../core/ui/blurred_media_backdrop.dart';
import '../../../core/ui/app_colors.dart';
import '../domain/photo_item.dart';

void _showStyledSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  AppToast.showFromSnackBar(
    context,
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: AppToast.hide,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFE53935) : context.brandPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
      duration: const Duration(seconds: 3),
    ),
  );
}

class PhotoViewerScreen extends ConsumerStatefulWidget {
  final PhotoItem item;
  final List<PhotoItem>? allPhotos;
  final int? initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.item,
    this.allPhotos,
    this.initialIndex,
  });

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  bool _isDownloading = false;
  double _swipeDy = 0;
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheAdjacentImages();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PhotoItem get _currentItem {
    if (widget.allPhotos != null && widget.allPhotos!.isNotEmpty) {
      return widget.allPhotos![_currentIndex];
    }
    return widget.item;
  }

  void _precacheAdjacentImages() {
    final items = widget.allPhotos != null && widget.allPhotos!.isNotEmpty
        ? widget.allPhotos!
        : <PhotoItem>[widget.item];
    if (items.length < 2) return;

    for (final index in <int>{_currentIndex - 1, _currentIndex + 1}) {
      if (index < 0 || index >= items.length) continue;
      final item = items[index];
      if (item.isVideo) continue;

      final fullUrl = ApiConfig.getMediaUrl(item.url);
      if (fullUrl.isEmpty) continue;

      unawaited(
        precacheImage(
          authenticatedImageProvider(context, fullUrl),
          context,
        ).catchError((_) {}),
      );
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _swipeDy += details.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    // Если свайп был больше 100 пикселей вверх или вниз
    if (_swipeDy.abs() > 100) {
      Navigator.of(context).pop();
    }
    // Возвращаем в исходное состояние
    setState(() {
      _swipeDy = 0;
    });
  }

  Future<void> _downloadMedia() async {
    setState(() => _isDownloading = true);
    try {
      final currentItem = _currentItem;

      if (kIsWeb) {
        final bytes = await loadMediaBytes(
          ref.read(apiClientProvider),
          ApiConfig.getMediaUrl(currentItem.url),
        );
        if (!mounted) return;
        final saved = await downloadFile(
          bytes: bytes,
          fileName:
              'media_${DateTime.now().microsecondsSinceEpoch}.${currentItem.isVideo ? 'mp4' : 'jpg'}',
        );
        if (!mounted) return;
        if (!saved) throw StateError('media_not_saved');
        _showStyledSnackBar(
          context,
          tr(context, ru: 'Файл сохранён', zh: '文件已保存'),
        );
        return;
      }

      // Запрашиваем разрешение на сохранение в галерею
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) {
            _showStyledSnackBar(
              context,
              'Нет разрешения на сохранение в галерею',
              isError: true,
            );
          }
          return;
        }
      }

      String savePath;
      final fullUrl = ApiConfig.getMediaUrl(currentItem.url);

      final bytes = await loadMediaBytes(ref.read(apiClientProvider), fullUrl);
      final tempDir = await getTemporaryDirectory();
      savePath =
          '${tempDir.path}/media_${DateTime.now().microsecondsSinceEpoch}.${currentItem.isVideo ? 'mp4' : 'jpg'}';
      await File(savePath).writeAsBytes(bytes);
      if (!mounted) return;

      // Сохраняем в галерею
      final companyName = ref.read(companyNameProvider);
      if (currentItem.isVideo) {
        await Gal.putVideo(savePath, album: companyName);
        // Удаляем временный файл только для видео
        try {
          await File(savePath).delete();
        } catch (_) {}
      } else {
        await Gal.putImage(savePath, album: companyName);
      }

      if (mounted) {
        _showStyledSnackBar(context, 'Сохранено в галерею');
      }
    } on DioException catch (e) {
      if (mounted) {
        String message = 'Ошибка загрузки';
        if (e.response?.statusCode == 403) {
          message = 'Нет доступа к файлу';
        } else if (e.response?.statusCode == 404) {
          message = 'Файл не найден';
        }
        _showStyledSnackBar(context, message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showStyledSnackBar(context, 'Не удалось сохранить', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _shareMedia(BuildContext context) async {
    try {
      final currentItem = _currentItem;
      final fullUrl = ApiConfig.getMediaUrl(currentItem.url);

      // Получаем box ДО async операций
      final box = context.findRenderObject() as RenderBox?;

      final bytes = await loadMediaBytes(ref.read(apiClientProvider), fullUrl);
      if (!mounted) return;

      // Шарим файл (sharePositionOrigin нужен для iPad)
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: currentItem.isVideo ? 'video/mp4' : 'image/jpeg',
            name:
                'media_${DateTime.now().microsecondsSinceEpoch}.${currentItem.isVideo ? 'mp4' : 'jpg'}',
          ),
        ],
        text: currentItem.trackingNumber != null
            ? 'Трек: ${currentItem.trackingNumber}'
            : null,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100),
      );
    } on DioException catch (e) {
      if (!context.mounted) return;
      String message = 'Ошибка';
      if (e.response?.statusCode == 403) {
        message = 'Нет доступа к файлу';
      } else if (e.response?.statusCode == 404) {
        message = 'Файл не найден';
      }
      _showStyledSnackBar(context, message, isError: true);
    } catch (e) {
      if (!context.mounted) return;
      _showStyledSnackBar(context, 'Не удалось поделиться', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiplePhotos =
        widget.allPhotos != null && widget.allPhotos!.length > 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: BlurredMediaBackdrop(
          imageUrl: _currentItem.isVideo
              ? null
              : ApiConfig.getMediaUrl(_currentItem.url),
          child: Stack(
            children: [
              Positioned.fill(
                child: hasMultiplePhotos
                    ? PageView.builder(
                        controller: _pageController,
                        itemCount: widget.allPhotos!.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                          _precacheAdjacentImages();
                        },
                        itemBuilder: (context, index) {
                          final item = widget.allPhotos![index];
                          return GestureDetector(
                            onVerticalDragUpdate: _onVerticalDragUpdate,
                            onVerticalDragEnd: _onVerticalDragEnd,
                            child: Transform.translate(
                              offset: Offset(0, _swipeDy),
                              child: Center(
                                child: item.isVideo
                                    ? _VideoPlayerView(
                                        key: ValueKey(item.url),
                                        active: index == _currentIndex,
                                        url: ApiConfig.getMediaUrl(item.url),
                                      )
                                    : InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: AuthenticatedCachedImage(
                                          imageUrl: ApiConfig.getMediaUrl(
                                            item.url,
                                          ),
                                          fit: BoxFit.contain,
                                          progressIndicatorBuilder:
                                              (_, _, progress) =>
                                                  MediaLoadingIndicator(
                                                    progress: progress,
                                                  ),
                                          errorWidget: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white70,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      )
                    : GestureDetector(
                        onVerticalDragUpdate: _onVerticalDragUpdate,
                        onVerticalDragEnd: _onVerticalDragEnd,
                        child: Transform.translate(
                          offset: Offset(0, _swipeDy),
                          child: Center(
                            child: widget.item.isVideo
                                ? _VideoPlayerView(
                                    url: ApiConfig.getMediaUrl(widget.item.url),
                                  )
                                : InteractiveViewer(
                                    minScale: 1,
                                    maxScale: 4,
                                    child: AuthenticatedCachedImage(
                                      imageUrl: ApiConfig.getMediaUrl(
                                        widget.item.url,
                                      ),
                                      fit: BoxFit.contain,
                                      progressIndicatorBuilder:
                                          (_, _, progress) =>
                                              MediaLoadingIndicator(
                                                progress: progress,
                                              ),
                                      errorWidget: (_, _, _) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white70,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
              ),
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 8,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                      const Spacer(),
                      if (hasMultiplePhotos)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.allPhotos!.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (hasMultiplePhotos) const Spacer(),
                      IconButton(
                        onPressed: _isDownloading ? null : _downloadMedia,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.download_rounded,
                                color: Colors.white,
                              ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _shareMedia(context),
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom info
              if (_currentItem.trackingNumber != null ||
                  _currentItem.assemblyNumber != null)
                Positioned(
                  bottom: _currentItem.isVideo ? 140 : 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentItem.trackingNumber != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Трек: ${_currentItem.trackingNumber}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_currentItem.assemblyNumber != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ID сборки: ${_currentItem.assemblyNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPlayerView extends StatefulWidget {
  final String url;
  final bool active;

  const _VideoPlayerView({super.key, required this.url, this.active = true});

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  VideoPlayerController? _controller;
  bool _started = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    VideoPlayerController? pending;
    try {
      pending = await createAuthenticatedVideoController(
        context,
        widget.url,
        progressivePlayback: true,
      );
      if (!mounted) {
        await pending.dispose();
        return;
      }
      await pending.initialize();
      if (!mounted) {
        await pending.dispose();
        return;
      }
      await pending.setLooping(false);
      if (!mounted) {
        await pending.dispose();
        return;
      }
      if (widget.active) await pending.play();
      if (!mounted) {
        await pending.dispose();
        return;
      }
      if (!widget.active) await pending.pause();
      if (!mounted) {
        await pending.dispose();
        return;
      }
      setState(() => _controller = pending);
    } catch (error) {
      debugPrint('[ReportVideo] Initialization failed: $error');
      await pending?.dispose();
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) unawaited(_syncPlayback());
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      if (widget.active) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) return const Icon(Icons.error_outline, color: Colors.white);
    if (controller == null || !controller.value.isInitialized) {
      return const MediaLoadingIndicator();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: ReportVideoControls(
            controller: controller,
            active: widget.active,
          ),
        ),
      ],
    );
  }
}
