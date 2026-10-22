import 'package:flutter/material.dart';

/// Zoom owns multi-touch/panning; the gallery owns horizontal swipes only at 1x.
/// Dismiss uses raw single-pointer motion, so it cannot win pinch's gesture arena.
class MediaImageViewport extends StatefulWidget {
  const MediaImageViewport({
    super.key,
    required this.imageKey,
    required this.child,
    this.active = true,
    this.onInteractionBlockedChanged,
    this.onDismiss,
  });
  final Object imageKey;
  final Widget child;
  final bool active;
  final ValueChanged<bool>? onInteractionBlockedChanged;
  final VoidCallback? onDismiss;

  @override
  State<MediaImageViewport> createState() => _MediaImageViewportState();
}

class _MediaImageViewportState extends State<MediaImageViewport> {
  final _controller = TransformationController();
  final _pointers = <int>{};
  Offset? _origin;
  Offset _last = Offset.zero;
  Offset _doubleTap = Offset.zero;
  double _dismissDy = 0;
  bool _multiTouch = false;
  bool _blocked = false;
  bool get _zoomed => _controller.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() {
    final blocked = _zoomed || _pointers.length > 1;
    if (blocked == _blocked) return;
    setState(() => _blocked = blocked);
    widget.onInteractionBlockedChanged?.call(blocked);
  }

  @override
  void didUpdateWidget(covariant MediaImageViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageKey != widget.imageKey ||
        oldWidget.active != widget.active) {
      _pointers.clear();
      _origin = null;
      _dismissDy = 0;
      _multiTouch = false;
      _controller.removeListener(_changed);
      _controller.value = Matrix4.identity();
      _controller.addListener(_changed);
      if (_blocked) {
        _blocked = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onInteractionBlockedChanged?.call(false);
        });
      }
    }
  }

  void _down(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length == 1) {
      _origin = event.localPosition;
      _last = event.localPosition;
      _multiTouch = _zoomed;
    } else {
      _multiTouch = true;
      if (_dismissDy != 0) setState(() => _dismissDy = 0);
    }
    _changed();
  }

  void _move(PointerMoveEvent event) {
    _last = event.localPosition;
    if (_multiTouch || _zoomed || _origin == null || _pointers.length != 1) {
      return;
    }
    final delta = _last - _origin!;
    if (delta.dy.abs() > delta.dx.abs() * 1.3) {
      setState(() => _dismissDy = delta.dy);
    }
  }

  void _up(PointerEvent event, {bool cancelled = false}) {
    _pointers.remove(event.pointer);
    final dismiss =
        !cancelled &&
        !_multiTouch &&
        !_zoomed &&
        _origin != null &&
        _dismissDy.abs() > 100 &&
        (_last - _origin!).dy.abs() > (_last - _origin!).dx.abs() * 1.3;
    if (_pointers.isEmpty) {
      _origin = null;
      if (_dismissDy != 0) setState(() => _dismissDy = 0);
    }
    _changed();
    if (dismiss) widget.onDismiss?.call();
  }

  void _toggleZoom() {
    if (_zoomed) {
      _controller.value = Matrix4.identity();
    } else {
      const scale = 2.5;
      _controller.value = Matrix4.identity()
        ..translateByDouble(
          -_doubleTap.dx * (scale - 1),
          -_doubleTap.dy * (scale - 1),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: (event) => _up(event, cancelled: true),
      child: GestureDetector(
        onDoubleTapDown: (details) => _doubleTap = details.localPosition,
        onDoubleTap: _toggleZoom,
        child: Transform.translate(
          offset: Offset(0, _dismissDy),
          child: InteractiveViewer(
            transformationController: _controller,
            panEnabled: _zoomed,
            minScale: 1,
            maxScale: 4,
            onInteractionUpdate: (_) => setState(() {}),
            child: SizedBox.expand(child: widget.child),
          ),
        ),
      ),
    ),
  );
}
