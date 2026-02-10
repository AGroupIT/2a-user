import 'package:flutter/material.dart';

/// Тип результата оплаты
enum PaymentResultType {
  success,
  fail,
}

/// Обработчик результата оплаты (для deep links)
class PaymentResultHandler {
  /// Парсинг deep link URI
  static PaymentResultType? parseDeepLink(Uri uri) {
    // Ожидаемые URI:
    // twoalogistic://payment/success
    // twoalogistic://payment/fail

    if (uri.scheme != 'twoalogistic') return null;
    if (uri.host != 'payment') return null;

    final path = uri.path;
    if (path == '/success' || path == 'success') {
      return PaymentResultType.success;
    } else if (path == '/fail' || path == 'fail') {
      return PaymentResultType.fail;
    }

    return null;
  }

  /// Показать диалог результата оплаты
  static Future<void> showResultDialog(
    BuildContext context,
    PaymentResultType result,
  ) async {
    final isSuccess = result == PaymentResultType.success;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          size: 64,
          color: isSuccess ? Colors.green : Colors.red,
        ),
        title: Text(
          isSuccess ? 'Оплата успешна!' : 'Ошибка оплаты',
        ),
        content: Text(
          isSuccess
              ? 'Ваш платёж успешно обработан. Спасибо!'
              : 'К сожалению, платёж не прошёл. Попробуйте ещё раз или используйте другой способ оплаты.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Показать снэкбар с результатом
  static void showResultSnackBar(
    BuildContext context,
    PaymentResultType result,
  ) {
    final isSuccess = result == PaymentResultType.success;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSuccess
                    ? 'Платёж успешно обработан!'
                    : 'Ошибка оплаты. Попробуйте ещё раз.',
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// Виджет для отображения результата оплаты (полноэкранный)
class PaymentResultScreen extends StatelessWidget {
  final PaymentResultType result;
  final VoidCallback? onClose;

  const PaymentResultScreen({
    super.key,
    required this.result,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = result == PaymentResultType.success;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: (isSuccess ? Colors.green : Colors.red)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    size: 64,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isSuccess ? 'Оплата успешна!' : 'Ошибка оплаты',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  isSuccess
                      ? 'Ваш платёж успешно обработан.\nБлагодарим за оплату!'
                      : 'К сожалению, платёж не прошёл.\nПопробуйте ещё раз или используйте\nдругой способ оплаты.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isSuccess ? Colors.green : Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isSuccess ? 'Отлично!' : 'Понятно'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
