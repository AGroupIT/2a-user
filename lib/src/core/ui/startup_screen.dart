import 'package:flutter/material.dart';

/// Visible startup/error state while essential local storage is unavailable.
/// Never substitutes empty preferences for a failed session-store load.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: onRetry == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Не удалось запустить приложение / 启动失败'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Повторить / 重试'),
                  ),
                ],
              ),
      ),
    ),
  );
}
