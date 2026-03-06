// TODO: Update to ShowcaseView.get() API when showcaseview 6.0.0 is released
// ignore_for_file: deprecated_member_use
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/services/auto_refresh_service.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/news_provider.dart';
import '../domain/news_item.dart';

class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen({super.key});

  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen>
    with AutoRefreshMixin {
  // Showcase keys
  final _showcaseKeyHeader = GlobalKey();
  final _showcaseKeyNewsCard = GlobalKey();

  bool _showcaseStarted = false;
  bool _allSkipped = false;
  List<ShowcaseBlock> _currentRunBlocks = [];

  @override
  void initState() {
    super.initState();
    startAutoRefresh(() {
      ref.invalidate(newsListProvider);
    });
  }

  void _startShowcaseIfNeeded(BuildContext showcaseContext) {
    if (_showcaseStarted) return;
    if (!TickerMode.of(showcaseContext)) return;

    final pairs = [
      (_showcaseKeyHeader, ShowcaseBlock.newsHeader),
      (_showcaseKeyNewsCard, ShowcaseBlock.newsCard),
    ];

    final visible = pairs
        .where((p) => p.$1.currentContext != null && ref.read(showcaseBlockProvider(p.$2)))
        .toList();

    if (visible.isEmpty) {
      _showcaseStarted = false;
      return;
    }

    _showcaseStarted = true;
    _currentRunBlocks = visible.map((p) => p.$2).toSet().toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(showcasePendingBlocksProvider.notifier).setBlocks(_currentRunBlocks);
      startShowCaseSafe(showcaseContext, visible.map((p) => p.$1).toList());
    });
  }

  void _onShowcaseComplete() {
    for (final block in _currentRunBlocks) {
      ref.read(showcaseServiceProvider).markBlockAsSeen(block);
      ref.invalidate(showcaseBlockProvider(block));
    }
    _currentRunBlocks = [];
  }

  void _skipAllShowcases() {
    setState(() => _allSkipped = true);
    ref.read(showcaseServiceProvider).markAllBlocksSeen();
    for (final block in ShowcaseBlock.values) {
      ref.invalidate(showcaseBlockProvider(block));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(newsListProvider);
    final shouldShowHeader = !_allSkipped && ref.watch(showcaseBlockProvider(ShowcaseBlock.newsHeader));
    final shouldShowCard = !_allSkipped && ref.watch(showcaseBlockProvider(ShowcaseBlock.newsCard));
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    Future<void> onRefresh() async {
      ref.invalidate(newsListProvider);
      await ref.read(newsListProvider.future);
    }

    return ShowcaseWrapper(
      onComplete: _onShowcaseComplete,
      onSkipAll: _skipAllShowcases,
      child: Builder(
        builder: (showcaseContext) {
          // Запускаем showcase если нужно
          _startShowcaseIfNeeded(showcaseContext);

          return asyncItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) {
              final errorInfo = ErrorUtils.getErrorInfo(e);
              return EmptyState(
                icon: errorInfo.icon,
                title: errorInfo.title,
                message: errorInfo.message,
              );
            },
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.newspaper_outlined,
                  title: tr(context, ru: 'Пока нет новостей', zh: '暂无新闻'),
                );
              }
              return RefreshIndicator(
                onRefresh: onRefresh,
                color: context.brandPrimary,
                child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 6,
              16,
              24 + bottomPad,
            ),
            itemCount: items.length + 1, // +1 for header
            itemBuilder: (context, i) {
              final headerText = Text(
                tr(context, ru: 'Новости', zh: '新闻'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              );
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: shouldShowHeader
                      ? Showcase(
                          key: _showcaseKeyHeader,
                          title: tr(context, ru: '📰 Лента новостей', zh: '📰 新闻动态'),
                          description: tr(
                            context,
                            ru: 'Актуальные новости и объявления от компании:\n• Новые услуги и тарифы\n• Изменения в работе\n• Важные уведомления\n• Акции и предложения\n• Потяните вниз для обновления ⬇️',
                            zh: '公司的最新新闻和公告：\n• 新服务和费率\n• 工作变化\n• 重要通知\n• 促销和优惠\n• 下拉刷新 ⬇️',
                          ),
                          targetPadding: getShowcaseTargetPadding(),
                          tooltipPosition: TooltipPosition.bottom,
                          tooltipBackgroundColor: Colors.white,
                          textColor: Colors.black87,
                          titleTextStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                          descTextStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          child: headerText,
                        )
                      : headerText,
                );
              }
              final item = items[i - 1];
              if (i == 1 && shouldShowCard) {
                // Первая карточка новостей - оборачиваем в Showcase
                return Padding(
                  padding: EdgeInsets.only(bottom: i == items.length ? 0 : 12),
                  child: Showcase(
                    key: _showcaseKeyNewsCard,
                    title: tr(context, ru: '📄 Карточка новости', zh: '📄 新闻卡片'),
                    description: tr(
                      context,
                      ru: 'Каждая новость содержит:\n• 🖼️ Обложку с изображением (если есть)\n• 📅 Дату публикации\n• 📝 Заголовок и краткое описание\n• 👆 Нажмите для чтения полной версии\n• Полный текст откроется на отдельной странице',
                      zh: '每条新闻包含：\n• 🖼️ 封面图片（如有）\n• 📅 发布日期\n• 📝 标题和简短描述\n• 👆 点击阅读完整版本\n• 完整文本将在单独页面打开',
                    ),
                    targetPadding: getShowcaseTargetPadding(),
                    tooltipPosition: TooltipPosition.bottom,
                    tooltipBackgroundColor: Colors.white,
                    textColor: Colors.black87,
                    titleTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                    descTextStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                    child: _NewsCard(item: item),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(bottom: i == items.length ? 0 : 12),
                child: _NewsCard(item: item),
              );
            },
          ),
        );
            },
          );
        },
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => context.push('/news/${item.slug}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image
              if (item.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    height: 160,
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
                    height: 160,
                    color: const Color(0xFFF5F5F5),
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: Color(0xFFCCCCCC),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfe3301).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        df.format(item.publishedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFfe3301),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Excerpt
                    Text(
                      item.excerpt,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        height: 1.4,
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
                            color: const Color(0xFFfe3301),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Color(0xFFfe3301),
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
