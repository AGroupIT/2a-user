import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';

import '../../../core/ui/sheet_handle.dart';

class MoreSheet extends StatelessWidget {
  const MoreSheet({super.key});

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      'Меню',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MenuItem(
                      icon: Icons.person_rounded,
                      title: 'Профиль',
                      onTap: () => _go(context, '/profile'),
                    ),
                    const SizedBox(height: 8),
                    _MenuItem(
                      icon: Icons.support_agent_rounded,
                      title: 'Чат с поддержкой',
                      onTap: () => _go(context, '/support'),
                    ),
                    const SizedBox(height: 8),
                    _MenuItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Чат по оплате',
                      iconColor: const Color(0xFF4CAF50),
                      onTap: () => _go(context, '/payment-chat'),
                    ),
                    const SizedBox(height: 8),
                    _MenuItem(
                      icon: Icons.newspaper_rounded,
                      title: 'Новости',
                      onTap: () => _go(context, '/news'),
                    ),
                    const SizedBox(height: 8),
                    _MenuItem(
                      icon: Icons.rule_rounded,
                      title: 'Правила оказания услуг',
                      onTap: () => _go(context, '/rules'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? context.brandSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

