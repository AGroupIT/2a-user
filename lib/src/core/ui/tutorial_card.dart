import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/demo_mode_provider.dart';
import '../services/showcase_service.dart';

/// Один шаг обучающей подсказки.
class TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  /// Если задан — при переходе на этот шаг экран проскролит к виджету
  /// с этим ключом и выделит его прожектором.
  final GlobalKey? targetKey;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    this.targetKey,
  });
}

/// Оборачивает экран и показывает обучающий оверлей,
/// когда активен режим обучения ([demoModeProvider] == true).
class TutorialScreenWrapper extends ConsumerWidget {
  final String screenKey;
  final List<TutorialStep> steps;
  final Widget child;

  const TutorialScreenWrapper({
    required this.screenKey,
    required this.steps,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemoMode = ref.watch(demoModeProvider);
    if (!isDemoMode || steps.isEmpty) return child;

    // _TutorialOverlay рендерится через корневой Overlay (SizedBox.shrink),
    // поэтому Stack здесь нужен только чтобы смонтировать виджет.
    return Stack(
      children: [
        child,
        _TutorialOverlay(screenKey: screenKey, steps: steps),
      ],
    );
  }
}

// ─── Overlay ──────────────────────────────────────────────────────────────────

class _TutorialOverlay extends ConsumerStatefulWidget {
  final String screenKey;
  final List<TutorialStep> steps;

  const _TutorialOverlay({required this.screenKey, required this.steps});

