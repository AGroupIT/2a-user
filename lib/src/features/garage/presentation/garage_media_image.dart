import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_config.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/fullscreen_image_overlay.dart';
import '../../../core/utils/file_download_helper.dart';

class GarageImageStrip extends StatelessWidget {
  final List<String> imagePaths;
  final String keyPrefix;
  final String fallbackFileNamePrefix;
  final double imageSize;

  const GarageImageStrip({
    super.key,
    required this.imagePaths,
    required this.keyPrefix,
    required this.fallbackFileNamePrefix,
    this.imageSize = 82,
  });

  @override
  Widget build(BuildContext context) {
    final paths = imagePaths
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: imageSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final imagePath = paths[index];
          return Semantics(
            button: true,
            label: 'Открыть изображение ${index + 1} из ${paths.length}',
            child: Tooltip(
              message: 'Открыть изображение ${index + 1} из ${paths.length}',
              child: InkWell(
                key: ValueKey('$keyPrefix-image-$index'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => showGarageImage(
                  context: context,
                  imagePath: imagePath,
                  fallbackFileName: '$fallbackFileNamePrefix-${index + 1}.jpg',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    ApiConfig.getMediaThumbnailUrl(imagePath, size: 240),
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: imageSize,
                      height: imageSize,
                      color: const Color(0xFFEFF1F4),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void showGarageImage({
  required BuildContext context,
  required String imagePath,
  required String fallbackFileName,
}) {
  final imageUrl = ApiConfig.getMediaUrl(imagePath);
  final fileName = _garageImageFileName(imagePath, fallbackFileName);
  showFullscreenImageOverlay(
    context: context,
    imageUrl: imageUrl,
    fileName: fileName,
    onDownload: () {
      unawaited(
        _downloadGarageImage(
          context: context,
          imageUrl: imageUrl,
          fileName: fileName,
        ),
      );
    },
  );
}

String _garageImageFileName(String imagePath, String fallbackFileName) {
  final uri = Uri.tryParse(imagePath);
  final path = uri?.path ?? imagePath;
  final lastSegment = path
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .lastOrNull;
  if (lastSegment == null || !lastSegment.contains('.')) {
    return fallbackFileName;
  }
  return Uri.decodeComponent(lastSegment);
}

Future<void> _downloadGarageImage({
  required BuildContext context,
  required String imageUrl,
  required String fileName,
}) async {
  AppToast.show(
    context,
    'Загрузка изображения...',
    icon: Icons.download_rounded,
    duration: const Duration(seconds: 10),
  );
  try {
    final response = await Dio().get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('empty_image_response');
    }
    final saved = await downloadFile(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
    );
    if (!saved) throw StateError('image_not_saved');
    if (!context.mounted) return;
    AppToast.show(
      context,
      'Изображение сохранено: $fileName',
      icon: Icons.download_done_rounded,
    );
  } catch (_) {
    if (!context.mounted) return;
    AppToast.show(
      context,
      'Не удалось скачать изображение',
      isError: true,
      icon: Icons.error_outline_rounded,
    );
  }
}
