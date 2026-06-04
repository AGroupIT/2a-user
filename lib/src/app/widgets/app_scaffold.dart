import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/app_background.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/app_layout.dart';
import '../../core/ui/pixso_top_menu_surface.dart';
import '../../features/clients/presentation/client_switcher_button.dart';
import '../../features/notifications/application/notifications_controller.dart';
import '../../features/notifications/domain/notification_item.dart';
import '../../features/notifications/presentation/notifications_bell_button.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showBack;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusTop = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    final overlayStyle = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              const Positioned.fill(child: AppBackground()),
              Padding(
                padding: EdgeInsets.only(top: statusTop),
                child: ClipRect(child: child),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppFloatingTopBar(title: title, showBack: showBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppFloatingTopBar extends StatelessWidget {
  final String title;
  final bool showBack;

  const AppFloatingTopBar({
    super.key,
    required this.title,
    required this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlayStyle = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          top + AppLayout.topBarTopMargin,
          14,
          AppLayout.topBarBottomGap,
        ),
        child: _buildTopBarSurface(
          context: context,
          content: const _TopBarContent(),
        ),
      ),
    );
  }
}

Widget _buildTopBarSurface({
  required BuildContext context,
  required Widget content,
}) {
  // Transparent container - glass effect only on individual buttons
  return SizedBox(height: AppLayout.topBarHeight, child: content);
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          fit: FlexFit.loose,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClientSwitcherButton(),
          ),
        ),
        const _ActionsPill(),
      ],
    );
  }
}

class _ActionsPill extends ConsumerWidget {
  const _ActionsPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsControllerProvider);
    final hasUnreadSupportChat =
        notifications.value?.any(
          (item) => !item.isRead && item.type == NotificationType.chatMessage,
        ) ??
        false;

    return PixsoTopMenuSurface(
      width: 116,
      padding: const EdgeInsets.all(7),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TopBarActionButton(
              tooltip: 'Главная',
              icon: CupertinoIcons.house,
              highlighted: true,
              onTap: () => context.go('/'),
            ),
            const SizedBox(width: 6),
            const NotificationsBellButton(),
            const SizedBox(width: 6),
            _TopBarActionButton(
              tooltip: 'Чат поддержки',
              icon: CupertinoIcons.chat_bubble_2,
              hasBadge: hasUnreadSupportChat,
              onTap: () => context.go('/support'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool hasBadge;
  final bool highlighted;
  final VoidCallback onTap;

  const _TopBarActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.hasBadge = false,
    this.highlighted = false,
  });

  static const _contentColor = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PixsoTopMenuActionSurface(
                highlighted: highlighted,
                child: Icon(
                  icon,
                  size: 18.5,
                  color: highlighted ? context.brandPrimary : _contentColor,
                ),
              ),
              if (hasBadge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
