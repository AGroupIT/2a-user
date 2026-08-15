import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import 'sp_finance_ui.dart';

typedef SpBarcodeScannerLauncher =
    Future<String?> Function(BuildContext context);

Future<String?> showSpBarcodeScannerSheet(BuildContext context) {
  return showSpFinanceModalSheet<String>(
    context: context,
    builder: (_) => const _SpBarcodeScannerSheet(),
  );
}

class _SpBarcodeScannerSheet extends StatefulWidget {
  const _SpBarcodeScannerSheet();

  @override
  State<_SpBarcodeScannerSheet> createState() => _SpBarcodeScannerSheetState();
}

class _SpBarcodeScannerSheetState extends State<_SpBarcodeScannerSheet> {
  static const _verificationWindow = Duration(milliseconds: 550);
  static const _minimumDetections = 2;

  late final MobileScannerController _controller;
  final Map<String, int> _detectionCounts = {};
  Timer? _verificationTimer;
  bool _accepted = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.itf14,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_accepted) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null || code.isEmpty) continue;

      final detections = (_detectionCounts[code] ?? 0) + 1;
      _detectionCounts[code] = detections;
      if (detections >= _minimumDetections) {
        _accept(code);
        return;
      }
    }

    if (_detectionCounts.isEmpty || _verificationTimer?.isActive == true) {
      return;
    }

    _verificationTimer = Timer(_verificationWindow, () {
      if (!mounted || _accepted || _detectionCounts.isEmpty) return;
      final bestMatch = _detectionCounts.entries.reduce(
        (current, candidate) =>
            candidate.value > current.value ? candidate : current,
      );
      _accept(bestMatch.key);
    });
  }

  void _accept(String code) {
    if (_accepted || !mounted) return;
    _accepted = true;
    _verificationTimer?.cancel();
    Navigator.of(context).pop(code);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (!mounted) return;
      setState(() => _torchEnabled = !_torchEnabled);
    } on MobileScannerException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              ru: 'Фонарик недоступен на этом устройстве',
              zh: '此设备不支持闪光灯',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: context.brandPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(context, ru: 'Сканировать штрихкод', zh: '扫描条形码'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('sp-barcode-torch-button'),
                    tooltip: tr(context, ru: 'Фонарик', zh: '闪光灯'),
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _torchEnabled
                          ? Icons.flash_off_rounded
                          : Icons.flash_on_rounded,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: tr(context, ru: 'Закрыть', zh: '关闭'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scanWindow = Rect.fromCenter(
                    center: Offset(
                      constraints.maxWidth / 2,
                      constraints.maxHeight / 2,
                    ),
                    width: constraints.maxWidth.clamp(0, 320).toDouble(),
                    height: 140,
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        scanWindow: scanWindow,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              tr(
                                context,
                                ru: 'Не удалось открыть камеру. Проверьте разрешение на доступ к камере.',
                                zh: '无法打开相机。请检查相机访问权限。',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: IgnorePointer(
                          child: Container(
                            width: scanWindow.width,
                            height: scanWindow.height,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: context.brandPrimary,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Text(
                tr(
                  context,
                  ru: 'Наведите камеру на штрихкод товара. Код подставится в поиск автоматически.',
                  zh: '将相机对准商品条形码，识别结果会自动用于搜索。',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontFamily: 'Gilroy',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
