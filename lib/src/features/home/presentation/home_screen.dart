import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_pill.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../invoices/data/fake_invoices_repository.dart';
import '../../invoices/domain/invoice_item.dart';
import '../../photos/data/fake_photos_repository.dart';
import '../../photos/domain/photo_item.dart';
import '../../photos/presentation/photo_viewer_screen.dart';
import '../../tracks/data/fake_tracks_repository.dart';
import '../../tracks/domain/track_item.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message: 'Чтобы увидеть данные, сначала выберите или добавьте код клиента.',
      );
    }

    final tracksAsync = ref.watch(tracksListProvider(clientCode));
    final invoicesAsync = ref.watch(invoicesListProvider(clientCode));
    final photosCountAsync = ref.watch(photosTotalCountProvider(clientCode));
    final recentPhotosAsync = ref.watch(photosRecentProvider((clientCode: clientCode, limit: 10)));

    final tracksCount = tracksAsync.asData?.value.length;
    final invoicesCount = invoicesAsync.asData?.value.length;
    final photosCount = photosCountAsync.asData?.value;

    final theme = Theme.of(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, (24 + bottomPad) * 0.55),
      children: [
        const _GreetingBlock(fullName: 'Богдан Остапенко'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                title: 'Треки',
                icon: Icons.local_shipping_rounded,
                value: tracksCount,
                onTap: () => context.go('/tracks'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                title: 'Фото',
                icon: Icons.photo_rounded,
                value: photosCount,
                onTap: () => context.go('/photos'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                title: 'Счета',
                icon: Icons.receipt_long_rounded,
                value: invoicesCount,
                onTap: () => context.go('/invoices'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Дайджест',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _DigestSection(
          title: 'Треки',
          onAll: () => context.go('/tracks'),
          child: _TracksDigest(tracksAsync: tracksAsync),
        ),
        const SizedBox(height: 12),
        _DigestSection(
          title: 'Фото',
          onAll: () => context.go('/photos'),
          child: _PhotosDigest(photosAsync: recentPhotosAsync),
        ),
        const SizedBox(height: 12),
        _DigestSection(
          title: 'Счета',
          onAll: () => context.go('/invoices'),
          child: _InvoicesDigest(invoicesAsync: invoicesAsync),
        ),
      ],
    );
  }
}

class _GreetingBlock extends StatelessWidget {
  final String fullName;

  const _GreetingBlock({
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingFor(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          fullName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  String _greetingFor(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Доброе утро';
    if (h >= 12 && h < 17) return 'Добрый день';
    if (h >= 17 && h < 23) return 'Добрый вечер';
    return 'Доброй ночи';
  }
}

class _QuickCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final int? value;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.value == null ? '—' : widget.value.toString();
    return AspectRatio(
      aspectRatio: 1.06,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.lerp(
                    Alignment.topLeft,
                    Alignment.topRight,
                    _animation.value,
                  )!,
                  end: Alignment.lerp(
                    Alignment.bottomRight,
                    Alignment.bottomLeft,
                    _animation.value,
                  )!,
                  colors: [
                    Color.lerp(
                      const Color(0xFFfe3301),
                      const Color(0xFFff5f02),
                      _animation.value * 0.5,
                    )!,
                    Color.lerp(
                      const Color(0xFFff5f02),
                      const Color(0xFFfe3301),
                      _animation.value * 0.5,
                    )!,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0xFFfe3301),
                      const Color(0xFFff5f02),
                      _animation.value,
                    )!.withValues(alpha: 0.35),
                    blurRadius: 20 + (_animation.value * 5),
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.20),
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.12),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, size: 20, color: Colors.white),
                    const Spacer(),
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        display,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
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

class _DigestSection extends StatelessWidget {
  final String title;
  final VoidCallback onAll;
  final Widget child;

  const _DigestSection({
    required this.title,
    required this.onAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: onAll,
              child: const Text('Смотреть все'),
            ),
          ],
        ),
        child,
      ],
    );
  }
}

