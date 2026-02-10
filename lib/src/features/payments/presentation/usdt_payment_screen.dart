import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/payments_provider.dart';
import '../domain/payment_model.dart';
import 'payment_screen.dart';

/// Экран оплаты USDT TRC20
class UsdtPaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final int? invoiceId;
  final String? description;

  const UsdtPaymentScreen({
    super.key,
    required this.amount,
    this.invoiceId,
    this.description,
  });

  @override
  ConsumerState<UsdtPaymentScreen> createState() => _UsdtPaymentScreenState();
}

class _UsdtPaymentScreenState extends ConsumerState<UsdtPaymentScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  CreateUsdtPaymentResult? _paymentResult;
  UsdtPaymentCheckResult? _checkResult;
  Timer? _checkTimer;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _createPayment();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _createPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final result = await paymentService.createUsdtPayment(
        amount: widget.amount,
        invoiceId: widget.invoiceId,
        description: widget.description,
      );

      if (result != null) {
        setState(() {
          _paymentResult = result;
          _isLoading = false;
          _remainingSeconds = result.expiresAt.difference(DateTime.now()).inSeconds;
        });
        _startCountdown();
        _startChecking();
      } else {
        setState(() {
          _errorMessage = 'Не удалось создать платёж';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _handleExpired();
      }
    });
  }

  void _startChecking() {
    _checkTimer?.cancel();
    // Check every 10 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_paymentResult == null) return;

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final result = await paymentService.checkUsdtPayment(_paymentResult!.paymentId);

      if (result != null) {
        setState(() => _checkResult = result);

        if (result.isSuccess) {
          _checkTimer?.cancel();
          _countdownTimer?.cancel();
          _showSuccessDialog();
        } else if (result.isExpired || result.isFailed) {
          _checkTimer?.cancel();
          _countdownTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint('Error checking payment: $e');
    }
  }

  void _handleExpired() {
    _checkTimer?.cancel();
    setState(() {
      _checkResult = UsdtPaymentCheckResult(
        paymentId: _paymentResult?.paymentId ?? 0,
        status: 'expired',
        message: 'Время платежа истекло',
      );
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          size: 64,
          color: Colors.green,
        ),
        title: const Text('Оплата успешна!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Получено: ${_checkResult?.usdtAmount?.toStringAsFixed(4) ?? _paymentResult?.formattedUsdtAmount ?? ''} USDT',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_checkResult?.txHash != null) ...[
              const SizedBox(height: 8),
              Text(
                'TX: ${_checkResult!.txHash!.substring(0, 16)}...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Close screen with success
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Отлично!'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label скопирован'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата USDT'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Создание платежа...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createPayment,
                child: const Text('Попробовать снова'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      );
    }

    if (_checkResult?.isExpired == true || _checkResult?.isFailed == true) {
      return _buildExpiredState();
    }

    if (_paymentResult != null) {
      return _buildPaymentDetails();
    }

    return const SizedBox.shrink();
  }

  Widget _buildExpiredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.timer_off,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Время платежа истекло',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _checkResult?.message ?? 'Создайте новый платёж',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createPayment,
              child: const Text('Создать новый платёж'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetails() {
    final payment = _paymentResult!;
    final isConfirming = _checkResult?.isConfirming == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _remainingSeconds < 300
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: _remainingSeconds < 300 ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Осталось: ${_formatTime(_remainingSeconds)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds < 300 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: payment.walletAddress,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorStateBuilder: (context, error) {
                return const Center(
                  child: Text('Ошибка генерации QR'),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Status indicator
          if (isConfirming)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Транзакция найдена, подтверждение...',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Amount to send
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  'Отправьте ровно:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      payment.formattedUsdtAmount,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () => _copyToClipboard(
                        payment.usdtAmount.toStringAsFixed(4),
                        'Сумма',
                      ),
                      tooltip: 'Копировать сумму',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '≈ ${payment.rubAmount.toStringAsFixed(2)} ₽',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Wallet address
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wallet, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Адрес кошелька (TRC20)',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () => _copyToClipboard(payment.walletAddress, 'Адрес'),
                      tooltip: 'Копировать адрес',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  payment.walletAddress,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Exchange rate info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Курс: 1 USDT = ${payment.effectiveRate.toStringAsFixed(2)} ₽ (ЦБ + ${payment.markupPercent.toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Warning
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.warning_amber, color: Colors.amber, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Важно!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Отправляйте только USDT по сети TRC20\n'
                  '• Сумма должна быть точной: ${payment.formattedUsdtAmount}\n'
                  '• Платёж будет зачислен автоматически',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Check status button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checkPaymentStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Проверить статус'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Диалог выбора способа оплаты
Future<PaymentProvider?> showPaymentMethodDialog(
  BuildContext context, {
  required double amount,
}) {
  return showModalBottomSheet<PaymentProvider>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выберите способ оплаты',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Сумма: ${amount.toStringAsFixed(2)} ₽',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Card/SBP option
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card, color: Colors.blue),
            ),
            title: const Text('Карта / СБП'),
            subtitle: const Text('Банковская карта или Система быстрых платежей'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pop(PaymentProvider.pally),
          ),

          const Divider(),

          // USDT option
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.currency_bitcoin, color: Colors.green),
            ),
            title: const Text('USDT TRC20'),
            subtitle: const Text('Криптовалюта (курс ЦБ + 12%)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pop(PaymentProvider.usdtTrc20),
          ),

          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

/// Утилита для навигации к экрану оплаты с выбором метода
Future<void> navigateToPaymentWithChoice(
  BuildContext context, {
  required double amount,
  int? invoiceId,
  String? description,
}) async {
  final method = await showPaymentMethodDialog(context, amount: amount);

  if (method == null || !context.mounted) return;

  if (method == PaymentProvider.usdtTrc20) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UsdtPaymentScreen(
          amount: amount,
          invoiceId: invoiceId,
          description: description,
        ),
      ),
    );
  } else {
    // Import and use the regular payment screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PallyPaymentScreen(
          amount: amount,
          invoiceId: invoiceId,
          description: description,
        ),
      ),
    );
  }
}

/// Wrapper for Pally payment (using the existing PaymentScreen)
class _PallyPaymentScreen extends StatelessWidget {
  final double amount;
  final int? invoiceId;
  final String? description;

  const _PallyPaymentScreen({
    required this.amount,
    this.invoiceId,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to existing payment screen
    return PaymentScreen(
      amount: amount,
      invoiceId: invoiceId,
      description: description,
    );
  }
}

