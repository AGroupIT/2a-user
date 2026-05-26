import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_cached_media_image.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/utils/error_utils.dart';
import '../../clients/application/client_codes_controller.dart';
import '../data/photos_provider.dart';
import '../domain/photo_item.dart';
import 'photo_viewer_screen.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  final ScrollController _scrollController = ScrollController();
  PaginatedPhotosNotifier? _photosNotifier;

  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _photoGridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _photosNotifier?.removeListener(_onPhotosChanged);
    super.dispose();
  }

  void _onPhotosChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.9) {
      _photosNotifier?.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message:
            'Чтобы увидеть фотографии, сначала выберите или добавьте код клиента.',
      );
    }

    // Держим WebSocket-подписку для фонового обновления фото без перезагрузки экрана.
    ref.watch(photosRealtimeBridgeProvider);

    final newNotifier = ref.watch(paginatedPhotosProvider(clientCode));
    if (_photosNotifier != newNotifier) {
      _photosNotifier?.removeListener(_onPhotosChanged);
      _photosNotifier = newNotifier;
      newNotifier.addListener(_onPhotosChanged);
    }
    final photosState = newNotifier.state;

    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);

    Future<void> onRefresh() async {
      await _photosNotifier?.loadInitial();
    }

    return TutorialScreenWrapper(
      screenKey: 'photos',
      steps: [
        TutorialStep(
          icon: Icons.photo_camera_rounded,
          title: 'Фотоотчёты',
          description:
              'Мы фотографируем ваши посылки на складе. Здесь хранятся все снимки и видео по вашим отправлениям.',
          targetKey: _statsKey,
        ),
        TutorialStep(
          icon: Icons.fullscreen_rounded,
          title: 'Просмотр фото',
          description:
              'Нажмите на любое фото для полноэкранного просмотра. Видеофайлы отмечены значком воспроизведения.',
          targetKey: _photoGridKey,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: context.brandPrimary,
        // CustomScrollView + SliverGrid обеспечивают виртуализацию фото-грида:
        // только видимые ячейки держатся в дереве, остальные уничтожаются.
        // Ранее использовался ListView + shrinkWrap:true GridView, который рендерил
        // ВСЕ фото одновременно → OOM crash при большом количестве.
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KeyedSubtree(
                          key: _statsKey,
                          child: const _PhotosHeaderSection(),
                        ),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),
                ..._buildPhotosSlivers(context, photosState),
                SliverToBoxAdapter(child: SizedBox(height: bottomPad + 16)),
              ],
            ),
            ScrollToTopButton(
              controller: _scrollController,
              bottomOffset:
                  AppLayout.bottomBarHeight +
                  AppLayout.bottomBarBottomMargin +
                  37,
            ),
          ],
        ),
      ),
    );
  }

  /// Возвращает список slivers для секции фотографий.
  /// Использует SliverGrid вместо shrinkWrap GridView — обеспечивает
  /// виртуализацию: только видимые ячейки держатся в дереве.
  List<Widget> _buildPhotosSlivers(
    BuildContext context,
    PaginatedPhotosState state,
  ) {
    if (state.isLoading && state.photos.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ];
    }

    if (state.error != null && state.photos.isEmpty) {
      final errorInfo = ErrorUtils.getErrorInfo(state.error);
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Не удалось загрузить фото: ${errorInfo.message}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ];
    }

    if (state.photos.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'Фотоотчёт отсутствует',
            message: 'Пока нет загруженных фото и видео.',
          ),
        ),
      ];
    }

    final items = state.photos;
    final groups = _groupPhotosByDate(items);
    var globalIndex = 0;
    final slivers = <Widget>[];

    for (var groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
      final group = groups[groupIndex];
      final startIndex = globalIndex;
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, groupIndex == 0 ? 0 : 18, 16, 10),
            child: _PhotoDateDivider(
              date: group.date,
              count: group.photos.length,
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          key: groupIndex == 0 ? _photoGridKey : null,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = group.photos[index];
                return _PhotoThumbnail(
                  item: item,
                  onOpen: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => PhotoViewerScreen(
                        item: item,
                        allPhotos: items,
                        initialIndex: startIndex + index,
                      ),
                    ),
                  ),
                );
              },
              childCount: group.photos.length,
              addAutomaticKeepAlives: false,
              addSemanticIndexes: false,
            ),
          ),
        ),
      );
      globalIndex += group.photos.length;
    }

    slivers.addAll([
      if (state.isLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      if (!state.isLoading && !state.hasMore && items.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Все фото загружены (${items.length})',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ]);

    return slivers;
  }

  List<_PhotoDateGroup> _groupPhotosByDate(List<PhotoItem> items) {
    final groups = <_PhotoDateGroup>[];
    for (final item in items) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      if (groups.isEmpty || !_isSameDay(groups.last.date, day)) {
        groups.add(_PhotoDateGroup(date: day, photos: [item]));
      } else {
        groups.last.photos.add(item);
      }
    }
    return groups;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _PhotoDateGroup {
  final DateTime date;
  final List<PhotoItem> photos;

  _PhotoDateGroup({required this.date, required this.photos});
}

class _PhotoDateDivider extends StatelessWidget {
  final DateTime date;
  final int count;

  const _PhotoDateDivider({required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('d MMMM yyyy', 'ru').format(date);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.70),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(3, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: context.brandPrimary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 16 / 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F2F2F),
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 16 / 13,
                  fontWeight: FontWeight.w600,
                  color: context.brandPrimary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _PhotosHeaderSection extends StatelessWidget {
  const _PhotosHeaderSection();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Фотоотчеты',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 24,
                height: 29 / 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F2F2F),
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final PhotoItem item;
  final VoidCallback onOpen;

  const _PhotoThumbnail({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.isVideo)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                    )
                  else
                    AppCachedMediaImage(
                      url: item.url,
                      thumbnailSize: 360,
                      memCacheWidth: 180,
                      memCacheHeight: 180,
                      maxWidthDiskCache: 360,
                      maxHeightDiskCache: 360,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      useOldImageOnUrlChange: false,
                      filterQuality: FilterQuality.low,
                      imageBuilder: (_, imageProvider) {
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                      placeholder: (_, _) {
                        return Container(
                          color: Colors.black.withValues(alpha: 0.06),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorWidget: (_, _, error) {
                        return Container(
                          color: Colors.black.withValues(alpha: 0.06),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        );
                      },
                    ),
                  if (item.isVideo)
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
