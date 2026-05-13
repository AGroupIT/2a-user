import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final List<Widget> actions;

  const AppPageHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack) ...[const _PageBackButton(), const SizedBox(width: 10)],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 24,
                height: 29 / 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F2F2F),
                letterSpacing: 0,
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 16),
            for (var index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              actions[index],
            ],
          ],
        ],
      ),
    );
  }
}

class AppPageHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const AppPageHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? context.brandPrimary : const Color(0xFF2F2F2F);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: Icon(icon, size: 23, color: color)),
          ),
        ),
      ),
    );
  }
}

class _PageBackButton extends StatelessWidget {
  const _PageBackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/more');
        }
      },
      child: Container(
        width: 20,
        height: 36,
        alignment: Alignment.centerLeft,
        child: Icon(
          CupertinoIcons.chevron_left,
          size: 20,
          color: Color(0xFF2F2F2F),
        ),
      ),
    );
  }
}
