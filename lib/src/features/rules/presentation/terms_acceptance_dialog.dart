import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_colors.dart';

/// Диалог принятия правил оказания услуг при первом входе
/// Блокирует доступ к приложению до принятия правил
class TermsAcceptanceDialog extends ConsumerWidget {
  const TermsAcceptanceDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false, // Запрещаем закрытие диалога свайпом или кнопкой "назад"
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок с иконкой
                Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.brandPrimary,
                      context.brandSecondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Добро пожаловать!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Контент (скроллируемый)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Прежде чем продолжить',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Для использования приложения необходимо ознакомиться и принять правила оказания услуг компании 2A Logistic.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Блок с основными пунктами
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoItem(
                            icon: Icons.check_circle_outline_rounded,
                            text: 'Условия оказания услуг',
                            color: context.brandPrimary,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            icon: Icons.verified_user_outlined,
                            text: 'Права и обязанности клиентов',
                            color: context.brandPrimary,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            icon: Icons.inventory_2_outlined,
                            text: 'Правила упаковки и маркировки',
                            color: context.brandPrimary,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            icon: Icons.policy_outlined,
                            text: 'Порядок работы и процедуры',
                            color: context.brandPrimary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Кнопка "Ознакомиться с правилами"
                    OutlinedButton.icon(
                      onPressed: () {
                        // Закрываем диалог и переходим к правилам
                        Navigator.of(context).pop();
                        context.go('/rules');
                      },
                      icon: const Icon(Icons.article_outlined, size: 20),
                      label: const Text('Ознакомиться с правилами'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.brandPrimary,
                        side: BorderSide(color: context.brandPrimary, width: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Кнопка "Соглашаюсь"
                    FilledButton.icon(
                      onPressed: () async {
                        // Отмечаем что пользователь принял правила
                        final service = ref.read(showcaseServiceProvider);
                        await service.acceptTerms();

                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.done_rounded, size: 22),
                      label: const Text(
                        'Соглашаюсь',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Мелкий текст
                    Text(
                      'Нажимая кнопку "Соглашаюсь", вы подтверждаете, что ознакомились с правилами оказания услуг и обязуетесь их соблюдать.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}

/// Функция для показа диалога принятия правил
Future<void> showTermsAcceptanceDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false, // Нельзя закрыть кликом вне диалога
    builder: (context) => const TermsAcceptanceDialog(),
  );
}
