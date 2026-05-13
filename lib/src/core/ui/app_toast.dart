import 'dart:async';

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    IconData? icon,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon ??
                (isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded),
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.25,
            ),
          ),
        ),
      ],
    );

    showContent(
      context,
      content: content,
      isError: isError,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  static void showFromSnackBar(BuildContext context, SnackBar snackBar) {
    final action = snackBar.action;
    final content = action == null
        ? snackBar.content
        : Row(
            children: [
              Expanded(child: snackBar.content),
              const SizedBox(width: 12),
              action,
            ],
          );

    showContent(
      context,
      content: content,
      backgroundColor: snackBar.backgroundColor,
      duration: snackBar.duration,
    );
  }

  static void showContent(
    BuildContext context, {
    required Widget content,
    bool isError = false,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    hide();

    final color =
        backgroundColor ??
        (isError ? const Color(0xFFE53935) : context.brandPrimary);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopToastOverlay(
        backgroundColor: color,
        onDismiss: hide,
        child: content,
      ),
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _TopToastOverlay extends StatefulWidget {
  const _TopToastOverlay({
    required this.child,
    required this.backgroundColor,
    required this.onDismiss,
  });

  final Widget child;
  final Color backgroundColor;
  final VoidCallback onDismiss;

  @override
  State<_TopToastOverlay> createState() => _TopToastOverlayState();
}

class _TopToastOverlayState extends State<_TopToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      left: 14,
      right: 14,
      top: topPadding + 8,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: FadeTransition(
            opacity: _opacity,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: widget.backgroundColor.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.25,
                      ),
                      child: IconTheme.merge(
                        data: const IconThemeData(color: Colors.white),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
