import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/app_scaffold.dart';
import '../../../core/ui/app_background.dart';
import '../../../core/ui/app_colors.dart';
import '../../more/presentation/more_sheet.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _titles = <String>[
    'Дашборд',
    'Фото',
    'Треки',
    'Счета',
    'Ещё',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    final title = _titles[currentIndex.clamp(0, _titles.length - 1)];
    final statusTop = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    final overlayStyle = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          onHorizontalDragEnd: (details) {
            // Only allow tab-swipe when we're at the root of a branch (no inner pages)
            if (Navigator.of(context).canPop()) return;

            final v = details.primaryVelocity ?? 0;
            // Swipe right: previous tab
            if (v > 250) {
              if (currentIndex > 0) {
                HapticFeedback.lightImpact();
                navigationShell.goBranch(currentIndex - 1, initialLocation: false);
              }
            }
            // Swipe left: next tab
            else if (v < -250) {
              // Не позволяем свайпать на последнюю вкладку "Ещё" (она открывается только по тапу)
              if (currentIndex < _titles.length - 2) {
                HapticFeedback.lightImpact();
                navigationShell.goBranch(currentIndex + 1, initialLocation: false);
              }
            }
          },
          child: Stack(
            children: [
              const Positioned.fill(child: AppBackground()),
              Padding(
                padding: EdgeInsets.only(top: statusTop),
                child: ClipRect(child: navigationShell),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppFloatingTopBar(title: title, showBack: false),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: _AnimatedBottomNav(
              currentIndex: currentIndex,
              onTap: (index) {
                navigationShell.goBranch(index, initialLocation: index == currentIndex);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AnimatedBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<_AnimatedBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousIndex = 0;
  double _dragStart = 0;

  static const _items = [
    (icon: CupertinoIcons.house, selectedIcon: CupertinoIcons.house_fill, label: 'Главная'),
    (icon: CupertinoIcons.photo, selectedIcon: CupertinoIcons.photo_fill, label: 'Фото'),
    (icon: CupertinoIcons.cube_box, selectedIcon: CupertinoIcons.cube_box_fill, label: 'Треки'),
    (icon: CupertinoIcons.doc, selectedIcon: CupertinoIcons.doc_fill, label: 'Счета'),
    (icon: Icons.more_horiz_rounded, selectedIcon: Icons.more_horiz_rounded, label: 'Ещё'),
  ];

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(_AnimatedBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSwipe(double delta) {
    final nextIndex = widget.currentIndex;
    
    // Swipe right - go to previous item
    if (delta > 20) {
      if (nextIndex > 0) {
        HapticFeedback.lightImpact();
        widget.onTap(nextIndex - 1);
      }
    }
    // Swipe left - go to next item
    else if (delta < -20) {
      // Не позволяем свайпать на последнюю вкладку "Ещё" (она открывается только по тапу)
      if (nextIndex < _items.length - 2) {
        HapticFeedback.lightImpact();
        widget.onTap(nextIndex + 1);
      }
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStart = details.globalPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final delta = _dragStart - details.globalPosition.dx;
    _handleSwipe(delta);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;
              
              return Stack(
                children: [
                  // Animated indicator
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final start = _previousIndex * itemWidth;
                      final end = widget.currentIndex * itemWidth;
                      final current = start + (end - start) * _animation.value;

                      return Positioned(
                        left: current + 4,
                        top: 10,
                        bottom: 10,
                        child: Container(
                          width: itemWidth - 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [context.brandPrimary, context.brandSecondary],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: context.brandSecondary.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Items
                  Row(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      final isSelected = index == widget.currentIndex;
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              // Если нажали на кнопку "Ещё" (последняя), показываем модальное окно
                              if (index == _items.length - 1) {
                                showModalBottomSheet<void>(
                                  context: context,
                                  backgroundColor: Colors.white,
                                  barrierColor: Colors.black.withValues(alpha: 0.22),
                                  useSafeArea: true,
                                  isScrollControlled: true,
                                  builder: (_) => const MoreSheet(),
                                );
                              } else {
                                widget.onTap(index);
                              }
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Center(
                              child: Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                size: 26,
                                color: isSelected ? Colors.white : const Color(0xFFff5f02),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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
