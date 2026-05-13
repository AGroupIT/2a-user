import 'package:flutter/material.dart';

class PixsoTopMenuSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double minWidth;

  const PixsoTopMenuSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.width,
    this.minWidth = 0,
  });

  static const height = 40.0;
  static const _radius = 10.0;
  static const _surfaceColor = Color(0xCCFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      constraints: BoxConstraints(minWidth: minWidth, minHeight: height),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 25,
            spreadRadius: 0,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
