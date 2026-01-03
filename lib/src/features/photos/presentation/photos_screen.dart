import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../clients/application/client_codes_controller.dart';
import '../data/fake_photos_repository.dart';
import '../domain/photo_item.dart';
import 'photo_viewer_screen.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  late int _month;
  late int _year;
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month - 1;
    _year = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message: 'Чтобы увидеть фотографии, сначала выберите или добавьте код клиента.',
      );
    }

    final photosCountAsync = ref.watch(photosTotalCountProvider(clientCode));
    final daysAsync = ref.watch(photosDaysProvider((clientCode: clientCode, month: _month, year: _year)));
    final photosAsync = _selectedDate.isEmpty
        ? const AsyncValue<List<PhotoItem>>.data([])
        : ref.watch(photosByDateProvider((clientCode: clientCode, date: _selectedDate)));

    final photosCount = photosCountAsync.asData?.value;

    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, (24 + bottomPad) * 0.55),
      children: [
        Text(
          'Фотографии и видео',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        _PhotosStatsCard(
          count: photosCount,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _CustomDropdown<int>(
                value: _month,
                label: 'Месяц',
                items: List.generate(
                  12,
                  (i) => _DropdownItem(value: i, label: _monthLabel(i)),
                ),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _month = v;
                    _selectedDate = '';
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: _CustomDropdown<int>(
                value: _year,
                label: 'Год',
                items: List.generate(
                  5,
                  (i) {
                    final y = DateTime.now().year - 2 + i;
                    return _DropdownItem(value: y, label: '$y');
                  },
                ),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _year = v;
                    _selectedDate = '';
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        daysAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Не удалось загрузить даты: $e', style: const TextStyle(color: Colors.red)),
          ),
          data: (days) {
            _syncSelectedDate(days);
            return _CalendarGrid(
              year: _year,
              month: _month,
              selectedDate: _selectedDate,
              enabledDates: days,
              onPrevMonth: () {
                setState(() {
                  if (_month == 0) {
                    _month = 11;
                    _year -= 1;
                  } else {
                    _month -= 1;
                  }
                  _selectedDate = '';
                });
              },
              onNextMonth: () {
                setState(() {
                  if (_month == 11) {
                    _month = 0;
                    _year += 1;
                  } else {
                    _month += 1;
                  }
                  _selectedDate = '';
                });
              },
              onSelect: (date) => setState(() => _selectedDate = date),
            );
          },
        ),
        const SizedBox(height: 12),
        photosAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Не удалось загрузить фото: $e',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              if (_selectedDate.isNotEmpty) {
                return const EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: 'Фотоотчёт отсутствует',
                  message: 'За выбранную дату нет фото/видео.',
                );
              }
              return const EmptyState(
                icon: Icons.event_available_outlined,
                title: 'Выберите дату',
                message: 'Нажмите на оранжевый день в календаре.',
              );
            }

            // Разбиваем на 3 колонки
            final col1 = <PhotoItem>[];
            final col2 = <PhotoItem>[];
            final col3 = <PhotoItem>[];

            for (var i = 0; i < items.length; i++) {
              if (i % 3 == 0) {
                col1.add(items[i]);
              } else if (i % 3 == 1) {
                col2.add(items[i]);
              } else {
                col3.add(items[i]);
              }
            }

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: col1
                              .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PhotoThumbnail(
                                  item: item,
                                  onOpen: () => Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute<void>(
                                      fullscreenDialog: true,
                                      builder: (_) => PhotoViewerScreen(item: item),
                                    ),
                                  ),
                                ),
                              ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: col2
                              .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PhotoThumbnail(
                                  item: item,
                                  onOpen: () => Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute<void>(
                                      fullscreenDialog: true,
                                      builder: (_) => PhotoViewerScreen(item: item),
                                    ),
                                  ),
                                ),
                              ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: col3
                              .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PhotoThumbnail(
                                  item: item,
                                  onOpen: () => Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute<void>(
                                      fullscreenDialog: true,
                                      builder: (_) => PhotoViewerScreen(item: item),
                                    ),
                                  ),
                                ),
                              ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _syncSelectedDate(List<String> days) {
    final next = days.isEmpty ? '' : (days.contains(_selectedDate) ? _selectedDate : days.first);
    if (next == _selectedDate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedDate = next);
    });
  }

  String _monthLabel(int monthIndex0) {
    const names = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return names[monthIndex0.clamp(0, 11)];
  }
}

