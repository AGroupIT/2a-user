import 'package:flutter/material.dart';

import 'app_colors.dart';

const double kAppInputRadius = 10;
const double kAppInputLargeRadius = 14;

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
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: appInputBorder(resolvedBorderColor, radius: radius),
    enabledBorder: appInputBorder(resolvedBorderColor, radius: radius),
    focusedBorder: appInputBorder(
      resolvedFocusedColor,
      radius: radius,
      width: focusedWidth,
    ),
    errorBorder: appInputBorder(resolvedErrorColor, radius: radius),
    focusedErrorBorder: appInputBorder(
      resolvedErrorColor,
      radius: radius,
      width: focusedWidth,
    ),
    disabledBorder: appInputBorder(
      resolvedBorderColor.withValues(alpha: 0.55),
      radius: radius,
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
    final innerRadius = (radius - borderWidth).clamp(0, radius).toDouble();

    Widget result = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.brandPrimary, context.brandSecondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(radius),
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
