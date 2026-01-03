import 'package:flutter/material.dart';

import 'app_colors.dart';

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
      child: Icon(icon, size: 22),
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
    final isCircular = widget.width == widget.height;
    final borderRadius = isCircular ? widget.height / 2 : 10.0;

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
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isHovered && _isEnabled
                      ? [
                          AppColors.brandOrangeDark.withValues(alpha: 0.85),
                          AppColors.brandOrangeLight.withValues(alpha: 0.85),
                        ]
                      : [AppColors.brandOrangeDark, AppColors.brandOrangeLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: _isPressed
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.brandOrange.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          child: IconTheme(
                            data: const IconThemeData(
                              color: Colors.white,
                              size: 22,
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
      child: Icon(icon, size: 22),
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
    final isCircular = widget.width == widget.height;
    final borderRadius = isCircular ? widget.height / 2 : 10.0;

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
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.brandOrangeDark,
                    AppColors.brandOrangeLight,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: const EdgeInsets.all(1.5),
              child: Container(
                decoration: BoxDecoration(
                  color: _isHovered && _isEnabled
                      ? AppColors.brandOrange.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius - 1.5),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.brandOrange,
                              ),
                            ),
                          )
                        : DefaultTextStyle(
                            style: const TextStyle(
                              color: AppColors.brandOrange,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            child: IconTheme(
                              data: const IconThemeData(
                                color: AppColors.brandOrange,
                                size: 22,
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
