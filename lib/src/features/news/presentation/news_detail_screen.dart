import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/ui/quill_delta_viewer.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/news_provider.dart';

const _newsDetailTextColor = Color(0xFF2F2F2F);
const _newsDetailMutedTextColor = Color(0x992F2F2F);

BoxDecoration _newsDetailCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), offset: Offset(3, 4), blurRadius: 25),
    ],
  );
}

class NewsDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  const NewsDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncItem = ref.watch(newsItemProvider(widget.slug));
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    Widget buildFrame({required List<Widget> children}) {
      return Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 16,
              16,
              bottomPad + 16,
            ),
            children: children,
          ),
          ScrollToTopButton(controller: _scrollController),
        ],
      );
    }

    return asyncItem.when(
      loading: () => buildFrame(
        children: const [
          AppPageHeader(title: 'Новость', showBack: true),
          SizedBox(height: 15),
          _NewsDetailStateCard(
            icon: Icons.article_rounded,
            title: 'Загружаем новость',
            message: 'Получаем текст публикации.',
            isLoading: true,
          ),
        ],
      ),
      error: (e, _) {
        final errorInfo = ErrorUtils.getErrorInfo(e);
        return buildFrame(
          children: [
            AppPageHeader(
              title: tr(context, ru: 'Новость', zh: '新闻'),
              showBack: true,
            ),
            const SizedBox(height: 15),
            _NewsDetailStateCard(
              icon: errorInfo.icon,
              title: errorInfo.title,
              message: errorInfo.message,
              isError: true,
            ),
          ],
        );
      },
      data: (item) {
        if (item == null) {
          return buildFrame(
            children: [
              AppPageHeader(
                title: tr(context, ru: 'Новость', zh: '新闻'),
                showBack: true,
              ),
              const SizedBox(height: 15),
              _NewsDetailStateCard(
                icon: Icons.article_outlined,
                title: tr(context, ru: 'Статья не найдена', zh: '未找到文章'),
                message: tr(
                  context,
                  ru: 'Новость могла быть удалена или снята с публикации.',
                  zh: '该新闻可能已被删除或取消发布。',
                ),
                isError: true,
              ),
            ],
          );
        }

        final locale = isZh(context) ? 'zh' : 'ru';
        final df = DateFormat('dd MMM yyyy', locale);

        return TutorialScreenWrapper(
          screenKey: 'news_detail',
          steps: const [
            TutorialStep(
              icon: Icons.article_rounded,
              title: 'Статья',
              description:
                  'Здесь отображается полный текст новости с датой публикации и обложкой.',
            ),
            TutorialStep(
              icon: Icons.image_rounded,
              title: 'Фото в статье',
              description:
                  'Нажмите на любое изображение в статье, чтобы открыть его на весь экран и увеличить.',
            ),
          ],
          child: buildFrame(
            children: [
              AppPageHeader(
                title: tr(context, ru: 'Новость', zh: '新闻'),
                showBack: true,
              ),
              const SizedBox(height: 15),

              Container(
                decoration: _newsDetailCardDecoration(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: context.brandPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            df.format(item.publishedAt),
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 12,
                              height: 14 / 12,
                              fontWeight: FontWeight.w600,
                              color: context.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: _newsDetailTextColor,
                        fontFamily: 'Gilroy',
                        fontSize: 22,
                        height: 27 / 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.excerpt.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.excerpt,
                        style: const TextStyle(
                          color: _newsDetailMutedTextColor,
                          fontFamily: 'Gilroy',
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 15),

              if (item.imageUrl != null) ...[
                Container(
                  decoration: _newsDetailCardDecoration(),
                  clipBehavior: Clip.antiAlias,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        height: 200,
                        color: const Color(0xFFF5F5F5),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        height: 200,
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          color: Color(0xFFCCCCCC),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              Container(
                decoration: _newsDetailCardDecoration(),
                padding: const EdgeInsets.all(16),
                child: QuillDeltaViewer(
                  jsonContent: item.content,
                  linkColor: context.brandPrimary,
                  onImageTap: (imageUrl) =>
                      _openImageFullscreen(context, imageUrl),
                ),
              ),
            ],
          ),
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

class _NewsDetailStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool isLoading;
  final bool isError;

  const _NewsDetailStateCard({
    required this.icon,
    required this.title,
    this.message,
    this.isLoading = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isError ? const Color(0xFFE53935) : context.brandPrimary;
    return Container(
      decoration: _newsDetailCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(icon, color: accent, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _newsDetailTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: _newsDetailMutedTextColor,
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      height: 16 / 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
        loadingBuilder: (context, event) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}
