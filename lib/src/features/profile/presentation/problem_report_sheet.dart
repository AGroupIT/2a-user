import 'package:flutter/material.dart';

import '../../../core/logging/client_log_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../../core/utils/error_utils.dart';
import '../data/problem_report_repository.dart';
import '../data/profile_provider.dart';

Future<void> showProblemReportSheet({
  required BuildContext context,
  required ClientProfile profile,
  required ProblemReportRepository repository,
  String? currentScreen,
}) {
  ClientLogService.instance.action('Открыт экран сообщения о проблеме');

  return showBlurredModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProblemReportSheet(
      hostContext: context,
      profile: profile,
      repository: repository,
      currentScreen: currentScreen,
    ),
  );
}

void _showProblemReportSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  AppToast.showFromSnackBar(
    context,
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: AppToast.hide,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFE53935) : context.brandPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
      duration: const Duration(seconds: 3),
    ),
  );
}

class _ProblemReportSheet extends StatefulWidget {
  final BuildContext hostContext;
  final ClientProfile profile;
  final ProblemReportRepository repository;
  final String? currentScreen;

  const _ProblemReportSheet({
    required this.hostContext,
    required this.profile,
    required this.repository,
    this.currentScreen,
  });

  @override
  State<_ProblemReportSheet> createState() => _ProblemReportSheetState();
}

class _ProblemReportSheetState extends State<_ProblemReportSheet> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _controller.text.trim();
    if (description.length < 5) {
      _showProblemReportSnackBar(
        widget.hostContext,
        'Опишите проблему подробнее',
        isError: true,
      );
      return;
    }

    setState(() => _isSending = true);
    ClientLogService.instance.action('Отправка отчёта о проблеме');

    try {
      final result = await widget.repository.send(
        description: description,
        profile: widget.profile,
        currentScreen: widget.currentScreen,
      );
      if (!mounted) return;

      Navigator.of(context).pop();
      if (!widget.hostContext.mounted) return;
      _showProblemReportSnackBar(
        widget.hostContext,
        result.queued
            ? 'Связь нестабильна. Отчёт сохранён и отправится автоматически.'
            : result.id == null
            ? 'Отчёт отправлен'
            : 'Отчёт #${result.id} отправлен',
      );
    } catch (error, stackTrace) {
      final cause = error is ProblemReportSendException ? error.cause : error;
      final diagnosticsText = error is ProblemReportSendException
          ? error.diagnostics?.toSupportText()
          : null;
      await ClientLogService.instance.captureNonFatal(
        'Не удалось отправить отчёт о проблеме',
        error: cause,
        stackTrace: stackTrace,
        data: {if (diagnosticsText != null) 'hasNetworkDiagnostics': true},
      );
      if (!mounted) return;

      var copiedDiagnostics = false;
      if (diagnosticsText != null && diagnosticsText.isNotEmpty) {
        copiedDiagnostics = await AppClipboard.copyText(diagnosticsText);
      }
      if (!mounted || !widget.hostContext.mounted) return;

      final errorInfo = ErrorUtils.getErrorInfo(cause);
      _showProblemReportSnackBar(
        widget.hostContext,
        copiedDiagnostics
            ? '${errorInfo.message} Диагностика скопирована, отправьте её менеджеру.'
            : errorInfo.message,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.86),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 25,
                offset: Offset(3, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Сообщить о проблеме',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontSize: 22,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Опишите, что не работает. Мы приложим последние действия и ошибки API без паролей, токенов и чувствительных данных.',
                        style: TextStyle(
                          color: Color(0x992F2F2F),
                          fontFamily: 'Gilroy',
                          fontSize: 14,
                          height: 18 / 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _controller,
                        minLines: 4,
                        maxLines: 7,
                        enabled: !_isSending,
                        textInputAction: TextInputAction.newline,
                        decoration: appInputDecoration(
                          context,
                          hintText: 'Например: не открываются фотоотчёты',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSending
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Отмена'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSending ? null : _submit,
                              child: _isSending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Отправить'),
                            ),
                          ),
                        ],
                      ),
                    ],
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