  @override
  ConsumerState<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<_TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  bool _visible = false;
  late AnimationController _ctrl;
  Rect? _spotlightRect;

  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Перерисовываем OverlayEntry на каждом кадре анимации
    _ctrl.addListener(_markNeedsBuild);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final svc = ref.read(showcaseServiceProvider);
      if (!svc.hasSeenTutorial(widget.screenKey)) {
        _visible = true;
        _insertOverlay();
        _ctrl.forward();
        _scrollToStep(0);
        _updateSpotlight(0);
      }
    });
  }

  void _markNeedsBuild() => _entry?.markNeedsBuild();

  void _insertOverlay() {
    _entry = OverlayEntry(builder: _buildOverlayContent);
    // rootOverlay: true — рендерится поверх навигации, TabBar и т.д.
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _ctrl.removeListener(_markNeedsBuild);
    _ctrl.dispose();
    super.dispose();
  }

  /// Прокручивает к виджету текущего шага.
  void _scrollToStep(int stepIndex) {
    if (stepIndex >= widget.steps.length) return;
    final key = widget.steps[stepIndex].targetKey;
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.25,
      );
    });
  }

  /// Вычисляет Rect целевого виджета в глобальных (экранных) координатах.
  /// Оверлей покрывает весь экран, поэтому глобальные == локальные координаты.
  /// Если виджет ещё не смонтирован (данные грузятся асинхронно) — повторяет
  /// попытку до [_maxRetries] раз с интервалом 200 мс.
  static const int _maxRetries = 8;

  void _updateSpotlight(int stepIndex, {int retryCount = 0}) {
    if (stepIndex >= widget.steps.length) {
      _spotlightRect = null;
      _markNeedsBuild();
      return;
    }
    final key = widget.steps[stepIndex].targetKey;
    if (key == null) {
      _spotlightRect = null;
      _markNeedsBuild();
      return;
    }

    // Захватываем RenderBox ДО асинхронного разрыва
    final targetBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) {
      // Виджет ещё не смонтирован — повторяем попытку (асинхронная загрузка)
      if (retryCount < _maxRetries) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          _updateSpotlight(stepIndex, retryCount: retryCount + 1);
        });
      }
      return;
    }

    // Ждём завершения скролла (400ms) + небольшой запас
    Future.delayed(const Duration(milliseconds: 460), () {
      if (!mounted) return;
      if (!targetBox.hasSize) return;

      const pad = 10.0;
      final globalPos = targetBox.localToGlobal(Offset.zero);
      final size = targetBox.size;

      _spotlightRect = Rect.fromLTWH(
        globalPos.dx - pad,
        globalPos.dy - pad,
        size.width + pad * 2,
        size.height + pad * 2,
      );
      _markNeedsBuild();
    });
  }

  Future<void> _next() async {
    if (_step < widget.steps.length - 1) {
      _step++;
      _spotlightRect = null;
      _markNeedsBuild();
      _scrollToStep(_step);
      _updateSpotlight(_step);
    } else {
      await _dismiss(disableDemo: false);
    }
  }

  Future<void> _dismiss({bool disableDemo = false}) async {
    final svc = ref.read(showcaseServiceProvider);
    final router = GoRouter.of(context); // захватываем до async gap
    await _ctrl.reverse();
    if (!mounted) return;
    await svc.markTutorialSeen(widget.screenKey);
    _visible = false;
    _removeOverlay();
    if (disableDemo) {
      ref.read(demoModeProvider.notifier).disable();
      return;
    }
    // Тур завершён — отключаем демо-режим автоматически
    if (svc.isTourComplete()) {
      ref.read(demoModeProvider.notifier).disable();
      return;
    }
    final nextRoute = svc.nextTourRoute(widget.screenKey);
    if (nextRoute != null && mounted) {
      router.go(nextRoute);
    }
  }

  /// Этот виджет не рендерит ничего напрямую — всё через OverlayEntry.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  Widget _buildOverlayContent(BuildContext ctx) {
    if (!_visible) return const SizedBox.shrink();

    final mq = MediaQuery.of(ctx);
    final screenHeight = mq.size.height;
    final bottomPad = mq.padding.bottom;
    final topPad = mq.padding.top;
    final brandColor = Theme.of(ctx).colorScheme.primary;

    // Карточка сверху, если прожектор в нижней половине экрана
    final spotlightLow = _spotlightRect != null &&
        _spotlightRect!.center.dy > screenHeight * 0.55;

    final animValue = _ctrl.value;

    return Positioned.fill(
      child: Stack(
        children: [
          // ── Затемнение с прожектором ─────────────────────────────────────
          Positioned.fill(
            child: Opacity(
              opacity: animValue,
              child: CustomPaint(
                painter: _SpotlightPainter(
                  spotlight: _spotlightRect,
                  radius: 14,
                ),
              ),
            ),
          ),

          // ── Рамка прожектора ─────────────────────────────────────────────
          if (_spotlightRect != null)
            Positioned(
              left: _spotlightRect!.left - 2,
              top: _spotlightRect!.top - 2,
              width: _spotlightRect!.width + 4,
              height: _spotlightRect!.height + 4,
              child: Opacity(
                opacity: animValue,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.75),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Карточка-подсказка ────────────────────────────────────────────
          if (spotlightLow)
            Positioned(
              left: 16,
              right: 16,
              top: topPad + 16,
              child: _buildCard(ctx, brandColor),
            )
          else
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomPad + 90,
              child: _buildCard(ctx, brandColor),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext ctx, Color brandColor) {
    final step = widget.steps[_step];
    final isLast = _step == widget.steps.length - 1;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: _ctrl,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Индикатор шагов + кнопка выхода
                  Row(
                    children: [
                      ...List.generate(widget.steps.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _step ? 22 : 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: i == _step
                                ? brandColor
                                : brandColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _dismiss(disableDemo: true),
                        child: Text(
                          'Завершить обучение',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Иконка + заголовок
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          step.icon,
                          color: brandColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            step.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Описание
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Кнопка «Далее» / «Понятно!»
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        isLast ? 'Понятно!' : 'Далее →',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
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

// ─── Spotlight painter ────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect? spotlight;
  final double radius;

  const _SpotlightPainter({this.spotlight, this.radius = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xAA000000);

    if (spotlight == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(spotlight!, Radius.circular(radius)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotlight != spotlight || old.radius != radius;
}