class _TracksDigest extends StatelessWidget {
  final AsyncValue<List<TrackItem>> tracksAsync;

  const _TracksDigest({
    required this.tracksAsync,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM, HH:mm', 'ru');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: tracksAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Не удалось загрузить треки: $e', style: const TextStyle(color: Colors.red)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Пока нет треков.'),
              );
            }

            final top = items.take(10).toList(growable: false);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(top[i].code, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(df.format(top[i].date)),
                    trailing: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: StatusPill(
                        text: top[i].status,
                        color: _trackStatusColor(context, top[i].status),
                      ),
                    ),
                  ),
                  if (i != top.length - 1)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Color _trackStatusColor(BuildContext context, String status) {
    final s = status.toLowerCase();
    if (s.contains('получ')) return const Color(0xFF1B8A5A);
    if (s.contains('отправ')) return const Color(0xFF2563EB);
    if (s.contains('ожидан')) return const Color(0xFFB45309);
    if (s.contains('склад')) return const Color(0xFF0F766E);
    return Theme.of(context).colorScheme.primary;
  }
}

class _PhotosDigest extends StatelessWidget {
  final AsyncValue<List<PhotoItem>> photosAsync;

  const _PhotosDigest({
    required this.photosAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: photosAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
            error: (e, _) => Text('Не удалось загрузить фото: $e', style: const TextStyle(color: Colors.red)),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('Пока нет фото/видео.'),
                );
              }

              final top = items.take(12).toList();
              
              // Разбиваем на 3 колонки
              final col1 = <PhotoItem>[];
              final col2 = <PhotoItem>[];
              final col3 = <PhotoItem>[];
              
              for (var i = 0; i < top.length; i++) {
                if (i % 3 == 0) {
                  col1.add(top[i]);
                } else if (i % 3 == 1) {
                  col2.add(top[i]);
                } else {
                  col3.add(top[i]);
                }
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: col1.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PhotoThumb(
                          item: item,
                          onOpen: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => PhotoViewerScreen(item: item),
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: col2.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PhotoThumb(
                          item: item,
                          onOpen: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => PhotoViewerScreen(item: item),
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: col3.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PhotoThumb(
                          item: item,
                          onOpen: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => PhotoViewerScreen(item: item),
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final PhotoItem item;
  final VoidCallback onOpen;

  const _PhotoThumb({
    required this.item,
    required this.onOpen,
  });

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
                    CachedNetworkImage(
                      imageUrl: item.url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: Colors.black.withValues(alpha: 0.06),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: Colors.black.withValues(alpha: 0.06),
                        child: const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  if (item.isVideo)
                    const Center(
                      child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
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

class _InvoicesDigest extends StatelessWidget {
  final AsyncValue<List<InvoiceItem>> invoicesAsync;

  const _InvoicesDigest({
    required this.invoicesAsync,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    final money = NumberFormat.decimalPattern('ru');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: invoicesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Не удалось загрузить счета: $e', style: const TextStyle(color: Colors.red)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Пока нет счетов.'),
              );
            }

            final top = items.take(10).toList(growable: false);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(top[i].invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(df.format(top[i].sendDate)),
                        const SizedBox(height: 2),
                        Text(
                          '${money.format(top[i].totalCostRub.round())} ₽',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                    trailing: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: StatusPill(
                        text: top[i].status,
                        color: _invoiceStatusColor(context, top[i].status),
                      ),
                    ),
                  ),
                  if (i != top.length - 1)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Color _invoiceStatusColor(BuildContext context, String status) {
    final s = status.toLowerCase();
    if (s.contains('оплачен')) return const Color(0xFF1B8A5A);
    if (s.contains('требует')) return const Color(0xFFB45309);
    if (s.contains('новый')) return const Color(0xFF2563EB);
    return Theme.of(context).colorScheme.primary;
  }
}
