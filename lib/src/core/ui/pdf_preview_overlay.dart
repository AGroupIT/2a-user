import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../utils/locale_text.dart';
import 'blurred_media_backdrop.dart';

void showPdfPreviewOverlay({
  required BuildContext context,
  required String url,
  required String fileName,
  required VoidCallback onDownload,
}) {
  if (kIsWeb) {
    onDownload();
    return;
  }

  late OverlayEntry pdfOverlay;
  pdfOverlay = OverlayEntry(
    builder: (context) => _PdfPreviewOverlay(
      url: url,
      fileName: fileName,
      onDownload: onDownload,
      onClose: pdfOverlay.remove,
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(pdfOverlay);
}

class _PdfPreviewOverlay extends StatefulWidget {
  final String url;
  final String fileName;
  final VoidCallback onDownload;
  final VoidCallback onClose;

  const _PdfPreviewOverlay({
    required this.url,
    required this.fileName,
    required this.onDownload,
    required this.onClose,
  });

  @override
  State<_PdfPreviewOverlay> createState() => _PdfPreviewOverlayState();
}

class _PdfPreviewOverlayState extends State<_PdfPreviewOverlay> {
  late Future<Uint8List> _pdfBytesFuture;
  bool _pdfRendered = false;
  Object? _pdfRenderError;

  @override
  void initState() {
    super.initState();
    _pdfBytesFuture = _loadPdfBytes();
  }

  Future<Uint8List> _loadPdfBytes() async {
    debugPrint('[PdfPreview] Loading PDF bytes: ${widget.url}');

    final response =
        await Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 25),
          ),
        ).get<List<int>>(
          widget.url,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            receiveDataWhenStatusError: true,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300,
            headers: const {
              'Accept': 'application/pdf,application/octet-stream,*/*',
            },
          ),
        );

    if (!mounted) {
      throw StateError('PDF preview closed before load completed');
    }

    final rawBytes = response.data;
    if (rawBytes == null || rawBytes.isEmpty) {
      throw StateError('PDF response is empty');
    }

    final bytes = rawBytes is Uint8List
        ? rawBytes
        : Uint8List.fromList(rawBytes);
    final sniffLength = bytes.length < 1024 ? bytes.length : 1024;
    final firstChunk = String.fromCharCodes(bytes.take(sniffLength));

    if (!firstChunk.contains('%PDF-')) {
      final headLength = bytes.length < 16 ? bytes.length : 16;
      final firstBytes = bytes
          .take(headLength)
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      debugPrint(
        '[PdfPreview] Non-PDF response: status=${response.statusCode}, '
        'contentType=${response.headers.value(Headers.contentTypeHeader)}, '
        'bytes=${bytes.length}, head=$firstBytes',
      );
      throw const FormatException('Response is not a PDF document');
    }

    debugPrint('[PdfPreview] Loaded PDF bytes: ${bytes.length}');
    return bytes;
  }

  void _retryLoad() {
    setState(() {
      _pdfRendered = false;
      _pdfRenderError = null;
      _pdfBytesFuture = _loadPdfBytes();
    });
  }

  Widget _buildLoadingBanner(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: Center(
        child: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(height: 14),
              Text(
                tr(context, ru: 'Открываем PDF...', zh: '正在打开 PDF...'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2F2F2F),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenError(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7E7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFE53935),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr(context, ru: 'Не удалось открыть PDF', zh: '无法打开 PDF'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    context,
                    ru: 'Файл можно скачать и открыть системным просмотрщиком.',
                    zh: '可以下载文件并用系统查看器打开。',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.onDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(tr(context, ru: 'Скачать', zh: '下载')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialLoadError(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7E7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFE53935),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr(context, ru: 'Не удалось загрузить PDF', zh: '无法加载 PDF'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    context,
                    ru: 'Попробуйте ещё раз или скачайте файл.',
                    zh: '请重试或下载文件。',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _retryLoad,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tr(context, ru: 'Повторить', zh: '重试')),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onDownload,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(tr(context, ru: 'Скачать', zh: '下载')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfDocument(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _pdfBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingBanner(context);
        }

        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          debugPrint('[PdfPreview] PDF load failed: ${snapshot.error}');
          return _buildInitialLoadError(context);
        }

        return Stack(
          children: [
            Positioned.fill(
              child: PDFView(
                pdfData: bytes,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: true,
                pageFling: true,
                pageSnap: false,
                fitPolicy: FitPolicy.WIDTH,
                preventLinkNavigation: true,
                backgroundColor: Colors.white,
                onRender: (pages) {
                  debugPrint('[PdfPreview] Native PDF rendered pages=$pages');
                  if (!mounted) return;
                  setState(() {
                    _pdfRendered = true;
                    _pdfRenderError = null;
                  });
                },
                onError: (error) {
                  debugPrint('[PdfPreview] Native PDF render failed: $error');
                  if (!mounted) return;
                  setState(() {
                    _pdfRenderError = error;
                  });
                },
                onPageError: (page, error) {
                  debugPrint(
                    '[PdfPreview] Native PDF page render failed: '
                    'page=$page, error=$error',
                  );
                },
              ),
            ),
            if (!_pdfRendered && _pdfRenderError == null)
              Positioned.fill(child: _buildLoadingBanner(context)),
            if (_pdfRenderError != null)
              Positioned.fill(child: _buildOpenError(context)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
      ),
      child: Material(
        color: Colors.transparent,
        child: BlurredMediaBackdrop(
          child: Stack(
            children: [
              Positioned.fill(
                top: topInset + 72,
                bottom: bottomInset + 12,
                left: 10,
                right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColoredBox(
                    color: Colors.white,
                    child: _buildPdfDocument(context),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: topInset + 8,
                    left: 8,
                    right: 8,
                    bottom: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.58),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: widget.onDownload,
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                        ),
                        tooltip: tr(context, ru: 'Скачать', zh: '下载'),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                        ),
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
