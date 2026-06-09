import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_layout.dart';

/// Основная кнопка с градиентным фоном
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.width,
    this.height = 48,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final double? width;
  final double height;

  factory PrimaryButton.text({
    Key? key,
    required VoidCallback? onPressed,
    required String text,
    bool isLoading = false,
    double? width,
    double height = 48,
  }) {
    return PrimaryButton(
      key: key,
      onPressed: onPressed,
      isLoading: isLoading,
      width: width,
      height: height,
      child: Text(text),
    );
  }

  factory PrimaryButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required IconData icon,
    bool isLoading = false,
    double size = 48,
  }) {
    return PrimaryButton(
      key: key,
      onPressed: onPressed,
      isLoading: isLoading,
      width: size,
      height: size,
      child: Icon(icon),
    );
  }

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final scale = AppLayout.compactScale(context);
    final effectiveWidth = widget.width == null || !widget.width!.isFinite
        ? widget.width
        : widget.width! * scale;
    final effectiveHeight = widget.height * scale;
    final isCircular = widget.width == widget.height;
    final borderRadius = isCircular ? effectiveHeight / 2 : 10.0 * scale;
    final brandPrimary = context.brandPrimary;
    final brandGradient = context.brandGradient;
    final hoverGradient = LinearGradient(
      colors: brandGradient.colors
          .map((color) => color.withValues(alpha: 0.85))
          .toList(),
      begin: brandGradient.begin,
      end: brandGradient.end,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: _isEnabled
            ? () => setState(() => _isPressed = false)
            : null,
        onTap: _isEnabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isEnabled ? 1.0 : 0.5,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: _isPressed ? 0.97 : 1.0,
            child: Container(
              width: effectiveWidth,
              height: effectiveHeight,
              decoration: BoxDecoration(
                gradient: _isHovered && _isEnabled
                    ? hoverGradient
                    : brandGradient,
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: _isPressed
                    ? []
                    : [
                        BoxShadow(
                          color: brandPrimary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 22 * scale,
                          height: 22 * scale,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          child: IconTheme(
                            data: IconThemeData(
                              color: Colors.white,
                              size: 22 * scale,
                            ),
                            child: widget.child,
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

/// Дополнительная кнопка с белым фоном и градиентным бордером
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.width,
    this.height = 48,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final double? width;
  final double height;

  factory SecondaryButton.text({
    Key? key,
    required VoidCallback? onPressed,
    required String text,
    bool isLoading = false,
    double? width,
    double height = 48,
  }) {
    return SecondaryButton(
      key: key,
      onPressed: onPressed,
      isLoading: isLoading,
      width: width,
      height: height,
      child: Text(text),
    );
  }

  factory SecondaryButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required IconData icon,
    bool isLoading = false,
    double size = 48,
  }) {
    return SecondaryButton(
      key: key,
      onPressed: onPressed,
      isLoading: isLoading,
      width: size,
      height: size,
      child: Icon(icon),
    );
  }

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final scale = AppLayout.compactScale(context);
    final effectiveWidth = widget.width == null || !widget.width!.isFinite
        ? widget.width
        : widget.width! * scale;
    final effectiveHeight = widget.height * scale;
    final isCircular = widget.width == widget.height;
    final borderRadius = isCircular ? effectiveHeight / 2 : 10.0 * scale;
    final brandPrimary = context.brandPrimary;
    final brandGradient = context.brandGradient;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: _isEnabled
            ? () => setState(() => _isPressed = false)
            : null,
        onTap: _isEnabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isEnabled ? 1.0 : 0.5,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: _isPressed ? 0.97 : 1.0,
            child: Container(
              width: effectiveWidth,
              height: effectiveHeight,
              decoration: BoxDecoration(
                gradient: brandGradient,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: const EdgeInsets.all(1.5),
              child: Container(
                decoration: BoxDecoration(
                  color: _isHovered && _isEnabled
                      ? brandPrimary.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius - 1.5),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 22 * scale,
                            height: 22 * scale,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(brandPrimary),
                            ),
                          )
                        : DefaultTextStyle(
                            style: TextStyle(
                              color: brandPrimary,
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            child: IconTheme(
                              data: IconThemeData(
                                color: brandPrimary,
                                size: 22 * scale,
                              ),
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
