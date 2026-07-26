import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../payments/data/payment_operator_status.dart';
import '../../payments/presentation/payment_operator_sleeping_notice.dart';
import '../../payments/presentation/payment_receipt_picker.dart';
import '../application/garage_providers.dart';
import '../domain/garage_models.dart';
import 'garage_ui.dart';

Future<bool?> showGaragePaymentSheet({
  required BuildContext context,
  required int orderId,
  required String orderNumber,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        GaragePaymentSheet(orderId: orderId, orderNumber: orderNumber),
  );
}

class GaragePaymentSheet extends ConsumerStatefulWidget {
  final int orderId;
  final String orderNumber;

  const GaragePaymentSheet({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  @override
  ConsumerState<GaragePaymentSheet> createState() => _GaragePaymentSheetState();
}

class _GaragePaymentSheetState extends ConsumerState<GaragePaymentSheet> {
  GarageBankQrPayment? _payment;
  Uint8List? _receiptBytes;
  String? _receiptName;
  String? _receiptMime;
  String? _error;
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_start);
  }

  Future<void> _start() async {
    final current = ref.read(paymentOperatorStatusProvider).asData?.value;
    final operatorStatus =
        current ??
        await ref.read(paymentOperatorStatusProvider.future) ??
        PaymentOperatorStatus.workingFallback;
    if (!mounted) return;
    if (operatorStatus.sleeping) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payment = await ref
          .read(garageRepositoryProvider)
          .startBankQrPayment(
            widget.orderId,
            idempotencyKey: const Uuid().v4(),
          );
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось подготовить QR для оплаты';
      });
    }
  }

  Future<void> _pickReceipt() async {
    final receipt = await pickPaymentReceipt(context);
    if (!mounted || receipt == null) return;
    setState(() {
      _receiptBytes = receipt.bytes;
      _receiptName = receipt.fileName;
      _receiptMime = receipt.mimeType;
    });
  }

  Future<void> _upload() async {
    final payment = _payment;
    final bytes = _receiptBytes;
    if (payment == null || bytes == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      await ref
          .read(garageRepositoryProvider)
          .uploadPaymentReceipt(
            paymentId: payment.paymentId,
            bytes: bytes,
            fileName: _receiptName ?? 'receipt',
            mimeType: _receiptMime ?? 'application/octet-stream',
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      AppToast.show(context, 'Не удалось отправить чек', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final operatorsSleeping = paymentOperatorStatusOrWorking(
      ref.watch(paymentOperatorStatusProvider),
    ).sleeping;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  color: context.brandPrimary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Оплата автозапчастей',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Заказ ${widget.orderNumber}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 18),
              child: operatorsSleeping
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PaymentOperatorSleepingNotice(),
                        const SizedBox(height: 12),
                        GarageSecondaryButton(
                          label: 'Закрыть',
                          icon: Icons.close_rounded,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    )
                  : _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 70),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                  ? GarageEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Оплата недоступна',
                      subtitle: _error!,
                      action: GarageSecondaryButton(
                        label: 'Повторить',
                        icon: Icons.refresh_rounded,
                        onPressed: _start,
                      ),
                    )
                  : _content(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final payment = _payment!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GarageCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: payment.qrPayload,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (_, _) => const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(child: Text('QR-код недоступен')),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                garageMoney(payment.amountRub, '₽'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                payment.purpose,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GarageCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Чек об оплате',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Оплатите по QR, приложите фото или PDF чека. Платёж перейдёт на проверку.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GarageSecondaryButton(
                label: _receiptBytes == null ? 'Приложить чек' : 'Заменить чек',
                icon: Icons.attach_file_rounded,
                onPressed: _uploading ? null : _pickReceipt,
              ),
              if (_receiptBytes != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _receiptMime == 'application/pdf'
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: context.brandPrimary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _receiptName ?? 'Чек',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              GaragePrimaryButton(
                label: 'Я оплатил — отправить чек',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _receiptBytes == null ? null : _upload,
                loading: _uploading,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
