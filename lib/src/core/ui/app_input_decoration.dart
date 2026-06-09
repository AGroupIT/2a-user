import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_layout.dart';

const double kAppInputRadius = 10;
const double kAppInputLargeRadius = 14;

typedef AppOutlinedInputFrameBuilder =
    Widget Function(BuildContext context, FocusNode focusNode);

OutlineInputBorder appInputBorder(
  Color color, {
  double radius = kAppInputRadius,
  double width = 1,
}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: width),
  );
}

InputDecoration appInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? suffixText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  TextStyle? hintStyle,
  TextStyle? labelStyle,
  EdgeInsetsGeometry? contentPadding,
  bool isDense = false,
  Color? fillColor,
  Color? borderColor,
  Color? focusedBorderColor,
  Color? errorBorderColor,
  double radius = kAppInputRadius,
  double focusedWidth = 1.5,
}) {
  final resolvedBorderColor =
      borderColor ?? Colors.white.withValues(alpha: 0.70);
  final resolvedFocusedColor = focusedBorderColor ?? context.brandPrimary;
  final resolvedErrorColor = errorBorderColor ?? const Color(0xFFE53935);
  final scale = AppLayout.compactScale(context);
  final effectiveRadius = radius * scale;
  final defaultPadding = EdgeInsets.symmetric(
    horizontal: 14 * scale,
    vertical: 12 * scale,
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    labelStyle: labelStyle,
    hintStyle: hintStyle,
    isDense: isDense,
    filled: true,
    fillColor: fillColor ?? Colors.white.withValues(alpha: 0.75),
    contentPadding: contentPadding ?? defaultPadding,
    border: appInputBorder(resolvedBorderColor, radius: effectiveRadius),
    enabledBorder: appInputBorder(resolvedBorderColor, radius: effectiveRadius),
    focusedBorder: appInputBorder(
      resolvedFocusedColor,
      radius: effectiveRadius,
      width: focusedWidth,
    ),
    errorBorder: appInputBorder(resolvedErrorColor, radius: effectiveRadius),
    focusedErrorBorder: appInputBorder(
      resolvedErrorColor,
      radius: effectiveRadius,
      width: focusedWidth,
    ),
    disabledBorder: appInputBorder(
      resolvedBorderColor.withValues(alpha: 0.55),
      radius: effectiveRadius,
    ),
  );
}

class AppGradientInputFrame extends StatelessWidget {
  final Widget child;
  final double radius;
  final double borderWidth;
  final Color fillColor;
  final EdgeInsetsGeometry? margin;

  const AppGradientInputFrame({
    super.key,
    required this.child,
    this.radius = kAppInputLargeRadius,
    this.borderWidth = 1.5,
    this.fillColor = Colors.white,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final scale = AppLayout.compactScale(context);
    final effectiveRadius = radius * scale;
    final innerRadius = (effectiveRadius - borderWidth)
        .clamp(0, effectiveRadius)
        .toDouble();

    Widget result = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.brandPrimary, context.brandSecondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(effectiveRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: ColoredBox(color: fillColor, child: child),
        ),
      ),
    );

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }

    return result;
  }
}

class AppOutlinedInputFrame extends StatefulWidget {
  final AppOutlinedInputFrameBuilder builder;
  final double? height;
  final double radius;
  final double borderWidth;
  final double focusedBorderWidth;
  final Color fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final bool enabled;
  final EdgeInsetsGeometry? margin;

  const AppOutlinedInputFrame({
    super.key,
    required this.builder,
    this.height,
    this.radius = kAppInputLargeRadius,
    this.borderWidth = 1,
    this.focusedBorderWidth = 1.5,
    this.fillColor = Colors.white,
    this.borderColor,
    this.focusedBorderColor,
    this.enabled = true,
    this.margin,
  });

  @override
  State<AppOutlinedInputFrame> createState() => _AppOutlinedInputFrameState();
}

class _AppOutlinedInputFrameState extends State<AppOutlinedInputFrame> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.enabled && _focusNode.hasFocus;
    final normalBorderColor = widget.borderColor ?? const Color(0xFFE3E7EE);
    final borderColor = widget.enabled
        ? (focused
              ? widget.focusedBorderColor ?? context.brandPrimary
              : normalBorderColor)
        : normalBorderColor.withValues(alpha: 0.58);

    final scale = AppLayout.compactScale(context);
    final effectiveRadius = widget.radius * scale;
    final effectiveHeight = widget.height == null
        ? null
        : widget.height! * scale;

    Widget result = AnimatedContainer(
      height: effectiveHeight,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.enabled
            ? widget.fillColor
            : widget.fillColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(effectiveRadius),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: (widget.focusedBorderColor ?? context.brandPrimary)
                      .withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: borderColor,
          width: focused ? widget.focusedBorderWidth : widget.borderWidth,
        ),
      ),
      child: widget.builder(context, _focusNode),
    );

    if (widget.margin != null) {
      result = Padding(padding: widget.margin!, child: result);
    }

    return result;
  }
}
