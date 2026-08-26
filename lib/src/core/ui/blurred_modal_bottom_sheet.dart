import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_layout.dart';

const _mobileSheetBorderRadius = BorderRadius.vertical(
  top: Radius.circular(30),
);

/// Project-wide modal bottom sheet with a dimmed + softly blurred backdrop.
///
/// It intentionally mirrors the common subset of [showModalBottomSheet]
/// arguments used in this app, so existing sheets can switch to it without
/// rewriting their inner content. The sheet content still owns its internal
/// layout, fixed handle and keyboard rules. Bottom system navigation insets are
/// protected by default so actions stay reachable on Android devices with
/// gesture or three-button navigation.
Future<T?> showBlurredModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool useSafeArea = true,
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
    if (AppLayout.useSideNavigation(context)) {
      final dx = details.primaryDelta ?? 0;
      if (dx <= 0 && _dragOffset <= 0) return;
      setState(() => _dragOffset = (_dragOffset + dx).clamp(0.0, 1000.0));
      return;
    }

    final dy = details.primaryDelta ?? 0;
    if (dy <= 0 && _dragOffset <= 0) return;
    setState(() => _dragOffset = (_dragOffset + dy).clamp(0.0, 1000.0));
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enableDrag) return;
    final velocity = details.primaryVelocity ?? 0;
    if (AppLayout.useSideNavigation(context)) {
      final shouldClose = velocity > 650 || _dragOffset > 96;
      if (shouldClose) {
        Navigator.of(context).maybePop();
        return;
      }
      if (_dragOffset != 0) setState(() => _dragOffset = 0);
      return;
    }

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
    final useSideSheet = AppLayout.useSideNavigation(context);
    final modalMaxWidth = useSideSheet
        ? mediaSize.width * 0.6
        : AppLayout.modalMaxWidth(context);
    final maxWidth = modalMaxWidth.clamp(0.0, mediaSize.width).toDouble();
    final maxHeight = useSideSheet
        ? mediaSize.height
        : widget.isScrollControlled
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

    sheet = ConstrainedBox(
      constraints: routeConstraints,
      child: SizedBox(
        width: maxWidth,
        height: useSideSheet ? mediaSize.height : null,
        child: sheet,
      ),
    );

    if (useSideSheet) {
      sheet = ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
        child: ColoredBox(color: Colors.white, child: sheet),
      );
    } else {
      // Paint the inset together with the modal surface. Wrapping only with
      // SafeArea leaves a transparent strip above Android system navigation
      // when callers use a transparent route background.
      if (widget.useSafeArea) {
        sheet = ColoredBox(
          color: Colors.white,
          child: SafeArea(top: false, child: sheet),
        );
      }

      // Clip the complete surface so every mobile sheet has the same rounded
      // top corners, including legacy sheets whose inner content is
      // rectangular.
      sheet = ClipRRect(borderRadius: _mobileSheetBorderRadius, child: sheet);
    }

    if (widget.enableDrag) {
      sheet = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: useSideSheet ? null : _onDragUpdate,
        onVerticalDragEnd: useSideSheet ? null : _onDragEnd,
        onHorizontalDragUpdate: useSideSheet ? _onDragUpdate : null,
        onHorizontalDragEnd: useSideSheet ? _onDragEnd : null,
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
            if (useSideSheet)
              Align(
                alignment: Alignment.centerRight,
                child: FractionalTranslation(
                  translation: Offset(1 - eased, 0),
                  child: Transform.translate(
                    offset: Offset(_dragOffset, 0),
                    child: child,
                  ),
                ),
              )
            else
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
