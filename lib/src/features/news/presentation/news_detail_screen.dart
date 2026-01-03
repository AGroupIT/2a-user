import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../data/fake_news_repository.dart';

class NewsDetailScreen extends ConsumerWidget {
  final String slug;
  const NewsDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItem = ref.watch(newsItemProvider(slug));
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return asyncItem.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить статью',
        message: e.toString(),
      ),
      data: (item) {
        if (item == null) {
          return const EmptyState(
            icon: Icons.article_outlined,
            title: 'Статья не найдена',
          );
        }

        final df = DateFormat('dd MMM yyyy', 'ru');

        return ListView(
          padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, 24 + bottomPad),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfe3301).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFFfe3301)),
                      const SizedBox(width: 6),
                      Text(
                        df.format(item.publishedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFfe3301),
                        ),
                      ),
                    ],
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
                      child: const Icon(Icons.image_not_supported_rounded, color: Color(0xFFCCCCCC), size: 48),
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
                    launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                  }
                },
                styleSheet: _buildMarkdownStyleSheet(context),
                imageBuilder: (uri, title, alt) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: uri.toString(),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          height: 150,
                          color: const Color(0xFFF5F5F5),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, _, _) => Container(
                          height: 150,
                          color: const Color(0xFFF5F5F5),
                          child: const Icon(Icons.broken_image_rounded, color: Color(0xFFCCCCCC)),
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
      h1: baseTextStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w900, height: 1.3),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h2: baseTextStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3),
      h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
      h3: baseTextStyle.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 6),
      h4: baseTextStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      h4Padding: const EdgeInsets.only(top: 10, bottom: 4),

      // Bold and italic
      strong: baseTextStyle.copyWith(fontWeight: FontWeight.w700),
      em: baseTextStyle.copyWith(fontStyle: FontStyle.italic),
      del: baseTextStyle.copyWith(decoration: TextDecoration.lineThrough, color: const Color(0xFF999999)),

      // Links
      a: baseTextStyle.copyWith(
        color: const Color(0xFFfe3301),
        decoration: TextDecoration.underline,
        decorationColor: const Color(0xFFfe3301),
      ),

      // Lists
      listBullet: baseTextStyle.copyWith(color: const Color(0xFFfe3301)),
      listBulletPadding: const EdgeInsets.only(right: 8),
      listIndent: 20,

      // Blockquote
      blockquote: baseTextStyle.copyWith(
        fontStyle: FontStyle.italic,
        color: const Color(0xFF666666),
      ),
      blockquoteDecoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: Color(0xFFfe3301), width: 4),
        ),
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
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
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
