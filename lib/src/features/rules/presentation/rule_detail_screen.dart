import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/quill_delta_viewer.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/rules_provider.dart';

class RuleDetailScreen extends ConsumerWidget {
  final String slug;
  const RuleDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItem = ref.watch(ruleItemProvider(slug));
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return asyncItem.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final errorInfo = ErrorUtils.getErrorInfo(e);
        return EmptyState(
          icon: errorInfo.icon,
          title: errorInfo.title,
          message: errorInfo.message,
        );
      },
      data: (item) {
        if (item == null) {
          return EmptyState(
            icon: Icons.article_outlined,
            title: tr(context, ru: 'Правило не найдено', zh: '未找到规则'),
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            topPad * 0.7 + 6,
            16,
            24 + bottomPad,
          ),
          children: [
            // Title
            Text(
              item.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),

            // Content card with Quill Delta
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: QuillDeltaViewer(
                jsonContent: item.content,
                linkColor: context.brandPrimary,
                onImageTap: (imageUrl) => _openImageFullscreen(context, imageUrl),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Открывает изображение в полноэкранном режиме
  void _openImageFullscreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }
}

/// Полноэкранный просмотрщик изображения с зумом
class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullscreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}
