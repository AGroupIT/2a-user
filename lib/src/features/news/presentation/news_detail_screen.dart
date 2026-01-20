import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/ui/app_colors.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/utils/locale_text.dart';
import '../data/news_provider.dart';

class NewsDetailScreen extends ConsumerWidget {
  final String slug;
  const NewsDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItem = ref.watch(newsItemProvider(slug));
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return asyncItem.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: tr(context, ru: 'Не удалось загрузить статью', zh: '无法加载文章'),
        message: e.toString(),
      ),
      data: (item) {
        if (item == null) {
          return EmptyState(
            icon: Icons.article_outlined,
            title: tr(context, ru: 'Статья не найдена', zh: '未找到文章'),
          );
        }

        final locale = isZh(context) ? 'zh' : 'ru';
        final df = DateFormat('dd MMM yyyy', locale);

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
            const SizedBox(height: 12),

            // Date badge
            Row(
              children: [
                Builder(
                  builder: (ctx) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: ctx.brandPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: ctx.brandPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          df.format(item.publishedAt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ctx.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cover image
            if (item.imageUrl != null) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 20),
            ],

            // Content card with Markdown
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
              child: MarkdownBody(
                data: item.content,
                selectable: true,
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(
                      Uri.parse(href),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                styleSheet: _buildMarkdownStyleSheet(context),
                imageBuilder: (uri, title, alt) {
                  final imageUrl = uri.toString();
                  return GestureDetector(
                    onTap: () => _openImageFullscreen(context, imageUrl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            height: 150,
                            color: const Color(0xFFF5F5F5),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            height: 150,
                            color: const Color(0xFFF5F5F5),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Color(0xFFCCCCCC),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final baseTextStyle = const TextStyle(
      fontSize: 15,
      height: 1.6,
      color: Color(0xFF333333),
    );

    return MarkdownStyleSheet(
      // Paragraphs
      p: baseTextStyle,
      pPadding: const EdgeInsets.only(bottom: 12),

      // Headings
      h1: baseTextStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        height: 1.3,
      ),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h2: baseTextStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
      h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
      h3: baseTextStyle.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 6),
      h4: baseTextStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      h4Padding: const EdgeInsets.only(top: 10, bottom: 4),

      // Bold and italic
      strong: baseTextStyle.copyWith(fontWeight: FontWeight.w700),
      em: baseTextStyle.copyWith(fontStyle: FontStyle.italic),
      del: baseTextStyle.copyWith(
        decoration: TextDecoration.lineThrough,
        color: const Color(0xFF999999),
      ),

      // Links
      a: baseTextStyle.copyWith(
        color: context.brandPrimary,
        decoration: TextDecoration.underline,
        decorationColor: context.brandPrimary,
      ),

      // Lists
      listBullet: baseTextStyle.copyWith(color: context.brandPrimary),
      listBulletPadding: const EdgeInsets.only(right: 8),
      listIndent: 20,

      // Blockquote
      blockquote: baseTextStyle.copyWith(
        fontStyle: FontStyle.italic,
        color: const Color(0xFF666666),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: context.brandPrimary, width: 4)),
        color: const Color(0xFFFFF5F3),
        borderRadius: BorderRadius.circular(4),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),

      // Code
      code: TextStyle(
        fontSize: 13,
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFFF5F5F5),
        color: const Color(0xFFe53935),
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),

      // Horizontal rule
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),

      // Table
      tableHead: baseTextStyle.copyWith(fontWeight: FontWeight.w700),
      tableBody: baseTextStyle,
      tableBorder: TableBorder.all(color: const Color(0xFFEEEEEE), width: 1),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.all(8),
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
