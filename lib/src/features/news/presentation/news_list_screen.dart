import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/auto_refresh_service.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../data/news_provider.dart';
import '../domain/news_item.dart';

class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen({super.key});

  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen>
    with AutoRefreshMixin {
  @override
  void initState() {
    super.initState();
    startAutoRefresh(() {
      ref.invalidate(newsListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(newsListProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    Future<void> onRefresh() async {
      ref.invalidate(newsListProvider);
      await ref.read(newsListProvider.future);
    }

    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить новости',
        message: e.toString(),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.newspaper_outlined,
            title: 'Пока нет новостей',
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          color: const Color(0xFFfe3301),
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 6,
              16,
              24 + bottomPad,
            ),
            itemCount: items.length + 1, // +1 for header
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    'Новости',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }
              final item = items[i - 1];
              return Padding(
                padding: EdgeInsets.only(bottom: i == items.length ? 0 : 12),
                child: _NewsCard(item: item),
              );
            },
          ),
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');

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
                        color: const Color(0xFFfe3301).withOpacity(0.1),
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
                          'Читать далее',
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
