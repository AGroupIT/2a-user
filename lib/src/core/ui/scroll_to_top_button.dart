import 'package:flutter/material.dart';

/// Кнопка «Наверх» — появляется при прокрутке вниз.
/// Использовать внутри Stack:
/// ```dart
/// Stack(children: [
///   ListView(..., controller: _scrollController),
///   ScrollToTopButton(controller: _scrollController),
/// ])
/// ```
class ScrollToTopButton extends StatefulWidget {
  final ScrollController controller;
  final double showAfterOffset;

  const ScrollToTopButton({
    super.key,
    required this.controller,
    this.showAfterOffset = 300,
  });

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ScrollToTopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final positions = widget.controller.positions;
    final show = positions.length == 1 &&
        positions.first.pixels > widget.showAfterOffset;
    if (show != _visible) {
      setState(() => _visible = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: MediaQuery.of(context).padding.bottom + 16,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_visible,
          child: GestureDetector(
            onTap: () {
              widget.controller.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
