// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
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
import '../../../core/ui/tutorial_card.dart';

import '../../../core/ui/app_background.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/chat_presence_service.dart';
import '../../../core/network/api_config.dart';
import '../data/chat_provider.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';
import '../../../core/utils/locale_text.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;

  const SupportChatScreen({super.key, this.initialMessage});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;
  bool _isDisposed = false;

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // Локальный флаг защиты от двойной отправки (синхронный, выставляется раньше isSending в контроллере)
  bool _isSendingLocally = false;

  final GlobalKey _messagesAreaKey = GlobalKey();
  final GlobalKey _inputAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();

    // Загружаем чат и запускаем polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isChatScreenOpenProvider.notifier).set(true);
      ref.read(chatControllerProvider.notifier).loadConversation();

      // Если есть начальное сообщение - устанавливаем его в текстовое поле
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
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
    final chatState = ref.read(chatControllerProvider);
    final conversationId = chatState.conversation?.id;
    await ref
        .read(chatPresenceServiceProvider)
        .openChat(ChatType.support, conversationId: conversationId);
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
    ref.read(chatControllerProvider.notifier).pollNewMessages();
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
    _isDisposed = true;
    _pollingTimer?.cancel();

    // Не используем ref в dispose() - это небезопасно
    // ref.read() выполняется асинхронно при деактивации виджета

    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _isDisposed) return;
    _appLifecycleState = state;
    debugPrint('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      _clearNotifications();
      // Обновляем сообщения при возврате в приложение
      ref.read(chatControllerProvider.notifier).pollNewMessages();
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

  Future<void> _handleMessageSend(String text) async {
    if (_isSendingLocally) return;

    final chatState = ref.read(chatControllerProvider);
    if (chatState.isSending) return;

    final pendingAttachments = chatState.pendingAttachments;

    // Если нет текста и нет вложений - ничего не делаем
    if (text.trim().isEmpty && pendingAttachments.isEmpty) return;

    setState(() => _isSendingLocally = true);
    try {
      HapticFeedback.lightImpact();
      _textController.selection = const TextSelection.collapsed(offset: 0);
      _textController.clear();

      // Собираем ID вложений
      final attachmentIds = pendingAttachments.map((a) => a.id).toList();

      final success = await ref
          .read(chatControllerProvider.notifier)
          .sendMessage(
            text.isEmpty ? 'Файл' : text,
            attachmentIds: attachmentIds,
          );

      if (success) {
        // Очищаем pending attachments
        ref.read(chatControllerProvider.notifier).clearPendingAttachments();
        // Прокрутка вниз после отправки
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingLocally = false);
      } else {
        _isSendingLocally = false;
      }
    }
  }

  /// Показать диалог выбора типа вложения
  void _showAttachmentPicker() {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => Container(
        margin: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          AppLayout.bottomBarObstruction(context) + 16,
        ),
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
            Text(
              tr(context, ru: 'Прикрепить файл', zh: '附加文件'),
              style: const TextStyle(
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
              title: Text(
                tr(context, ru: 'Камера', zh: '相机'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                tr(context, ru: 'Сделать фото', zh: '拍照'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
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
              title: Text(
                tr(context, ru: 'Галерея', zh: '相册'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                tr(context, ru: 'Выбрать изображение', zh: '选择图片'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
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
                child: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.orange,
                ),
              ),
              title: Text(
                tr(context, ru: 'Документ', zh: '文档'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                tr(
                  context,
                  ru: 'PDF, Word, Excel и другие',
                  zh: 'PDF、Word、Excel等',
                ),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocumentFile();
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
        final fileName = image.name.isNotEmpty
            ? image.name
            : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _uploadFileFromBytes(bytes, fileName);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(
          tr(context, ru: 'Ошибка при съёмке: $e', zh: '拍照错误：$e'),
        );
      }
    }
  }

  /// Выбрать изображение из галереи
  Future<void> _pickImageFromGallery() async {
    debugPrint('📷 [Gallery] Starting image picker via file_picker...');
    try {
      // Используем file_picker вместо image_picker для обхода проблемы с HDR на iOS
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      debugPrint(
        '📷 [Gallery] file_picker returned: ${result != null ? "file selected" : "null/cancelled"}',
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        debugPrint('📷 [Gallery] File name: ${file.name}');
        debugPrint('📷 [Gallery] File size: ${file.size}');

        // Для веб-версии используем bytes, для мобильных - path
        final bytes = kIsWeb
            ? file.bytes
            : (file.path != null ? await File(file.path!).readAsBytes() : null);

        if (bytes == null || bytes.isEmpty) {
          debugPrint('📷 [Gallery] ERROR: could not read file bytes');
          if (mounted) {
            _showErrorSnackbar(
              tr(context, ru: 'Не удалось прочитать файл', zh: '无法读取文件'),
            );
          }
          return;
        }

        debugPrint('📷 [Gallery] Bytes read: ${bytes.length}');

        // Определяем имя файла
        String fileName = file.name;
        if (fileName.isEmpty) {
          fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }

        debugPrint('📷 [Gallery] Uploading ${bytes.length} bytes as $fileName');
        await _uploadFileFromBytes(bytes, fileName);
        debugPrint('📷 [Gallery] Upload completed');
      }
    } catch (e, stack) {
      debugPrint('📷 [Gallery] ERROR: $e');
      debugPrint('📷 [Gallery] Stack: $stack');
      if (mounted) {
        _showErrorSnackbar(
          tr(context, ru: 'Ошибка при выборе изображения: $e', zh: '选择图片错误：$e'),
        );
      }
    }
  }

  /// Выбрать документ (PDF, Word, Excel и др.)
  Future<void> _pickDocumentFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'csv',
          'ppt',
          'pptx',
          'txt',
          'rtf',
          'zip',
          'rar',
          '7z',
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Для веб-версии используем bytes, для мобильных - path
        final bytes =
            file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);

        if (bytes == null || bytes.isEmpty) {
          if (mounted) {
            _showErrorSnackbar(
              tr(context, ru: 'Не удалось прочитать файл', zh: '无法读取文件'),
            );
          }
          return;
        }

        // Проверка размера (10MB)
        if (bytes.length > 10 * 1024 * 1024) {
          if (mounted) {
            _showErrorSnackbar(
              tr(
                context,
                ru: 'Файл слишком большой. Максимум 10 МБ',
                zh: '文件太大。最大 10 MB',
              ),
            );
          }
          return;
        }

        final fileName = file.name.isNotEmpty
            ? file.name
            : 'document_${DateTime.now().millisecondsSinceEpoch}';

        await _uploadFileFromBytes(bytes, fileName);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(
          tr(context, ru: 'Ошибка при выборе файла: $e', zh: '选择文件错误：$e'),
        );
      }
    }
  }

  /// Загрузить файл из bytes на сервер (для iOS)
  Future<void> _uploadFileFromBytes(Uint8List bytes, String fileName) async {
    debugPrint(
      '📤 [Upload] _uploadFileFromBytes called with ${bytes.length} bytes, fileName: $fileName',
    );

    final chatState = ref.read(chatControllerProvider);
    final conversationId = chatState.conversation?.id;

    debugPrint('📤 [Upload] conversationId: $conversationId');

    if (conversationId == null) {
      debugPrint('📤 [Upload] ERROR: conversationId is null!');
      if (mounted) {
        _showErrorSnackbar(
          tr(context, ru: 'Чат не инициализирован', zh: '聊天未初始化'),
        );
      }
      return;
    }

    if (bytes.isEmpty) {
      debugPrint('📤 [Upload] ERROR: bytes are empty!');
      if (mounted) {
        _showErrorSnackbar(tr(context, ru: 'Файл пустой', zh: '文件为空'));
      }
      return;
    }

    debugPrint('📤 [Upload] Calling controller.uploadFileFromBytes...');
    final result = await ref
        .read(chatControllerProvider.notifier)
        .uploadFileFromBytes(bytes, fileName);

    debugPrint(
      '📤 [Upload] Result: ${result != null ? "success" : "null/error"}',
    );
    if (result == null && mounted) {
      _showErrorSnackbar(
        tr(context, ru: 'Ошибка при загрузке файла', zh: '上传文件错误'),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    AppToast.showFromSnackBar(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Хранение контекста Showcase для вызова next()

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final shellBottomInset = AppLayout.bottomBarObstruction(context) + 8;
    final keyboardBottomInset = keyboardInset + 8;
    final composerBottomInset = keyboardBottomInset > shellBottomInset
        ? keyboardBottomInset
        : shellBottomInset;

    return TutorialScreenWrapper(
      screenKey: 'support',
      steps: [
        TutorialStep(
          icon: Icons.support_agent_rounded,
          title: 'Чат поддержки',
          description:
              'Напишите нам любой вопрос. Менеджер ответит в рабочее время. История сообщений сохраняется.',
          targetKey: _messagesAreaKey,
        ),
        TutorialStep(
          icon: Icons.attach_file_rounded,
          title: 'Вложения',
          description:
              'Прикрепите фото или файл к сообщению — это поможет быстрее разобраться с вопросом.',
          targetKey: _inputAreaKey,
        ),
        TutorialStep(
          icon: Icons.send_rounded,
          title: 'Отправка',
          description:
              'Введите текст и нажмите кнопку отправки. Можно также отправить голосовое сообщение.',
          targetKey: _inputAreaKey,
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(child: AppBackground()),
            SafeArea(
              top: false, // Контент скроллится под топ-меню
              bottom: false,
              child: KeyedSubtree(
                key: _messagesAreaKey,
                child: _buildMessagesList(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(bottom: composerBottomInset),
          child: _buildInputField(),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    final chatState = ref.watch(chatControllerProvider);

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
                ref.read(chatControllerProvider.notifier).loadConversation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandPrimary,
              ),
              child: Text(
                tr(context, ru: 'Повторить', zh: '重试'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final messages = chatState.messages;

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isFromClient;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

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
                    gradient: LinearGradient(
                      colors: [context.brandPrimary, context.brandSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
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
                            colors: [
                              context.brandPrimary,
                              context.brandSecondary,
                            ],
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
                      // Цитата (reply)
                      if (message.replyToMessageId != null)
                        GestureDetector(
                          onTap: () =>
                              _scrollToMessage(message.replyToMessageId!),
                          child: _buildReplyQuote(message, isMe),
                        ),

                      // Отображаем вложения
                      if (message.attachments.isNotEmpty)
                        _buildMessageAttachments(message.attachments, isMe),

                      // Текст сообщения (если это не просто "Файл")
                      if (message.content.isNotEmpty &&
                          message.content != 'Файл')
                        MarkdownBody(
                          data: message.content.replaceAll('\n', '  \n'),
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1.4,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            strong: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            em: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            a: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1.4,
                              color: isMe ? Colors.white : context.brandPrimary,
                              decoration: TextDecoration.underline,
                            ),
                            code: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 14,
                              color: isMe ? Colors.white : Colors.black87,
                              backgroundColor: isMe
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                            listBullet: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                          ),
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              launchUrl(
                                Uri.parse(href),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      if (message.content.isNotEmpty &&
                          message.content != 'Файл')
                        const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.isEdited) ...[
                            Text(
                              'изм.',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isMe ? Colors.white54 : Colors.black38,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            dateFormat.format(message.createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe ? Colors.white70 : Colors.black45,
                            ),
                          ),
                        ],
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
  void _scrollToMessage(int messageId) {
    final messages = ref.read(chatControllerProvider).messages;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index < 0 || !_scrollController.hasClients) return;
    final reversedIndex = messages.length - 1 - index;
    final offset = reversedIndex * 80.0;
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildReplyQuote(ChatMessage message, bool isMe) {
    final chatState = ref.read(chatControllerProvider);
    final replyMsg = chatState.messages
        .where((m) => m.id == message.replyToMessageId)
        .firstOrNull;
    if (replyMsg == null) return const SizedBox.shrink();

    final senderLabel = replyMsg.isFromClient ? 'Вы' : replyMsg.senderName;
    final quoteText = replyMsg.content.length > 60
        ? '${replyMsg.content.substring(0, 60)}...'
        : replyMsg.content;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isMe
                ? Colors.white.withValues(alpha: 0.6)
                : context.brandPrimary,
            width: 2.5,
          ),
        ),
        color: isMe
            ? Colors.white.withValues(alpha: 0.12)
            : context.brandPrimary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.8)
                  : context.brandPrimary,
            ),
          ),
          Text(
            quoteText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageAttachments(List<ChatAttachment> attachments, bool isMe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attachments.map((attachment) {
        final isImage = attachment.fileType.startsWith('image/');
        final fullUrl = ApiConfig.getMediaUrl(attachment.url);

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
                  memCacheWidth: 360,
                  memCacheHeight: 360,
                  maxWidthDiskCache: 720,
                  maxHeightDiskCache: 720,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  useOldImageOnUrlChange: false,
                  filterQuality: FilterQuality.low,
                  placeholder: (context, url) => Container(
                    width: 150,
                    height: 150,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 150,
                    height: 100,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
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
          // Документ (PDF, Word, Excel и др.)
          final docIcon = _getDocumentIcon(attachment.fileName);
          final docColor = _getDocumentColor(attachment.fileName);
          return GestureDetector(
            onTap: () => _downloadFile(fullUrl, attachment.fileName),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.2)
                          : docColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      docIcon,
                      color: isMe ? Colors.white : docColor,
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
                    color: isMe ? Colors.white70 : docColor,
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

  /// Иконка документа по расширению файла
  IconData _getDocumentIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'rtf':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'txt':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Цвет иконки документа по расширению
  Color _getDocumentColor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
      case 'rtf':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.amber;
      case 'txt':
        return Colors.grey;
      default:
        return context.brandPrimary;
    }
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
        builder: (context) => _FullScreenImageView(
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
      if (mounted) {
        AppToast.showFromSnackBar(
          context,
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(tr(context, ru: 'Загрузка файла...', zh: '正在下载文件...')),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }

      // Получаем директорию для сохранения
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // Скачиваем файл
      final dio = Dio();
      await dio.download(url, filePath);

      if (!mounted) return;

      AppToast.hide();
      AppToast.showFromSnackBar(
        context,
        SnackBar(
          content: Text(
            tr(context, ru: 'Файл сохранён: $fileName', zh: '文件已保存：$fileName'),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.fixed,
          action: SnackBarAction(
            label: tr(context, ru: 'Открыть', zh: '打开'),
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
      AppToast.hide();
      AppToast.showFromSnackBar(
        context,
        SnackBar(
          content: Text(tr(context, ru: 'Ошибка загрузки: $e', zh: '下载错误：$e')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.fixed,
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
              gradient: LinearGradient(
                colors: [context.brandPrimary, context.brandSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(context, ru: 'Чат поддержки', zh: '客服聊天'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              tr(
                context,
                ru: 'Напишите нам и мы поможем решить любой вопрос',
                zh: '给我们写信，我们会帮您解决任何问题',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    final chatState = ref.watch(chatControllerProvider);
    final pendingAttachments = chatState.pendingAttachments;
    final isUploading = chatState.isUploading;

    return Padding(
      key: _inputAreaKey,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 25,
              offset: const Offset(3, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.44),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.24),
                        ],
                        stops: const [0, 0.52, 1],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.36),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (pendingAttachments.isNotEmpty || isUploading)
                            _buildPendingAttachments(
                              context,
                              pendingAttachments,
                              isUploading,
                            ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _showAttachmentPicker,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.brandPrimary,
                                        context.brandSecondary,
                                      ],
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
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F8F8),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: TextField(
                                    controller: _textController,
                                    focusNode: _focusNode,
                                    minLines: 1,
                                    maxLines: 5,
                                    textInputAction: TextInputAction.newline,
                                    decoration: InputDecoration(
                                      hintText: tr(
                                        context,
                                        ru: 'Введите ваше сообщение...',
                                        zh: '输入您的消息...',
                                      ),
                                      hintStyle: const TextStyle(
                                        color: Colors.black38,
                                        fontSize: 15,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Builder(
                                builder: (context) {
                                  final isSending = ref.watch(
                                    chatControllerProvider.select(
                                      (s) => s.isSending,
                                    ),
                                  );
                                  final sendDisabled =
                                      isSending ||
                                      isUploading ||
                                      _isSendingLocally;
                                  return GestureDetector(
                                    onTap: sendDisabled
                                        ? null
                                        : () => _handleMessageSend(
                                            _textController.text,
                                          ),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: sendDisabled
                                              ? [
                                                  Colors.grey,
                                                  Colors.grey.shade400,
                                                ]
                                              : [
                                                  context.brandPrimary,
                                                  context.brandSecondary,
                                                ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: sendDisabled
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Виджет для отображения прикреплённых файлов перед отправкой
  Widget _buildPendingAttachments(
    BuildContext context,
    List<ChatAttachment> attachments,
    bool isUploading,
  ) {
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
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.brandPrimary,
                      ),
                    ),
                  ),
                ),
              ),

            // Показываем уже загруженные файлы
            ...attachments.map((attachment) {
              final fileType = attachment.fileType;
              final fileName = attachment.fileName;
              final url = attachment.url;
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
                              imageUrl: ApiConfig.getMediaUrl(url),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                              maxWidthDiskCache: 320,
                              maxHeightDiskCache: 320,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              useOldImageOnUrlChange: false,
                              filterQuality: FilterQuality.low,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFFF0F0F0),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                                color: _getDocumentColor(
                                  fileName,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getDocumentIcon(fileName),
                                    color: _getDocumentColor(fileName),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
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
                          ref
                              .read(chatControllerProvider.notifier)
                              .removePendingAttachment(attachment.id);
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

/// Полноэкранный просмотр изображения
class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String fileName;
  final VoidCallback onDownload;

  const _FullScreenImageView({
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
        title: Text(fileName, style: const TextStyle(fontSize: 16)),
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
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
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
