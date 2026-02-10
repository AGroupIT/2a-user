import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/payments_provider.dart';
import '../domain/payment_model.dart';

/// Экран оплаты
class PaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final int? invoiceId;
  final String? description;

  const PaymentScreen({
    super.key,
    required this.amount,
    this.invoiceId,
    this.description,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  CreatePaymentResult? _paymentResult;

  @override
  void initState() {
    super.initState();
    _createPayment();
  }

  Future<void> _createPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final result = await paymentService.createPayment(
        amount: widget.amount,
        invoiceId: widget.invoiceId,
        description: widget.description,
      );

      if (result != null) {
        setState(() {
          _paymentResult = result;
          _isLoading = false;
        });
        // Автоматически открываем страницу оплаты
        await _openPaymentPage();
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

  Future<void> _openPaymentPage() async {
    if (_paymentResult == null) return;

    final url = Uri.parse(_paymentResult!.paymentUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } else {
      setState(() {
        _errorMessage = 'Не удалось открыть страницу оплаты';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата'),
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

    if (_paymentResult != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.payment,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                'Сумма: ${widget.amount.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Заказ: ${_paymentResult!.orderId}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Нажмите кнопку ниже, чтобы перейти\nна страницу оплаты',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openPaymentPage,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Перейти к оплате'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'После оплаты вы будете автоматически возвращены в приложение',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Диалог подтверждения оплаты
Future<bool?> showPaymentConfirmationDialog(
  BuildContext context, {
  required double amount,
  String? description,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Подтверждение оплаты'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            Text(description),
            const SizedBox(height: 16),
          ],
          Text(
            'Сумма: ${amount.toStringAsFixed(2)} ₽',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Вы будете перенаправлены на страницу оплаты',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Оплатить'),
        ),
      ],
    ),
  );
}

/// Утилита для навигации к экрану оплаты
Future<void> navigateToPayment(
  BuildContext context, {
  required double amount,
  int? invoiceId,
  String? description,
  bool showConfirmation = true,
}) async {
  if (showConfirmation) {
    final confirmed = await showPaymentConfirmationDialog(
      context,
      amount: amount,
      description: description,
    );

    if (confirmed != true) return;
  }

  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: amount,
          invoiceId: invoiceId,
          description: description,
        ),
      ),
    );
  }
}