class _PhotosStatsCard extends StatelessWidget {
  final int? count;

  const _PhotosStatsCard({
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final display = count == null ? '—' : count.toString();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFfe3301),
            const Color(0xFFff5f02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFfe3301).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_rounded, size: 26, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Всего фото и видео',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        display,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final int year;
  final int month;
  final String selectedDate;
  final List<String> enabledDates;
  final ValueChanged<String> onSelect;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.selectedDate,
    required this.enabledDates,
    required this.onSelect,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = enabledDates.toSet();
    final daysInMonth = DateUtils.getDaysInMonth(year, month + 1);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onPrevMonth,
                      child: const SizedBox(
                        width: 28,
                        height: 24,
                        child: Icon(
                          Icons.keyboard_arrow_left_rounded,
                          size: 22,
                          color: Color(0xFFfe3301),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _monthName(month) + ' ' + year.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.0),
                      ),
                    ),
                    GestureDetector(
                      onTap: onNextMonth,
                      child: const SizedBox(
                        width: 28,
                        height: 24,
                        child: Icon(
                          Icons.keyboard_arrow_right_rounded,
                          size: 22,
                          color: Color(0xFFfe3301),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: daysInMonth,
                itemBuilder: (context, index) {
                    final day = index + 1;
                    final dateStr = _toYmd(year, month + 1, day);
                    final hasPhotos = enabled.contains(dateStr);
                    final isSelected = dateStr == selectedDate;

                    final bgColor = isSelected ? const Color(0xFFfe3301) : Colors.white;
                    final borderColor = hasPhotos ? const Color(0xFFfe3301) : Colors.grey[300]!;
                    final textColor = isSelected ? Colors.white : Colors.black87;
                    final textOpacity = hasPhotos ? 1.0 : 0.3;

                    return InkWell(
                      onTap: hasPhotos ? () => onSelect(dateStr) : null,
                      borderRadius: BorderRadius.circular(999),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: borderColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: textColor.withValues(alpha: textOpacity),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _toYmd(int y, int m, int d) {
    String pad(int n) => n < 10 ? '0$n' : '$n';
    return '$y-${pad(m)}-${pad(d)}';
  }

  static String _monthName(int monthIndex0) {
    const names = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    return names[monthIndex0.clamp(0, 11)];
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final PhotoItem item;
  final VoidCallback onOpen;

  const _PhotoThumbnail({
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

class _DropdownItem<T> {
  final T value;
  final String label;

  _DropdownItem({required this.value, required this.label});
}

class _CustomDropdown<T> extends StatefulWidget {
  final T value;
  final String label;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _CustomDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<_CustomDropdown<T>> {
  late T _selectedValue;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(_CustomDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selectedValue = widget.value;
    }
  }

  void _showMenu() {
    final renderBox = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    final double menuWidth = renderBox?.size.width ?? 200;
    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _hideMenu,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 50),
                child: GestureDetector(
                  onTap: () {},
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: menuWidth,
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: widget.items.map((item) {
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedValue = item.value;
                              });
                              widget.onChanged(item.value);
                              _overlayEntry?.remove();
                              _overlayEntry = null;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedValue == item.value
                                    ? const Color(0xFFfe3301).withValues(alpha: 0.1)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _selectedValue == item.value ? FontWeight.w600 : FontWeight.w500,
                                  color: _selectedValue == item.value ? const Color(0xFFfe3301) : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.items
        .firstWhere(
          (item) => item.value == _selectedValue,
          orElse: () => _DropdownItem(value: _selectedValue, label: 'N/A'),
        )
        .label;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          if (_overlayEntry == null) {
            _showMenu();
          } else {
            _hideMenu();
          }
        },
        child: Container(
          key: _targetKey,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.70),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(
                _overlayEntry != null ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFFfe3301),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
