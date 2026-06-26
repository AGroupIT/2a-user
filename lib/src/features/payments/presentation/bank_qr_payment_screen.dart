import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/ui/app_toast.dart';
import '../../../core/utils/locale_text.dart';
import '../data/bank_qr_payment.dart';

/// Bank QR Sprint 4 — экран оплаты счёта в рублях по банковскому QR.
/// Открывается из карточки счёта (кнопка «Оплатить в рублях»). На init стартует
/// QR-платёж (идемпотентно), показывает QR + реквизиты, принимает чек и по
/// «Я оплатил» загружает его → счёт переходит в «На проверке».
class BankQrPaymentScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  final String invoiceNumber;

  const BankQrPaymentScreen({
    super.key,
    required this.invoiceId,
    required this.invoiceNumber,
  });

  @override
  ConsumerState<BankQrPaymentScreen> createState() => _BankQrPaymentScreenState();
}

const _allowedExt = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'pdf'];

String _mimeForExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

class _BankQrPaymentScreenState extends ConsumerState<BankQrPaymentScreen> {
  bool _loading = true;
  String? _error;
  BankQrPaymentResult? _result;

  Uint8List? _fileBytes;
  String? _fileName;
  String? _fileMime;

  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(bankQrPaymentServiceProvider).startBankQrPayment(widget.invoiceId);
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _loading = false;
          _error = tr(context, ru: 'Не удалось начать оплату', zh: '无法开始支付');
        });
        return;
      }
      setState(() {
        _result = res;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final reason = (e.response?.data is Map) ? (e.response?.data['reason']?.toString()) : null;
      setState(() {
        _loading = false;
        _error = reason != null
            ? tr(context, ru: 'QR-оплата недоступна', zh: 'QR 支付不可用')
            : tr(context, ru: 'Ошибка сети. Повторите.', zh: '网络错误，请重试');
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExt,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes ?? await f.xFile.readAsBytes();
      final ext = (f.extension ?? f.name.split('.').last).toLowerCase();
      if (!_allowedExt.contains(ext)) {
        if (mounted) {
          AppToast.show(context, tr(context, ru: 'Неподдерживаемый формат файла', zh: '不支持的文件格式'), isError: true);
        }
        return;
      }
      setState(() {
        _fileBytes = bytes;
        _fileName = f.name;
        _fileMime = _mimeForExt(ext);
      });
    } catch (_) {
      if (mounted) {
        AppToast.show(context, tr(context, ru: 'Не удалось выбрать файл', zh: '无法选择文件'), isError: true);
      }
    }
  }

  Future<void> _confirmPaid() async {
    final res = _result;
    final bytes = _fileBytes;
    if (res == null || bytes == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final upload = await ref.read(bankQrPaymentServiceProvider).uploadBankQrReceipt(
            paymentId: res.paymentId,
            bytes: bytes,
            fileName: _fileName ?? 'receipt',
            mimeType: _fileMime ?? 'application/octet-stream',
          );
      if (!mounted) return;
      setState(() => _uploading = false);
      if (upload == null) {
        AppToast.show(context, tr(context, ru: 'Не удалось отправить чек', zh: '无法发送凭证'), isError: true);
        return;
      }
      AppToast.show(context, tr(context, ru: 'Чек отправлен на проверку', zh: '凭证已提交审核'));
      Navigator.of(context).pop(true); // сигнал обновить список
    } on DioException {
      if (!mounted) return;
      setState(() => _uploading = false);
      AppToast.show(context, tr(context, ru: 'Ошибка отправки чека', zh: '发送凭证出错'), isError: true);
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(context, label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, ru: 'Оплата в рублях', zh: '人民币支付'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _start, child: Text(tr(context, ru: 'Повторить', zh: '重试'))),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final res = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${res.amountRub.toStringAsFixed(2)} ₽',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            tr(context, ru: 'Счёт ${widget.invoiceNumber}', zh: '账单 ${widget.invoiceNumber}'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
              ),
              child: QrImageView(
                data: res.qrPayload,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                errorStateBuilder: (context, error) => SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(child: Text(tr(context, ru: 'Ошибка QR', zh: 'QR 错误'))),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(context,
                ru: 'Отсканируйте QR в приложении банка',
                zh: '在银行应用中扫描二维码'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _infoRow(tr(context, ru: 'Назначение', zh: '用途'), res.purpose,
              onCopy: () => _copy(res.purpose, tr(context, ru: 'Назначение скопировано', zh: '已复制用途'))),
          _infoRow(tr(context, ru: 'Сумма', zh: '金额'), '${res.amountRub.toStringAsFixed(2)} ₽',
              onCopy: () => _copy(res.amountRub.toStringAsFixed(2), tr(context, ru: 'Сумма скопирована', zh: '已复制金额'))),
          const Divider(height: 32),
          Text(
            tr(context, ru: '1. Оплатите по QR. 2. Приложите чек. 3. Нажмите «Я оплатил».',
                zh: '1. 通过二维码付款。2. 附上凭证。3. 点击「我已付款」。'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(_fileBytes == null
                ? tr(context, ru: 'Приложить чек (фото/PDF)', zh: '附上凭证（图片/PDF）')
                : tr(context, ru: 'Заменить чек', zh: '更换凭证')),
          ),
          if (_fileBytes != null) ...[
            const SizedBox(height: 8),
            _receiptPreview(),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_fileBytes != null && !_uploading) ? _confirmPaid : null,
            icon: _uploading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: Text(tr(context, ru: 'Я оплатил', zh: '我已付款')),
          ),
          const SizedBox(height: 8),
          Text(
            tr(context,
                ru: 'После отправки счёт перейдёт на проверку. Оплату подтвердит сотрудник.',
                zh: '提交后账单将进入审核，由工作人员确认付款。'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _receiptPreview() {
    final bytes = _fileBytes!;
    final isPdf = (_fileMime == 'application/pdf');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (isPdf)
            const Icon(Icons.picture_as_pdf, size: 40, color: Colors.redAccent)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
            ),
          const SizedBox(width: 12),
          Expanded(child: Text(_fileName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(
            onPressed: _uploading
                ? null
                : () => setState(() {
                      _fileBytes = null;
                      _fileName = null;
                      _fileMime = null;
                    }),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.copy, size: 16)),
            ),
        ],
      ),
    );
  }
}
