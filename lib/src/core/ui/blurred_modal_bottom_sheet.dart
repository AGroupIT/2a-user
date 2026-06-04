import 'dart:ui';

import 'package:flutter/material.dart';

/// Project-wide modal bottom sheet with a dimmed + softly blurred backdrop.
///
/// It intentionally mirrors the common subset of [showModalBottomSheet]
/// arguments used in this app, so existing sheets can switch to it without
/// rewriting their inner content. The sheet content still owns its internal
/// layout, fixed handle, safe-area and keyboard rules.
Future<T?> showBlurredModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  RouteSettings? routeSettings,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final capturedThemes = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );

  return navigator.push<T>(
    _BlurredModalBottomSheetRoute<T>(
      builder: builder,
      capturedThemes: capturedThemes,
      backgroundColor: backgroundColor,
      modalBarrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.24),
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      settings: routeSettings,
      modalBarrierLabel: MaterialLocalizations.of(
        context,
      ).modalBarrierDismissLabel,
    ),
  );
}

class _BlurredModalBottomSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;
  final Color? backgroundColor;
  final Color modalBarrierColor;
  final bool isScrollControlled;
  final bool useSafeArea;
  final bool isDismissible;
  final bool enableDrag;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;
  final String modalBarrierLabel;

  _BlurredModalBottomSheetRoute({
    required this.builder,
    required this.capturedThemes,
    required this.modalBarrierColor,
    required this.isScrollControlled,
    required this.useSafeArea,
    required this.isDismissible,
    required this.enableDrag,
    required this.modalBarrierLabel,
    this.backgroundColor,
    this.shape,
    this.clipBehavior,
    this.constraints,
    super.settings,
  });

  @override
  bool get barrierDismissible => isDismissible;

  @override
  Color? get barrierColor => modalBarrierColor;

  @override
  String? get barrierLabel => modalBarrierLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 210);

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return capturedThemes.wrap(
      _BlurredModalBottomSheetPage<T>(
        animation: animation,
        builder: builder,
        backgroundColor: backgroundColor,
        isScrollControlled: isScrollControlled,
        useSafeArea: useSafeArea,
        enableDrag: enableDrag,
        shape: shape,
        clipBehavior: clipBehavior,
        constraints: constraints,
      ),
    );
  }
}

class _BlurredModalBottomSheetPage<T> extends StatefulWidget {
  final Animation<double> animation;
  final WidgetBuilder builder;
  final Color? backgroundColor;
  final bool isScrollControlled;
  final bool useSafeArea;
  final bool enableDrag;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;

  const _BlurredModalBottomSheetPage({
    required this.animation,
    required this.builder,
    required this.backgroundColor,
    required this.isScrollControlled,
    required this.useSafeArea,
    required this.enableDrag,
    required this.shape,
    required this.clipBehavior,
    required this.constraints,
  });

  @override
  State<_BlurredModalBottomSheetPage<T>> createState() =>
      _BlurredModalBottomSheetPageState<T>();
}

class _BlurredModalBottomSheetPageState<T>
    extends State<_BlurredModalBottomSheetPage<T>> {
  double _dragOffset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enableDrag) return;
    final dy = details.primaryDelta ?? 0;
    if (dy <= 0 && _dragOffset <= 0) return;
    setState(() => _dragOffset = (_dragOffset + dy).clamp(0.0, 1000.0));
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enableDrag) return;
    final velocity = details.primaryVelocity ?? 0;
    final shouldClose = velocity > 650 || _dragOffset > 96;
    if (shouldClose) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_dragOffset != 0) setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final maxHeight = widget.isScrollControlled
        ? mediaSize.height
        : mediaSize.height * 9 / 16;
    final routeConstraints = widget.constraints == null
        ? BoxConstraints(maxHeight: maxHeight)
        : widget.constraints!.copyWith(
            maxHeight: widget.constraints!.maxHeight.isFinite
                ? widget.constraints!.maxHeight.clamp(0.0, maxHeight)
                : maxHeight,
          );

    Widget sheet = Builder(builder: widget.builder);

    if (widget.backgroundColor != Colors.transparent || widget.shape != null) {
      sheet = Material(
        color: widget.backgroundColor ?? Colors.white,
        shape: widget.shape,
        clipBehavior: widget.clipBehavior ?? Clip.none,
        child: sheet,
      );
    } else {
      sheet = Material(type: MaterialType.transparency, child: sheet);
    }

    sheet = ConstrainedBox(constraints: routeConstraints, child: sheet);

    if (widget.useSafeArea) {
      sheet = SafeArea(top: false, bottom: false, child: sheet);
    }

    if (widget.enableDrag) {
      sheet = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: sheet,
      );
    }

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final eased = Curves.easeOutCubic.transform(widget.animation.value);
        final blurSigma = 4.0 * eased;

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionalTranslation(
                translation: Offset(0, 1 - eased),
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: sheet,
    );
  }
}
