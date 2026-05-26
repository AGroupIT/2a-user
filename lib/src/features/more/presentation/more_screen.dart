import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/sentry_config.dart';
import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_diagnostics.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../clients/application/client_codes_controller.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  final GlobalKey _newsRulesKey = GlobalKey();
  final GlobalKey _supportKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  bool _networkDiagnosticsRunning = false;

  Future<void> _runNetworkDiagnostics() async {
    if (_networkDiagnosticsRunning) return;
    setState(() => _networkDiagnosticsRunning = true);
    ClientLogService.instance.action('Запуск диагностики сети');

    try {
      final report = await NetworkDiagnosticsService(
        ref.read(apiClientProvider),
      ).collect(clientCode: ref.read(activeClientCodeProvider));
      final copied = await AppClipboard.copyText(report.toSupportText());
      if (!mounted) return;
      _showSnackBar(
        copied
            ? 'Диагностика сети скопирована. Отправьте её менеджеру.'
            : 'Диагностика сети собрана, но не скопирована автоматически.',
      );
    } catch (error, stackTrace) {
      await ClientLogService.instance.captureNonFatal(
        'Не удалось собрать диагностику сети',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showSnackBar('Не удалось собрать диагностику сети', isError: true);
    } finally {
      if (mounted) {
        setState(() => _networkDiagnosticsRunning = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : context.brandPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return TutorialScreenWrapper(
      screenKey: 'more',
      steps: [
        TutorialStep(
          icon: Icons.newspaper_rounded,
          title: 'Новости и правила',
          description:
              'Здесь собраны новости компании и правила оказания услуг. Читайте обновления и условия работы.',
          targetKey: _newsRulesKey,
        ),
        TutorialStep(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Чат поддержки',
          description:
              'Возникли вопросы? Напишите нам в чат поддержки — отвечаем быстро в рабочее время.',
          targetKey: _supportKey,
        ),
        TutorialStep(
          icon: Icons.person_outline_rounded,
          title: 'Профиль',
          description:
              'Здесь можно изменить личные данные, посмотреть контакты компании и настройки аккаунта.',
          targetKey: _profileKey,
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          topPad * 0.7 + 16,
          16,
          100 + bottomPad,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: 'Дополнительно'),
            const SizedBox(height: 24),
            _MenuSection(
              title: 'Информация',
              items: [
                _MenuItem(
                  icon: CupertinoIcons.news,
                  title: 'Новости',
                  subtitle: 'Последние обновления',
                  onTap: () => context.push('/news'),
                ),
                _MenuItem(
                  icon: CupertinoIcons.doc_text,
                  title: 'Правила оказания услуг',
                  subtitle: 'Условия и положения',
                  onTap: () => context.push('/rules'),
                ),
                _MenuItem(
                  icon: CupertinoIcons.cart,
                  title: 'Мои заявки на выкуп',
                  subtitle: 'История заявок',
                  onTap: () => context.push('/shop/purchases'),
                ),
                _MenuItem(
                  icon: Icons.description_rounded,
                  title: 'Выкуп по бланку',
                  subtitle: 'Бланки на выкуп товаров',
                  onTap: () => context.push('/purchase-blanks'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MenuSection(
              title: 'Поддержка',
              items: [
                _MenuItem(
                  icon: CupertinoIcons.chat_bubble_2,
                  title: 'Чат поддержки',
                  subtitle: 'Задайте вопрос',
                  onTap: () => context.go('/support'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MenuSection(
              title: 'Аккаунт',
              items: [
                _MenuItem(
                  icon: CupertinoIcons.person,
                  title: 'Профиль',
                  subtitle: 'Настройки аккаунта',
                  onTap: () => context.push('/profile'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MenuSection(
              title: 'Диагностика',
              items: [
                _MenuItem(
                  icon: CupertinoIcons.wifi,
                  title: 'Диагностика сети',
                  subtitle: _networkDiagnosticsRunning
                      ? 'Проверяем соединение...'
                      : 'Скопировать отчёт для поддержки',
                  onTap: _runNetworkDiagnostics,
                ),
                if (SentryConfig.verifyButtonEnabled)
                  _MenuItem(
                    icon: CupertinoIcons.exclamationmark_triangle,
                    title: 'Verify Sentry Setup',
                    subtitle: 'Отправить тестовую ошибку',
                    onTap: () {
                      throw StateError('Sentry verify test exception');
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  const Divider(height: 1, indent: 60, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.brandPrimary, context.brandSecondary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: Color(0xFFCCCCCC),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
