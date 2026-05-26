import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/app_scaffold.dart';
import '../../../core/logging/client_log_service.dart';
import '../../../core/ui/app_background.dart';
import '../../../core/ui/app_colors.dart';
import '../application/shell_branch_provider.dart';
import '../../more/presentation/more_sheet.dart';

/// Notifier to hide/show bottom navigation bar (e.g. when a modal is open)
class BottomNavVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void hide() => state = false;
  void show() => state = true;
}

final bottomNavVisibleProvider =
    NotifierProvider<BottomNavVisibleNotifier, bool>(
      BottomNavVisibleNotifier.new,
    );

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _titles = <String>[
    'Дашборд',
    'Фото',
    'Треки',
    'Счета',
    'Поддержка',
    'Ещё',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    _syncActiveShellBranch(context, ref, currentIndex);
    final title = _titles[currentIndex.clamp(0, _titles.length - 1)];
    final statusTop = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    final overlayStyle = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    final bottomNavVisible = ref.watch(bottomNavVisibleProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          onHorizontalDragEnd: (details) {
            // Проверяем, что shell - активный маршрут (нет внутренних страниц поверх)
            // Используем rootNavigator чтобы проверить есть ли страницы поверх shell
            final rootNavigator = Navigator.of(context, rootNavigator: true);
            if (rootNavigator.canPop()) {
              return; // Есть внутренняя страница - не обрабатываем свайп
            }

            // Дополнительная проверка для shell navigator
            if (Navigator.of(context).canPop()) return;

            final v = details.primaryVelocity ?? 0;
            // Swipe right: previous tab
            if (v > 250) {
              if (currentIndex > 0) {
                HapticFeedback.lightImpact();
                ClientLogService.instance.action(
                  'Навигация свайпом по вкладкам',
                  data: {
                    'fromTab': title,
                    'toTab': _titles[currentIndex - 1],
                    'direction': 'previous',
                  },
                );
                navigationShell.goBranch(
                  currentIndex - 1,
                  initialLocation: false,
                );
              }
            }
            // Swipe left: next tab
            else if (v < -250) {
              // Не позволяем свайпать на последнюю вкладку "Ещё" (она открывается только по тапу)
              if (currentIndex < _titles.length - 2) {
                HapticFeedback.lightImpact();
                ClientLogService.instance.action(
                  'Навигация свайпом по вкладкам',
                  data: {
                    'fromTab': title,
                    'toTab': _titles[currentIndex + 1],
                    'direction': 'next',
                  },
                );
                navigationShell.goBranch(
                  currentIndex + 1,
                  initialLocation: false,
                );
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  offset: bottomNavVisible ? Offset.zero : const Offset(0, 1.5),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: _PixsoBottomNav(
                        currentIndex: currentIndex,
                        onTap: (index) {
                          navigationShell.goBranch(
                            index,
                            initialLocation: index == currentIndex,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncActiveShellBranch(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
  ) {
    if (ref.read(activeShellBranchIndexProvider) == currentIndex) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (ref.read(activeShellBranchIndexProvider) == currentIndex) return;
      ref.read(activeShellBranchIndexProvider.notifier).setIndex(currentIndex);
    });
  }
}

class _PixsoBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PixsoBottomNav({required this.currentIndex, required this.onTap});

  @override
  State<_PixsoBottomNav> createState() => _PixsoBottomNavState();
}

class _PixsoBottomNavState extends State<_PixsoBottomNav> {
  double _dragStart = 0;

  static const _items = [
    (
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: 'Главная',
    ),
    (
      icon: CupertinoIcons.photo_on_rectangle,
      selectedIcon: CupertinoIcons.photo_fill_on_rectangle_fill,
      label: 'Фотоотчёты',
    ),
    (
      icon: CupertinoIcons.cube,
      selectedIcon: CupertinoIcons.cube_fill,
      label: 'Треки',
    ),
    (
      icon: CupertinoIcons.creditcard,
      selectedIcon: CupertinoIcons.creditcard_fill,
      label: 'Счета',
    ),
    (
      icon: CupertinoIcons.chat_bubble_text,
      selectedIcon: CupertinoIcons.chat_bubble_text_fill,
      label: 'Чат',
    ),
    (
      icon: CupertinoIcons.ellipsis,
      selectedIcon: CupertinoIcons.ellipsis,
      label: 'Ещё',
    ),
  ];

  void _handleSwipe(double delta) {
    final nextIndex = widget.currentIndex;

    // Swipe right - go to previous item
    if (delta > 20) {
      if (nextIndex > 0) {
        HapticFeedback.lightImpact();
        ClientLogService.instance.action(
          'Навигация свайпом по нижнему меню',
          data: {
            'fromTab': _items[nextIndex].label,
            'toTab': _items[nextIndex - 1].label,
            'direction': 'previous',
          },
        );
        widget.onTap(nextIndex - 1);
      }
    }
    // Swipe left - go to next item
    else if (delta < -20) {
      // Не позволяем свайпать на последнюю вкладку "Ещё" (она открывается только по тапу)
      if (nextIndex < _items.length - 2) {
        HapticFeedback.lightImpact();
        ClientLogService.instance.action(
          'Навигация свайпом по нижнему меню',
          data: {
            'fromTab': _items[nextIndex].label,
            'toTab': _items[nextIndex + 1].label,
            'direction': 'next',
          },
        );
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
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _BottomNavSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth;
                final buttonSize = contentWidth >= 300
                    ? 50.0
                    : contentWidth / _items.length;
                final iconSize = 34 * (buttonSize / 50);
                final gap = _items.length > 1
                    ? (contentWidth - buttonSize * _items.length) /
                          (_items.length - 1)
                    : 0.0;
                final selectedIndex = widget.currentIndex.clamp(
                  0,
                  _items.length - 1,
                );
                final selectedLeft = selectedIndex * (buttonSize + gap);

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      left: selectedLeft,
                      top: 5,
                      child: _ActiveNavBackground(size: buttonSize),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_items.length, (index) {
                        final item = _items[index];
                        final isSelected = index == widget.currentIndex;

                        return _BottomNavButton(
                          icon: isSelected ? item.selectedIcon : item.icon,
                          label: item.label,
                          isSelected: isSelected,
                          size: buttonSize,
                          iconSize: iconSize,
                          horizontalPadding: 7 * (buttonSize / 50),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ClientLogService.instance.action(
                              'Нажата нижняя навигация',
                              data: {
                                'tab': item.label,
                                'index': index,
                                'selected': isSelected,
                              },
                            );
                            if (index == _items.length - 1) {
                              ClientLogService.instance.action(
                                'Открыто меню Ещё',
                                data: {'source': 'bottom_navigation'},
                              );
                              showModalBottomSheet<void>(
                                context: context,
                                backgroundColor: Colors.white,
                                barrierColor: Colors.black.withValues(
                                  alpha: 0.22,
                                ),
                                useSafeArea: true,
                                isScrollControlled: true,
                                builder: (_) => const MoreSheet(),
                              );
                            } else {
                              widget.onTap(index);
                            }
                          },
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavSurface extends StatelessWidget {
  final Widget child;

  const _BottomNavSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 25,
            offset: const Offset(3, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.44),
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.24),
                      ],
                      stops: const [0, 0.52, 1],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.36),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveNavBackground extends StatelessWidget {
  final double size;

  const _ActiveNavBackground({required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final double size;
  final double iconSize;
  final double horizontalPadding;
  final VoidCallback onTap;

  const _BottomNavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.size,
    required this.iconSize,
    required this.horizontalPadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!isSelected) const _InactiveNavGlass(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        icon,
                        key: ValueKey('${icon.codePoint}-$isSelected'),
                        size: iconSize,
                        color: isSelected ? Colors.white : context.brandPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InactiveNavGlass extends StatelessWidget {
  const _InactiveNavGlass();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withValues(alpha: 0)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.34),
                blurRadius: 12,
                offset: const Offset(-6, -6),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.58),
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.04),
                ],
                stops: const [0, 0.52, 1],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: RadialGradient(
                  center: const Alignment(-0.65, -0.75),
                  radius: 1.15,
                  colors: [
                    Colors.white.withValues(alpha: 0.38),
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
