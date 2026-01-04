import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../../clients/application/client_codes_controller.dart';

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
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                    const SizedBox(height: 16),
                    _LogoutButton(),
                    const SizedBox(height: 8),
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

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFFff5f02).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFff5f02), size: 22),
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

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // Очищаем сохранённые коды/активный код
          await ref.read(clientCodesControllerProvider.notifier).logout();
          // Выходим из аккаунта
          await ref.read(authProvider.notifier).logout();
          // Закрываем лист
          if (context.mounted) Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFfe3301).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFff5f02)),
          ),
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, color: Color(0xFFff5f02)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Выйти',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFFff5f02),
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
