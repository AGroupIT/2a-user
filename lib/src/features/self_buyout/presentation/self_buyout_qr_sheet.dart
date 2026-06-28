import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/utils/locale_text.dart';
import '../data/self_buyout_models.dart';
import '../data/self_buyout_service.dart';
import 'self_buyout_ui.dart';

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

/// Модалка оплаты заявки самовыкупа в рублях: стартует QR, принимает чек.
class SelfBuyoutQrSheet extends ConsumerStatefulWidget {
  final int requestId;
  final String requestNumber;
  final double cnyAmount;

  const SelfBuyoutQrSheet({
    super.key,
    required this.requestId,
    required this.requestNumber,
    required this.cnyAmount,
  });

  @override
  ConsumerState<SelfBuyoutQrSheet> createState() => _SelfBuyoutQrSheetState();
}

class _SelfBuyoutQrSheetState extends ConsumerState<SelfBuyoutQrSheet> {
  bool _loading = true;
  String? _error;
  SelfBuyoutPaymentInfo? _result;

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
      final res =
          await ref.read(selfBuyoutServiceProvider).startBankQr(widget.requestId);
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
    } on DioException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr(context, ru: 'Оплата недоступна. Повторите.', zh: '支付不可用，请重试');
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
          AppToast.show(
            context,
            tr(context, ru: 'Неподдерживаемый формат файла', zh: '不支持的文件格式'),
            isError: true,
          );
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
        AppToast.show(
          context,
          tr(context, ru: 'Не удалось выбрать файл', zh: '无法选择文件'),
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmPaid() async {
    final res = _result;
    final bytes = _fileBytes;
    if (res == null || bytes == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final ok = await ref.read(selfBuyoutServiceProvider).uploadReceipt(
            paymentId: res.paymentId,
            bytes: bytes,
            fileName: _fileName ?? 'receipt',
            mimeType: _fileMime ?? 'application/octet-stream',
          );
      if (!mounted) return;
      setState(() => _uploading = false);
      if (!ok) {
        AppToast.show(
          context,
          tr(context, ru: 'Не удалось отправить чек', zh: '无法发送凭证'),
          isError: true,
        );
        return;
      }
      AppToast.show(
        context,
        tr(context, ru: 'Чек отправлен на проверку', zh: '凭证已提交审核'),
      );
      Navigator.of(context).pop(true);
    } on DioException {
      if (!mounted) return;
      setState(() => _uploading = false);
      AppToast.show(
        context,
        tr(context, ru: 'Ошибка отправки чека', zh: '发送凭证出错'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SelfBuyoutGradientHeader(
                icon: Icons.qr_code_2_rounded,
                title: tr(context, ru: 'Оплата в рублях', zh: '卢布支付'),
                subtitle: tr(
                  context,
                  ru: 'Заявка ${widget.requestNumber}',
                  zh: '申请 ${widget.requestNumber}',
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _loading
                    ? _SelfBuyoutCard(
                        icon: Icons.hourglass_empty_rounded,
                        title: tr(context, ru: 'Готовим QR', zh: '正在生成二维码'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 22),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    : _error != null
                        ? _buildError()
                        : _buildContent(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomPadding),
              child: _buildFooter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return _SelfBuyoutCard(
      icon: Icons.error_outline_rounded,
      title: tr(context, ru: 'Оплата недоступна', zh: '支付不可用'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SelfBuyoutPrimaryButton(
            label: tr(context, ru: 'Повторить', zh: '重试'),
            icon: Icons.refresh_rounded,
            onTap: _start,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final res = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelfBuyoutCard(
          icon: Icons.qr_code_2_rounded,
          title: tr(context, ru: 'QR для оплаты', zh: '付款二维码'),
          child: Column(
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.04)),
                  ),
                  child: QrImageView(
                    data: res.qrPayload,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    errorStateBuilder: (context, error) => SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Text(tr(context, ru: 'Ошибка QR', zh: 'QR 错误')),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${res.amountRub.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                res.purpose,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SelfBuyoutCard(
          icon: Icons.upload_file_rounded,
          title: tr(context, ru: 'Чек об оплате', zh: '付款凭证'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  context,
                  ru: 'Оплатите по QR, приложите чек и нажмите «Я оплатил». Заявка уйдёт сотруднику на проверку.',
                  zh: '扫码付款后上传凭证并点击「我已付款」，申请将提交审核。',
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 1.28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SelfBuyoutSecondaryButton(
                label: _fileBytes == null
                    ? tr(context, ru: 'Приложить чек (фото/PDF)', zh: '附上凭证（图片/PDF）')
                    : tr(context, ru: 'Заменить чек', zh: '更换凭证'),
                icon: Icons.attach_file_rounded,
                onTap: _uploading ? null : _pickFile,
              ),
              if (_fileBytes != null) ...[
                const SizedBox(height: 10),
                _receiptPreview(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return SelfBuyoutPrimaryButton(
        label: tr(context, ru: 'Подготовка QR…', zh: '正在生成二维码…'),
        icon: Icons.hourglass_empty_rounded,
        onTap: null,
      );
    }
    if (_error != null) {
      return SelfBuyoutSecondaryButton(
        label: tr(context, ru: 'Закрыть', zh: '关闭'),
        icon: Icons.close_rounded,
        onTap: () => Navigator.of(context).pop(false),
      );
    }
    return SelfBuyoutPrimaryButton(
      label: tr(context, ru: 'Я оплатил', zh: '我已付款'),
      icon: Icons.check_circle_outline_rounded,
      isLoading: _uploading,
      onTap: (_fileBytes != null && !_uploading) ? _confirmPaid : null,
    );
  }

  Widget _receiptPreview() {
    final bytes = _fileBytes!;
    final isPdf = _fileMime == 'application/pdf';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPdf
                  ? Colors.redAccent.withValues(alpha: 0.10)
                  : context.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: isPdf
                ? const Icon(Icons.picture_as_pdf_rounded,
                    size: 28, color: Colors.redAccent)
                : Image.memory(bytes, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _fileName ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _uploading
                ? null
                : () => setState(() {
                      _fileBytes = null;
                      _fileName = null;
                      _fileMime = null;
                    }),
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _SelfBuyoutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SelfBuyoutCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.brandPrimary, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 14.5,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
