import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/ui/sheet_handle.dart';

class SpFinanceHeaderActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String? tooltip;
  final Key? buttonKey;

  const SpFinanceHeaderActionButton({
    super.key,
    required this.onTap,
    required this.child,
    this.tooltip,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 46,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                spreadRadius: -12,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );

    final message = tooltip;
    return message == null ? button : Tooltip(message: message, child: button);
  }
}

Future<T?> showSpFinanceModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showBlurredModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.22),
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: builder,
  );
}

Future<bool?> showSpFinanceConfirmationSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) {
  return showSpFinanceModalSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final confirmColor = destructive
          ? const Color(0xFFE5484D)
          : sheetContext.brandPrimary;

      return SpFinanceModalSurface(
        key: const ValueKey('sp-finance-modal-surface'),
        icon: icon,
        title: title,
        subtitle: message,
        body: const SizedBox.shrink(),
        footer: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: Color(0xFFE1E5ED)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class SpFinanceModalSurface extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final EdgeInsetsGeometry contentPadding;
  final double maxHeightFactor;
  final bool keyboardAware;
  final bool showCloseButton;

  const SpFinanceModalSurface({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.maxHeightFactor = 0.9,
    this.keyboardAware = false,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final useSideSheet = AppLayout.useSideNavigation(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = keyboardAware
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        height: useSideSheet ? mediaSize.height : null,
        constraints: BoxConstraints(
          maxHeight: useSideSheet
              ? mediaSize.height
              : mediaSize.height * maxHeightFactor,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: useSideSheet
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: useSideSheet ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!useSideSheet) const SheetHandle(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      useSideSheet ? 20 : 0,
                      12,
                      16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: context.brandPrimary.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            icon,
                            color: context.brandPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Gilroy',
                                    fontSize: 20,
                                    height: 1.1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (subtitle != null &&
                                    subtitle!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitle!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Gilroy',
                                      fontSize: 12.5,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (showCloseButton)
                          IconButton(
                            tooltip: 'Закрыть',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE9ECF2)),
            Flexible(
              child: Padding(padding: contentPadding, child: body),
            ),
            if (footer != null) ...[
              const Divider(height: 1, color: Color(0xFFE9ECF2)),
              ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + safeBottom),
                  child: footer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SpFinanceUi {
  const SpFinanceUi._();

  static const textColor = Color(0xFF2F2F2F);
  static const mutedTextColor = Color(0x992F2F2F);

  static BoxDecoration cardDecoration({Color color = Colors.white}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 24,
          spreadRadius: -14,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }

  static BoxDecoration softDecoration(BuildContext context) {
    return BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black.withValues(alpha: 0.025)),
    );
  }

  static TextStyle get sectionTitleStyle {
    return const TextStyle(
      color: AppColors.textPrimary,
      fontFamily: 'Gilroy',
      fontSize: 18,
      height: 22 / 18,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.15,
    );
  }

  static TextStyle get bodyStyle {
    return const TextStyle(
      color: AppColors.textPrimary,
      fontFamily: 'Gilroy',
      fontSize: 14,
      height: 18 / 14,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle get labelStyle {
    return const TextStyle(
      color: AppColors.textSecondary,
      fontFamily: 'Gilroy',
      fontSize: 12,
      height: 14 / 12,
      fontWeight: FontWeight.w700,
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    String? suffixText,
    IconData? prefixIcon,
  }) {
    return appInputDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      suffixText: suffixText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      labelStyle: labelStyle,
      hintStyle: const TextStyle(
        color: Color(0xFFB0B4BE),
        fontFamily: 'Gilroy',
        fontSize: 14,
        height: 16 / 14,
        fontWeight: FontWeight.w600,
      ),
      fillColor: const Color(0xFFF8FAFC),
      borderColor: const Color(0xFFE1E5ED),
      focusedBorderColor: context.brandPrimary,
      radius: 18,
      focusedWidth: 1.6,
    );
  }

  static Color? parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    final value = int.tryParse(buffer.toString(), radix: 16);
    return value == null ? null : Color(value);
  }
}

class SpPageHeader extends StatelessWidget {
  final String title;
  final String fallbackRoute;
  final Widget? trailing;

  const SpPageHeader({
    super.key,
    required this.title,
    this.fallbackRoute = '/',
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(fallbackRoute);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.035),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    spreadRadius: -12,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class SpHeroChip extends StatelessWidget {
  final IconData? icon;
  final String label;

  const SpHeroChip({super.key, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontSize: 12.5,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SpInfoNotice extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? trailing;

  const SpInfoNotice({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 13.5,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class SpCurrencySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const SpCurrencySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Row(
        children: [
          _CurrencyButton(
            label: 'Юани ¥',
            selected: value == 'CNY',
            onTap: () => onChanged('CNY'),
          ),
          const SizedBox(width: 6),
          _CurrencyButton(
            label: 'Рубли ₽',
            selected: value == 'RUB',
            onTap: () => onChanged('RUB'),
          ),
        ],
      ),
    );
  }
}

class _CurrencyButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? context.brandPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 42,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SpAnimatedHeroSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const SpAnimatedHeroSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            const Positioned.fill(child: SpAnimatedHeroGlowBackdrop()),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class SpAnimatedHeroGlowBackdrop extends StatefulWidget {
  const SpAnimatedHeroGlowBackdrop({super.key});

  @override
  State<SpAnimatedHeroGlowBackdrop> createState() =>
      _SpAnimatedHeroGlowBackdropState();
}

class _SpAnimatedHeroGlowBackdropState extends State<SpAnimatedHeroGlowBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final wave = Curves.easeInOutCubic.transform(_controller.value);
            final shift = (wave * 2) - 1;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -62,
                  top: -58,
                  child: Transform.translate(
                    offset: Offset(-10 * shift, 6 * shift),
                    child: _SpHeroGlowCircle(
                      size: 154,
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                Positioned(
                  right: 22,
                  bottom: -68,
                  child: Transform.translate(
                    offset: Offset(9 * shift, -7 * shift),
                    child: _SpHeroGlowCircle(
                      size: 152,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: -14,
                  bottom: 16,
                  child: Transform.translate(
                    offset: Offset(5 * shift, -4 * shift),
                    child: _SpHeroGlowCircle(
                      size: 82,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SpHeroGlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _SpHeroGlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
