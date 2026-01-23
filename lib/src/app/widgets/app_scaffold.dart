import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/app_background.dart';
import '../../core/ui/app_layout.dart';
import '../../core/ui/glass_surface.dart';
import '../../features/clients/presentation/client_switcher_button.dart';
import '../../features/notifications/presentation/notifications_bell_button.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showBack;
  final bool showSearch;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showBack = true,
    this.showSearch = true,
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
              // Allow content to extend under the floating top bar (for true blur)
              Padding(
                padding: EdgeInsets.only(top: statusTop),
                child: ClipRect(child: child),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppFloatingTopBar(
                  title: title,
                  showBack: showBack,
                  showSearch: showSearch,
                ),
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
  final bool showSearch;

  const AppFloatingTopBar({
    super.key,
    required this.title,
    required this.showBack,
    this.showSearch = true,
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
          content: _TopBarContent(
            title: title,
            showBack: showBack,
            showSearch: showSearch,
          ),
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
  return SizedBox(
    height: AppLayout.topBarHeight,
    child: content,
  );
}

class _TopBarContent extends StatelessWidget {
  final String title;
  final bool showBack;
  final bool showSearch;

  const _TopBarContent({
    required this.title,
    required this.showBack,
    required this.showSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          IconButton(
            tooltip: 'Назад',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        const ClientSwitcherButton(),
        const Spacer(),
        if (showSearch)
          _ActionsPill(onSearch: () => context.push('/search'))
        else
          const _ActionsPill(),
      ],
    );
  }
}

class _ActionsPill extends StatelessWidget {
  final VoidCallback? onSearch;

  const _ActionsPill({this.onSearch});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(999),
      blur: 40,
      useLiquidEffect: true,
      saturation: 1.7,
      tintColor: Colors.white.withValues(alpha: 0.08),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.50),
        width: 1.0,
      ),
      addHighlights: false,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      noiseOpacity: 0.0,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: IconButtonTheme(
          data: IconButtonThemeData(
            style: ButtonStyle(
              iconSize: const WidgetStatePropertyAll(22),
              minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
              padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              overlayColor: WidgetStatePropertyAll(
                Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Домой',
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_rounded),
                ),
              ),
              const NotificationsBellButton(),
              if (onSearch != null)
                IconButton(
                  tooltip: 'Поиск',
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
