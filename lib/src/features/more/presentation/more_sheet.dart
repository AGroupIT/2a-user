import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/demo_mode_provider.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/sheet_handle.dart';

class MoreSheet extends ConsumerWidget {
  const MoreSheet({super.key});

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      'Меню',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // ── Аккаунт ───────────────────────────────────
                  _MenuItem(
                    icon: Icons.person_rounded,
                    title: 'Профиль',
                    onTap: () => _go(context, '/profile'),
                  ),
                  const SizedBox(height: 8),
                  _MenuItem(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Реферальная программа',
                    iconColor: const Color(0xFF4CAF50),
                    onTap: () => _go(context, '/referral'),
                  ),

                  // ── Полезные инструменты ──────────────────────
                  const _SectionLabel(text: 'Полезные инструменты'),
                  _MenuItem(
                    icon: Icons.shopping_bag_rounded,
                    title: 'Совместные покупки',
                    iconColor: const Color(0xFF9C27B0),
                    onTap: () => _go(context, '/sp-finance'),
                  ),
                  const SizedBox(height: 8),
                  _MenuItem(
                    icon: Icons.calculate_rounded,
                    title: 'Калькулятор доставки',
                    iconColor: const Color(0xFF2196F3),
                    onTap: () => _go(context, '/calculator'),
                  ),

                  // ── Поддержка ─────────────────────────────────
                  const _SectionLabel(text: 'Поддержка'),
                  _MenuItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Чат по оплате',
                    iconColor: const Color(0xFF4CAF50),
                    onTap: () => _go(context, '/payment-chat'),
                  ),
                  const SizedBox(height: 8),
                  _MenuItem(
                    icon: Icons.support_agent_rounded,
                    title: 'Чат с поддержкой',
                    onTap: () => _go(context, '/support'),
                  ),

                  // ── Полезные материалы ────────────────────────
                  const _SectionLabel(text: 'Полезные материалы'),
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
                  const SizedBox(height: 8),
                  _MenuItem(
                    icon: Icons.price_change_rounded,
                    title: 'Тарифы',
                    iconColor: const Color(0xFFFF9800),
                    onTap: () => _go(context, '/tariffs'),
                  ),

                  // ── Настройки ─────────────────────────────────
                  const _SectionLabel(text: 'Настройки'),
                  _MenuItem(
                    icon: Icons.school_rounded,
                    title: 'Пройти обучение',
                    iconColor: const Color(0xFF607D8B),
                    onTap: () async {
                      // Захватываем context-зависимые объекты ДО async-разрыва
                      final nav = Navigator.of(context);
                      final router = GoRouter.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final brandColor = context.brandPrimary;

                      final svc = ref.read(showcaseServiceProvider);
                      await svc.resetAllBlocks();
                      await svc.resetAllTutorials();
                      for (final block in ShowcaseBlock.values) {
                        ref.invalidate(showcaseBlockProvider(block));
                      }
                      ref.read(showcaseTutorialResetProvider.notifier).trigger();
                      ref.read(demoModeProvider.notifier).enable();

                      nav.pop();
                      router.go('/');
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Text('Обучение запущено заново'),
                          backgroundColor: brandColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
          letterSpacing: 0.3,
        ),
      ),
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
