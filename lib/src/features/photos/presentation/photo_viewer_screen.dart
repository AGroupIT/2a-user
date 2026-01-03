import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';

import '../domain/photo_item.dart';

void _showStyledSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => messenger.hideCurrentSnackBar(),
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
      backgroundColor: isError
          ? const Color(0xFFE53935)
          : const Color(0xFFfe3301),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
      duration: const Duration(seconds: 3),
    ),
  );
}

class PhotoViewerScreen extends StatefulWidget {
  final PhotoItem item;

  const PhotoViewerScreen({
    super.key,
    required this.item,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  bool _isDownloading = false;
  double _swipeDy = 0;

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
      // Запрашиваем разрешение на сохранение в галерею
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) {
            _showStyledSnackBar(context, 'Нет разрешения на сохранение в галерею', isError: true);
          }
          return;
        }
      }

      String savePath;
      
      if (!widget.item.isVideo) {
        // Для изображений используем кеш CachedNetworkImage
        final file = await DefaultCacheManager().getSingleFile(widget.item.url);
        savePath = file.path;
      } else {
        // Для видео скачиваем через Dio
        final tempDir = await getTemporaryDirectory();
        savePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
        await Dio().download(widget.item.url, savePath);
      }
      
      // Сохраняем в галерею
      if (widget.item.isVideo) {
        await Gal.putVideo(savePath, album: '2A Logistic');
        // Удаляем временный файл только для видео
        try {
          await File(savePath).delete();
        } catch (_) {}
      } else {
        await Gal.putImage(savePath, album: '2A Logistic');
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

  Future<void> _shareMedia() async {
    try {
      String filePath;
      
      if (!widget.item.isVideo) {
        // Для изображений используем кеш CachedNetworkImage
        final file = await DefaultCacheManager().getSingleFile(widget.item.url);
        filePath = file.path;
      } else {
        // Для видео скачиваем во временную директорию
        final tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await Dio().download(widget.item.url, filePath);
      }
      
      // Шарим файл
      await Share.shareXFiles(
        [XFile(filePath)],
        text: widget.item.trackingNumber != null 
            ? 'Трек: ${widget.item.trackingNumber}' 
            : null,
      );
      
      // Удаляем временный файл для видео после небольшой задержки
      if (widget.item.isVideo) {
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            await File(filePath).delete();
          } catch (_) {}
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        String message = 'Ошибка';
        if (e.response?.statusCode == 403) {
          message = 'Нет доступа к файлу';
        } else if (e.response?.statusCode == 404) {
          message = 'Файл не найден';
        }
        _showStyledSnackBar(context, message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showStyledSnackBar(context, 'Не удалось поделиться', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                child: Transform.translate(
                  offset: Offset(0, _swipeDy),
                  child: Center(
                    child: widget.item.isVideo
                        ? _VideoPlayerView(url: widget.item.url)
                        : InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: CachedNetworkImage(
                              imageUrl: widget.item.url,
                              fit: BoxFit.contain,
                              placeholder: (_, _) => const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _isDownloading ? null : _downloadMedia,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _shareMedia,
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom info
            if (widget.item.trackingNumber != null || widget.item.assemblyNumber != null)
              Positioned(
                bottom: 0,
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
                      if (widget.item.trackingNumber != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, color: Colors.white70, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Трек: ${widget.item.trackingNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.item.assemblyNumber != null)
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'ID сборки: ${widget.item.assemblyNumber}',
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
    );
  }
}

class _VideoPlayerView extends StatefulWidget {
  final String url;

  const _VideoPlayerView({
    required this.url,
  });

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
              ),
            ),
        ],
      ),
    );
  }
}
