import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/news_provider.dart';
import '../domain/news_item.dart';

const _newsTextColor = Color(0xFF2F2F2F);
const _newsMutedTextColor = Color(0x992F2F2F);

BoxDecoration _newsCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), offset: Offset(3, 4), blurRadius: 25),
    ],
  );
}

class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen({super.key});

  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _newsListKey = GlobalKey();
  final GlobalKey _firstNewsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(newsListProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    Future<void> onRefresh() async {
      ref.invalidate(newsListProvider);
      await ref.read(newsListProvider.future);
    }

    Widget buildFrame({required List<Widget> children}) {
      return Stack(
        children: [
          RefreshIndicator(
            onRefresh: onRefresh,
            color: context.brandPrimary,
            child: ListView(
              controller: _scrollController,
              key: _newsListKey,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                topPad * 0.7 + 16,
                16,
                bottomPad + 16,
              ),
              children: children,
            ),
          ),
          ScrollToTopButton(controller: _scrollController),
        ],
      );
    }

    return asyncItems.when(
      loading: () => buildFrame(
        children: const [
          AppPageHeader(title: 'Новости', showBack: true),
          SizedBox(height: 15),
          _NewsStateCard(
            icon: Icons.newspaper_rounded,
            title: 'Загружаем новости',
            message: 'Получаем последние публикации компании.',
            isLoading: true,
          ),
        ],
      ),
      error: (e, _) {
        final errorInfo = ErrorUtils.getErrorInfo(e);
        return buildFrame(
          children: [
            AppPageHeader(
              title: tr(context, ru: 'Новости', zh: '新闻'),
              showBack: true,
            ),
            const SizedBox(height: 15),
            _NewsStateCard(
              icon: errorInfo.icon,
              title: errorInfo.title,
              message: errorInfo.message,
              isError: true,
            ),
          ],
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return buildFrame(
            children: [
              AppPageHeader(
                title: tr(context, ru: 'Новости', zh: '新闻'),
                showBack: true,
              ),
              const SizedBox(height: 15),
              _NewsStateCard(
                icon: Icons.newspaper_outlined,
                title: tr(context, ru: 'Пока нет новостей', zh: '暂无新闻'),
                message: tr(
                  context,
                  ru: 'Здесь появятся новости, акции и важные объявления.',
                  zh: '这里将显示新闻、活动和重要公告。',
                ),
              ),
            ],
          );
        }
        return TutorialScreenWrapper(
          screenKey: 'news_list',
          steps: [
            TutorialStep(
              icon: Icons.newspaper_rounded,
              title: 'Новости компании',
              description:
                  'Здесь публикуются важные новости: изменения тарифов, акции, объявления об изменениях в работе.',
              targetKey: _newsListKey,
            ),
            TutorialStep(
              icon: Icons.open_in_new_rounded,
              title: 'Читать подробнее',
              description:
                  'Нажмите на карточку новости, чтобы прочитать полный текст. Важные новости лучше не пропускать.',
              targetKey: _firstNewsKey,
            ),
          ],
          child: buildFrame(
            children: [
              AppPageHeader(
                title: tr(context, ru: 'Новости', zh: '新闻'),
                showBack: true,
              ),
              const SizedBox(height: 15),
              for (var i = 0; i < items.length; i++) ...[
                if (i == 0)
                  KeyedSubtree(
                    key: _firstNewsKey,
                    child: _NewsCard(item: items[i]),
                  )
                else
                  _NewsCard(item: items[i]),
                if (i != items.length - 1) const SizedBox(height: 15),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _NewsStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool isLoading;
  final bool isError;

  const _NewsStateCard({
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
      decoration: _newsCardDecoration(),
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
                    color: _newsTextColor,
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
                      color: _newsMutedTextColor,
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

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final locale = isZh(context) ? 'zh' : 'ru';
    final df = DateFormat('dd MMM yyyy', locale);

    return Container(
      decoration: _newsCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/news/${item.slug}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image
              if (item.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  height: 156,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    height: 156,
                    color: const Color(0xFFF5F5F5),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    height: 156,
                    color: const Color(0xFFF5F5F5),
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: Color(0xFFCCCCCC),
                    ),
                  ),
                )
              else
                const _NewsPlaceholderCover(),

              Padding(
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
                        color: _newsTextColor,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        height: 21 / 17,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      item.excerpt,
                      style: const TextStyle(
                        color: _newsMutedTextColor,
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        height: 18 / 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Read more link
                    Row(
                      children: [
                        Text(
                          tr(context, ru: 'Читать далее', zh: '阅读更多'),
                          style: TextStyle(
                            color: context.brandPrimary,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 16 / 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: context.brandPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsPlaceholderCover extends StatelessWidget {
  const _NewsPlaceholderCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.brandPrimary.withValues(alpha: 0.95),
            context.brandSecondary.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Icon(
          Icons.newspaper_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: 38,
        ),
      ),
    );
  }
}
