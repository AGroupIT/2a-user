import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import '../../../core/ui/app_background.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/chat_presence_service.dart';
import '../../../core/network/api_config.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../invoices/data/invoices_provider.dart';
import '../../invoices/domain/invoice_item.dart';
import '../../tracks/data/tracks_provider.dart';
import '../../tracks/domain/track_item.dart';
import '../../support/data/chat_models.dart';
import '../data/payment_chat_provider.dart';

class PaymentChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  final String? invoiceId;
  final String? invoiceNumber;
  final double? amount;
  
  const PaymentChatScreen({
    super.key,
    this.initialMessage,
    this.invoiceId,
    this.invoiceNumber,
    this.amount,
  });

  @override
  ConsumerState<PaymentChatScreen> createState() => _PaymentChatScreenState();
}

class _PaymentChatScreenState extends ConsumerState<PaymentChatScreen>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;

  final bool _showQuickActions = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  bool _isInfoBannerExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    
    // Загружаем чат и запускаем polling
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(isPaymentChatScreenOpenProvider.notifier).set(true);
      await ref.read(paymentChatControllerProvider.notifier).loadConversation();
      
      // Если есть начальное сообщение об оплате счёта - отправляем его сразу
      if (widget.invoiceId != null && widget.initialMessage != null) {
        await _sendInitialInvoiceMessage();
      } else if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        // Просто устанавливаем текст в поле (старое поведение)
        _textController.text = widget.initialMessage!;
      }
      
      // Запускаем polling для новых сообщений
      _startPolling();
      
      // Уведомляем сервер что чат открыт (для блокировки push-уведомлений)
      _notifyServerChatOpened();
    });

    // Очищаем уведомления при открытии чата
    _clearNotifications();
  }

  /// Уведомить сервер что чат открыт
  Future<void> _notifyServerChatOpened() async {
    final chatState = ref.read(paymentChatControllerProvider);
    final conversationId = chatState.conversation?.id;
    await ref.read(chatPresenceServiceProvider).openChat(
      ChatType.payment,
      conversationId: conversationId,
    );
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isAppInBackground) {
        _pollMessages();
      }
    });
  }
  
  void _pollMessages() {
    ref.read(paymentChatControllerProvider.notifier).pollNewMessages();
  }

  Future<void> _initNotifications() async {
    final notificationService = ref.read(pushNotificationServiceProvider);
    await notificationService.initialize();
  }

  Future<void> _clearNotifications() async {
    final notificationService = ref.read(pushNotificationServiceProvider);
    await notificationService.cancelAllNotifications();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    ref.read(isPaymentChatScreenOpenProvider.notifier).set(false);
    
    // Уведомляем сервер что чат закрыт
    ref.read(chatPresenceServiceProvider).closeChat(ChatType.payment);
    
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    debugPrint('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      _clearNotifications();
      // Обновляем сообщения при возврате в приложение
      ref.read(paymentChatControllerProvider.notifier).pollNewMessages();
      // Уведомляем сервер что чат снова открыт
      _notifyServerChatOpened();
    } else if (state == AppLifecycleState.paused) {
      // Уведомляем сервер что приложение ушло в фон
      ref.read(chatPresenceServiceProvider).onAppPaused();
    }
  }

  bool get _isAppInBackground =>
      _appLifecycleState == AppLifecycleState.paused ||
      _appLifecycleState == AppLifecycleState.inactive ||
      _appLifecycleState == AppLifecycleState.hidden;

  // Флаг чтобы отправить начальное сообщение только один раз
  bool _initialMessageSent = false;

  Future<void> _handleMessageSend(String text, {Map<String, dynamic>? metadata}) async {
    final chatState = ref.read(paymentChatControllerProvider);
    final pendingAttachments = chatState.pendingAttachments;
    
    // Если нет текста и нет вложений - ничего не делаем
    if (text.trim().isEmpty && pendingAttachments.isEmpty) return;

    HapticFeedback.lightImpact();
    _textController.clear();
    
    // Собираем ID вложений
    final attachmentIds = pendingAttachments.map((a) => a['id'] as int).toList();
    
    final success = await ref.read(paymentChatControllerProvider.notifier).sendMessage(
      text.isEmpty ? 'Файл' : text, 
      metadata: metadata,
      attachmentIds: attachmentIds,
    );
    
    if (success) {
      // Очищаем pending attachments
      ref.read(paymentChatControllerProvider.notifier).clearPendingAttachments();
      // Прокрутка вниз после отправки
      _scrollToBottom();
    }
  }
  
  /// Показать диалог выбора типа вложения
  void _showAttachmentPicker() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Прикрепить файл',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Камера', style: TextStyle(color: Colors.white)),
              subtitle: Text('Сделать фото', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: Colors.green),
              ),
              title: const Text('Галерея', style: TextStyle(color: Colors.white)),
              subtitle: Text('Выбрать изображение', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.orange),
              ),
              title: const Text('PDF документ', style: TextStyle(color: Colors.white)),
              subtitle: Text('Выбрать файл', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              onTap: () {
                Navigator.pop(context);
                _pickPdfFile();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  /// Выбрать изображение с камеры
  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false, // Конвертирует HEIC в JPEG на iOS
      );
      if (image != null) {
        // Читаем bytes напрямую из XFile для избежания проблем с iOS sandbox
        final bytes = await image.readAsBytes();
        final fileName = image.name.isNotEmpty ? image.name : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _uploadFileFromBytes(bytes, fileName);
      }
    } catch (e) {
      _showErrorSnackbar('Ошибка при съёмке: $e');
    }
  }
  
  /// Выбрать изображение из галереи (используем file_picker для обхода iOS HDR проблемы)
  Future<void> _pickImageFromGallery() async {
    debugPrint('📷 [Gallery] Starting file picker for images...');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      debugPrint('📷 [Gallery] FilePicker returned: ${result != null ? "${result.files.length} files" : "null/cancelled"}');
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        debugPrint('📷 [Gallery] File: ${file.name}, path: ${file.path}, size: ${file.size}');
        
        if (file.path != null) {
          final ioFile = File(file.path!);
          final exists = await ioFile.exists();
          debugPrint('📷 [Gallery] File exists: $exists');
          
          if (exists) {
            final bytes = await ioFile.readAsBytes();
            debugPrint('📷 [Gallery] Read ${bytes.length} bytes');
            
            if (bytes.isEmpty) {
              _showErrorSnackbar('Не удалось прочитать изображение');
              return;
            }
            
            final fileName = file.name.isNotEmpty 
                ? file.name 
                : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
            
            debugPrint('📷 [Gallery] Uploading $fileName (${bytes.length} bytes)...');
            await _uploadFileFromBytes(bytes, fileName);
            debugPrint('📷 [Gallery] Upload completed');
          }
        }
      }
    } catch (e, stack) {
      debugPrint('📷 [Gallery] ERROR: $e');
      debugPrint('📷 [Gallery] Stack: $stack');
      _showErrorSnackbar('Ошибка при выборе изображения: $e');
    }
  }
  
  /// Выбрать PDF файл
  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        // Проверка размера (10MB)
        final size = await file.length();
        if (size > 10 * 1024 * 1024) {
          _showErrorSnackbar('Файл слишком большой. Максимум 10 МБ');
          return;
        }
        await _uploadFile(file);
      }
    } catch (e) {
      _showErrorSnackbar('Ошибка при выборе файла: $e');
    }
  }
  
  /// Загрузить файл на сервер
  Future<void> _uploadFile(File file) async {
    final chatState = ref.read(paymentChatControllerProvider);
    final conversationId = chatState.conversation?.id;
    
    if (conversationId == null) {
      _showErrorSnackbar('Чат не инициализирован');
      return;
    }
    
    final result = await ref.read(paymentChatControllerProvider.notifier).uploadFile(file, conversationId);
    
    if (result == null) {
      _showErrorSnackbar('Ошибка при загрузке файла');
    }
  }
  
  /// Загрузить файл из bytes на сервер (для iOS)
  Future<void> _uploadFileFromBytes(Uint8List bytes, String fileName) async {
    final chatState = ref.read(paymentChatControllerProvider);
    final conversationId = chatState.conversation?.id;
    
    if (conversationId == null) {
      _showErrorSnackbar('Чат не инициализирован');
      return;
    }
    
    if (bytes.isEmpty) {
      _showErrorSnackbar('Файл пустой');
      return;
    }
    
    final result = await ref.read(paymentChatControllerProvider.notifier).uploadFileFromBytes(bytes, fileName, conversationId);
    
    if (result == null) {
      _showErrorSnackbar('Ошибка при загрузке файла');
    }
  }
  
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Отправить начальное сообщение с информацией о счёте (если есть)
  Future<void> _sendInitialInvoiceMessage() async {
    if (_initialMessageSent) return;
    if (widget.initialMessage == null || widget.initialMessage!.isEmpty) return;
    
    _initialMessageSent = true;
    
    Map<String, dynamic>? metadata;
    if (widget.invoiceId != null) {
      metadata = {
        'type': 'invoice_payment_request',
        'invoiceId': widget.invoiceId,
        'invoiceNumber': widget.invoiceNumber,
        'amount': widget.amount,
      };
    }
    
    await _handleMessageSend(widget.initialMessage!, metadata: metadata);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showQuickSendSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => _QuickSendSheet(
        onTrackSelected: _sendTrackInfo,
        onInvoiceSelected: _sendInvoiceInfo,
      ),
    );
  }

  void _sendTrackInfo(TrackItem track) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final buffer = StringBuffer();

    buffer.writeln('📦 **Информация о треке**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔢 Номер: ${track.code}');
    buffer.writeln('📊 Статус: ${track.status}');
    buffer.writeln('📅 Дата: ${dateFormat.format(track.date)}');

    if (track.comment != null) {
      buffer.writeln('💬 Комментарий: ${track.comment}');
    }

    if (track.assembly != null) {
      buffer.writeln('');
      buffer.writeln('📁 **Сборка:** ${track.assembly!.number}');
      buffer.writeln('   • Статус: ${track.assembly!.statusName ?? track.assembly!.status}');
    }

    if (track.photoReportUrls.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📸 Фото отчёт: ${track.photoReportUrls.length} фото');
    }

    final activePhoto = track.activePhotoRequest;
    if (activePhoto != null) {
      buffer.writeln('📷 Запрос фото: ${activePhoto.status}');
    }

    _handleMessageSend(buffer.toString());
  }

  void _sendInvoiceInfo(InvoiceItem invoice) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer();

    buffer.writeln('🧾 **Информация о счёте**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔢 Номер: ${invoice.invoiceNumber}');
    buffer.writeln('📊 Статус: ${invoice.status}');
    buffer.writeln('📅 Дата отправки: ${dateFormat.format(invoice.sendDate)}');
    buffer.writeln('');
    buffer.writeln('📦 **Параметры груза:**');
    buffer.writeln('   • Мест: ${invoice.placesCount}');
    buffer.writeln('   • Вес: ${invoice.weight.toStringAsFixed(1)} кг');
    buffer.writeln('   • Объём: ${invoice.volume.toStringAsFixed(2)} м³');
    buffer.writeln(
      '   • Плотность: ${invoice.density.toStringAsFixed(0)} кг/м³',
    );

    if (invoice.tariffName != null) {
      buffer.writeln('   • Тариф: ${invoice.tariffName}');
    }

    buffer.writeln('');
    buffer.writeln('💰 **Стоимость:**');
    if (invoice.tariffBaseCost != null && invoice.tariffBaseCost! > 0) {
      buffer.writeln('   • Тариф: \$${invoice.tariffBaseCost!.toStringAsFixed(2)}/кг');
    }
    if (invoice.insuranceCost != null && invoice.insuranceCost! > 0) {
      buffer.writeln(
        '   • Страховка: \$${invoice.insuranceCost!.toStringAsFixed(2)}',
      );
    }
    if (invoice.packagings.isNotEmpty) {
      final packagingTotal = invoice.packagings.fold<double>(0, (sum, p) => sum + p.cost);
      buffer.writeln(
        '   • Упаковка: \$${packagingTotal.toStringAsFixed(2)}',
      );
    }
    buffer.writeln(
      '   • **Итого:** ${invoice.totalCostRub.toStringAsFixed(0)} ₽',
    );

    if (invoice.scalePhotoUrls.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📸 Фото: ${invoice.scalePhotoUrls.length} шт.');
    }

    _handleMessageSend(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Stack(
      children: [
        // Градиентный фон как на других страницах
        const Positioned.fill(child: AppBackground()),

        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Отступ сверху для навигации (уменьшен для баннера)
              const SizedBox(height: 15),

              // Информационный блок о назначении чата (перемещён выше)
              _buildInfoBanner(),

              // Список сообщений
              Expanded(
                child: _buildMessagesList(),
              ),

              // Панель быстрых действий
              if (_showQuickActions) _buildQuickActionsBar(),

              // Поле ввода
              _buildInputField(bottomInset),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    final chatState = ref.watch(paymentChatControllerProvider);
    
    if (chatState.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(context.brandPrimary),
        ),
      );
    }
    
    if (chatState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              chatState.error!,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(paymentChatControllerProvider.notifier).loadConversation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandPrimary,
              ),
              child: const Text('Повторить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final messages = chatState.messages;

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    // Автопрокрутка вниз
    _scrollToBottom();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message);
      },
    );
  }
  
  /// Информационный баннер о назначении чата
  Widget _buildInfoBanner() {
    return GestureDetector(
      onTap: () => setState(() => _isInfoBannerExpanded = !_isInfoBannerExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE0B2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Чат только для оплаты счетов',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isInfoBannerExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '• Специалист не сможет ответить на вопросы, не касающиеся приёма оплаты\n'
                  '• Отправьте скриншот платежа для подтверждения\n'
                  '• Статус счёта обновится после проверки',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                    height: 1.3,
                  ),
                ),
              ),
              crossFadeState: _isInfoBannerExpanded 
                  ? CrossFadeState.showSecond 
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isFromClient;
    final dateFormat = DateFormat('HH:mm');

    // Используем реальное имя из сообщения
    final authorName = message.senderName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Имя автора сообщения
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 40,
              right: isMe ? 40 : 0,
              bottom: 4,
            ),
            child: Text(
              authorName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),

          // Сообщение
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                            colors: [context.brandPrimary, context.brandSecondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Отображаем вложения
                      if (message.attachments.isNotEmpty)
                        _buildMessageAttachments(message.attachments, isMe),
                      
                      // Текст сообщения (если это не просто "Файл")
                      if (message.content.isNotEmpty && message.content != 'Файл')
                        MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            strong: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            em: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            a: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: isMe ? Colors.white : context.brandPrimary,
                              decoration: TextDecoration.underline,
                            ),
                            code: TextStyle(
                              fontSize: 14,
                              color: isMe ? Colors.white : Colors.black87,
                              backgroundColor: isMe 
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                            listBullet: TextStyle(
                              fontSize: 15,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                          ),
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      if (message.content.isNotEmpty && message.content != 'Файл')
                        const SizedBox(height: 4),
                      Text(
                        dateFormat.format(message.createdAt.toLocal()),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isMe) ...[
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: context.brandPrimary,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  /// Отображение вложений в сообщении
  Widget _buildMessageAttachments(List<ChatAttachment> attachments, bool isMe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attachments.map((attachment) {
        final isImage = attachment.fileType.startsWith('image/');
        final fullUrl = attachment.url.startsWith('http') 
            ? attachment.url 
            : '${ApiConfig.mediaBaseUrl}${attachment.url}';
        
        if (isImage) {
          return GestureDetector(
            onTap: () => _showFullImage(fullUrl, attachment.fileName),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: fullUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 150,
                    height: 150,
                    color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 150,
                    height: 100,
                    color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: isMe ? Colors.white70 : Colors.black45,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ошибка загрузки',
                          style: TextStyle(
                            fontSize: 12,
                            color: isMe ? Colors.white70 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          // PDF или другой файл
          return GestureDetector(
            onTap: () => _downloadFile(fullUrl, attachment.fileName),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: isMe ? Colors.white : const Color(0xFF4CAF50),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.fileName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (attachment.fileSize != null)
                          Text(
                            _formatFileSize(attachment.fileSize!),
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe ? Colors.white70 : Colors.black45,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.download_rounded,
                    color: isMe ? Colors.white70 : const Color(0xFF4CAF50),
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }
      }).toList(),
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  /// Показать изображение на весь экран
  void _showFullImage(String url, String fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PaymentFullScreenImageView(
          imageUrl: url,
          fileName: fileName,
          onDownload: () => _downloadFile(url, fileName),
        ),
      ),
    );
  }
  
  /// Скачать файл
  Future<void> _downloadFile(String url, String fileName) async {
    try {
      // Показываем индикатор загрузки
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Загрузка файла...'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Получаем директорию для сохранения
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      
      // Скачиваем файл
      final dio = Dio();
      await dio.download(url, filePath);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Файл сохранён: $fileName'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Открыть',
            textColor: Colors.white,
            onPressed: () {
              // Открываем файл
              launchUrl(Uri.file(filePath));
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Чат по оплате',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Напишите нам по любым вопросам оплаты счетов и доставки',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.local_shipping_rounded,
              label: 'Отправить трек',
              onTap: _showQuickSendSheet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.receipt_long_rounded,
              label: 'Отправить счёт',
              onTap: _showQuickSendSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(double bottomInset) {
    final chatState = ref.watch(paymentChatControllerProvider);
    final pendingAttachments = chatState.pendingAttachments;
    final isUploading = chatState.isUploading;
    
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview прикреплённых файлов
            if (pendingAttachments.isNotEmpty || isUploading)
              _buildPendingAttachments(pendingAttachments, isUploading),
            
            Row(
              children: [
                // Кнопка прикрепления файла
                GestureDetector(
                  onTap: _showAttachmentPicker,
                  onLongPress: _showQuickSendSheet,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.attach_file_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Поле ввода
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Введите ваше сообщение...',
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: _handleMessageSend,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Кнопка отправки с индикатором загрузки
                Builder(
                  builder: (context) {
                    final isSending = ref.watch(paymentChatControllerProvider.select((s) => s.isSending));
                    return GestureDetector(
                      onTap: (isSending || isUploading) ? null : () => _handleMessageSend(_textController.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: (isSending || isUploading)
                                ? [Colors.grey, Colors.grey.shade400]
                                : [context.brandPrimary, context.brandSecondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: (isSending || isUploading)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// Виджет для отображения прикреплённых файлов перед отправкой
  Widget _buildPendingAttachments(List<Map<String, dynamic>> attachments, bool isUploading) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Показываем загружаемый файл
            if (isUploading)
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                    ),
                  ),
                ),
              ),
            
            // Показываем уже загруженные файлы
            ...attachments.map((attachment) {
              final fileType = attachment['fileType'] as String? ?? '';
              final fileName = attachment['fileName'] as String? ?? 'file';
              final url = attachment['url'] as String? ?? '';
              final isImage = fileType.startsWith('image/');
              
              return Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    // Превью файла
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isImage
                          ? CachedNetworkImage(
                              imageUrl: url.startsWith('http') 
                                  ? url 
                                  : '${ApiConfig.mediaBaseUrl}$url',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFFF0F0F0),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFFF0F0F0),
                                child: const Icon(Icons.error),
                              ),
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf,
                                    color: Color(0xFF4CAF50),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      fileName,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    
                    // Кнопка удаления
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          final id = attachment['id']?.toString();
                          if (id != null) {
                            ref.read(paymentChatControllerProvider.notifier).removePendingAttachment(id);
                          }
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSendSheet extends ConsumerStatefulWidget {
  final Function(TrackItem) onTrackSelected;
  final Function(InvoiceItem) onInvoiceSelected;

  const _QuickSendSheet({
    required this.onTrackSelected,
    required this.onInvoiceSelected,
  });

  @override
  ConsumerState<_QuickSendSheet> createState() => _QuickSendSheetState();
}

class _QuickSendSheetState extends ConsumerState<_QuickSendSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientCodeAsync = ref.watch(clientCodesControllerProvider);
    final clientCode = clientCodeAsync.value?.activeCode ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Быстрая отправка',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выберите трек или счёт для отправки в чат',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Поиск по номеру...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Треки'),
                Tab(text: 'Счета'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTracksList(clientCode),
                _buildInvoicesList(clientCode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracksList(String clientCode) {
    final tracksAsync = ref.watch(tracksSimpleListProvider(clientCode));

    return tracksAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      ),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (tracks) {
        final filtered = tracks
            .where(
              (t) =>
                  t.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  t.status.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'Треки не найдены',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final track = filtered[index];
            return _TrackListTile(
              track: track,
              onTap: () {
                widget.onTrackSelected(track);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInvoicesList(String clientCode) {
    final invoicesAsync = ref.watch(invoicesListProvider(clientCode));

    return invoicesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      ),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (invoices) {
        final filtered = invoices
            .where(
              (i) =>
                  i.invoiceNumber.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  i.status.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'Счета не найдены',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final invoice = filtered[index];
            return _InvoiceListTile(
              invoice: invoice,
              onTap: () {
                widget.onInvoiceSelected(invoice);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}

class _TrackListTile extends StatelessWidget {
  final TrackItem track;
  final VoidCallback onTap;

  const _TrackListTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.status} • ${dateFormat.format(track.date)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceListTile extends StatelessWidget {
  final InvoiceItem invoice;
  final VoidCallback onTap;

  const _InvoiceListTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${invoice.status} • ${dateFormat.format(invoice.sendDate)} • ${invoice.totalCostRub.toStringAsFixed(0)} ₽',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Полноэкранный просмотр изображения (Payment Chat)
class _PaymentFullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String fileName;
  final VoidCallback onDownload;

  const _PaymentFullScreenImageView({
    required this.imageUrl,
    required this.fileName,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: onDownload,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Не удалось загрузить изображение',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
