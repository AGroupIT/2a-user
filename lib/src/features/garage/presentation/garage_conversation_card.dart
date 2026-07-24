import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_config.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_toast.dart';
import '../application/garage_providers.dart';
import '../domain/garage_models.dart';
import 'garage_translated_text.dart';
import 'garage_ui.dart';

class GarageConversationCard extends ConsumerStatefulWidget {
  final GarageRequest request;

  const GarageConversationCard({super.key, required this.request});

  @override
  ConsumerState<GarageConversationCard> createState() =>
      _GarageConversationCardState();
}

class _GarageConversationCardState
    extends ConsumerState<GarageConversationCard> {
  final _controller = TextEditingController();
  GarageMessagePage? _page;
  GarageRequestMessage? _replyTo;
  List<GarageMessageAttachment> _pendingAttachments = const [];
  String? _error;
  int _initialUnreadCount = 0;
  int _latestRefresh = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GarageConversationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _page = null;
      _replyTo = null;
      _initialUnreadCount = 0;
      unawaited(_load());
      return;
    }
    if (oldWidget.request.lastMessageAt != widget.request.lastMessageAt) {
      unawaited(_load(showLoader: false));
    }
  }

  Future<void> _load({bool more = false, bool showLoader = true}) async {
    final cursor = more ? _page?.nextCursor : null;
    if (more && cursor == null) return;
    final refresh = more ? _latestRefresh : ++_latestRefresh;
    if (mounted && showLoader) {
      setState(() {
        if (more) {
          _loadingMore = true;
        } else {
          _loading = true;
        }
        _error = null;
      });
    }
    try {
      final loaded = await ref
          .read(garageRepositoryProvider)
          .getRequestMessages(widget.request.id, cursor: cursor);
      if (!mounted || (!more && refresh != _latestRefresh)) return;
      final merged = more && _page != null ? _page!.append(loaded) : loaded;
      setState(() {
        _page = merged;
        _error = null;
        if (!more && _initialUnreadCount == 0) {
          _initialUnreadCount = loaded.unreadCount;
        }
        _loading = false;
        _loadingMore = false;
      });
      if (merged.messages.isNotEmpty) {
        await _markRead(merged.messages.last.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Не удалось загрузить диалог';
      });
    }
  }

  Future<void> _markRead(int messageId) async {
    final current = _page;
    if (current == null || (current.lastReadMessageId ?? 0) >= messageId) {
      return;
    }
    try {
      final cursor = await ref
          .read(garageRepositoryProvider)
          .markRequestMessagesRead(
            widget.request.id,
            lastReadMessageId: messageId,
          );
      if (!mounted || _page == null) return;
      setState(() {
        final page = _page!;
        _page = GarageMessagePage(
          messages: page.messages,
          nextCursor: page.nextCursor,
          unreadCount: 0,
          lastReadMessageId: cursor.lastReadMessageId,
        );
      });
    } catch (_) {
      // Read cursor is best-effort and must not block the conversation.
    }
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    final attachments = _pendingAttachments;
    if ((content.isEmpty && attachments.isEmpty) || _sending) return;
    final reply = _replyTo;
    setState(() => _sending = true);
    try {
      await ref
          .read(garageRepositoryProvider)
          .sendRequestMessage(
            widget.request.id,
            content: content,
            messageType: reply?.messageType == 'question'
                ? 'answer'
                : 'comment',
            replyToMessageId: reply?.id,
            resolveQuestion: reply?.awaitsClientAnswer == true,
            attachmentIds: attachments
                .map((attachment) => attachment.id)
                .toList(growable: false),
          );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _replyTo = null;
        _pendingAttachments = const [];
      });
      await _load(showLoader: false);
      if (!mounted) return;
      setState(() => _sending = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.show(context, 'Не удалось отправить сообщение', isError: true);
    }
  }

  Future<void> _pickImages() async {
    if (_uploading) return;
    try {
      final images = await ImagePicker().pickMultiImage(
        imageQuality: 88,
        maxWidth: 2200,
        maxHeight: 2200,
      );
      for (final image in images) {
        if (_pendingAttachments.length >= 10) break;
        await _uploadAttachment(
          bytes: await image.readAsBytes(),
          fileName: image.name,
          mimeType: image.mimeType ?? _garageChatMimeType(image.name),
        );
      }
    } catch (_) {
      if (mounted) _showUploadError();
    }
  }

  Future<void> _pickFiles() async {
    if (_uploading) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
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
    if (result == null) return;
    for (final file in result.files) {
      if (_pendingAttachments.length >= 10) break;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      await _uploadAttachment(
        bytes: bytes,
        fileName: file.name,
        mimeType: _garageChatMimeType(file.name),
      );
    }
  }

  Future<void> _uploadAttachment({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    setState(() => _uploading = true);
    try {
      final attachment = await ref
          .read(garageRepositoryProvider)
          .uploadMessageAttachment(
            requestId: widget.request.id,
            bytes: bytes,
            fileName: fileName,
            mimeType: mimeType,
          );
      if (!mounted) return;
      setState(
        () => _pendingAttachments = [..._pendingAttachments, attachment],
      );
    } catch (_) {
      if (mounted) _showUploadError();
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showUploadError() {
    AppToast.show(context, 'Не удалось загрузить вложение', isError: true);
  }

  bool get _canWrite {
    final status = canonicalGarageRequestStatus(
      widget.request.status,
      order: widget.request.order,
    );
    if (!{
      'new',
      'in_progress',
      'pending_confirmation',
      'unpaid',
      'payment_review',
      'paid',
    }.contains(status)) {
      return false;
    }
    return !{
      'completed',
      'cancelled',
      'refunded',
    }.contains(widget.request.order?.status);
  }

  @override
  Widget build(BuildContext context) {
    return GarageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Диалог по заявке',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_initialUnreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Новых: $_initialUnreadCount',
                    style: TextStyle(
                      color: context.brandPrimary,
                      fontFamily: 'Gilroy',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            GarageEmptyState(
              icon: Icons.forum_outlined,
              title: 'Диалог не загрузился',
              subtitle: _error!,
              action: GarageSecondaryButton(
                label: 'Повторить',
                icon: Icons.refresh_rounded,
                onPressed: _load,
              ),
            )
          else ...[
            if (_page?.messages.isEmpty ?? true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Сообщений пока нет. Здесь можно уточнить детали заявки.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              for (final message in _page!.messages)
                _MessageBubble(
                  message: message,
                  replyTarget: _findMessage(message.replyToMessageId),
                  onReply: message.awaitsClientAnswer && _canWrite
                      ? () => setState(() => _replyTo = message)
                      : null,
                ),
            if (_page?.nextCursor != null) ...[
              const SizedBox(height: 8),
              GarageSecondaryButton(
                label: _loadingMore
                    ? 'Загрузка…'
                    : 'Показать следующие сообщения',
                icon: Icons.expand_more_rounded,
                onPressed: _loadingMore ? null : () => _load(more: true),
              ),
            ],
            const SizedBox(height: 12),
            if (_canWrite) _composer() else _readOnlyNotice(),
          ],
        ],
      ),
    );
  }

  GarageRequestMessage? _findMessage(int? messageId) {
    if (messageId == null) return null;
    for (final message in _page?.messages ?? const <GarageRequestMessage>[]) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  Widget _composer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_replyTo != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _translatedMessageText(
                    _replyTo!,
                    prefix: 'Ответ на вопрос: ',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Отменить ответ',
                  onPressed: () => setState(() => _replyTo = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        if (_pendingAttachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _pendingAttachments
                  .map(
                    (attachment) => InputChip(
                      avatar: Icon(
                        attachment.isImage
                            ? Icons.image_outlined
                            : Icons.insert_drive_file_outlined,
                        size: 17,
                      ),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Text(
                          attachment.fileName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onDeleted: _sending
                          ? null
                          : () => setState(
                              () => _pendingAttachments = _pendingAttachments
                                  .where((item) => item.id != attachment.id)
                                  .toList(growable: false),
                            ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Добавить изображения',
              onPressed: _sending || _uploading ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              color: context.brandPrimary,
            ),
            IconButton(
              tooltip: 'Добавить файл',
              onPressed: _sending || _uploading ? null : _pickFiles,
              icon: const Icon(Icons.attach_file_rounded),
              color: AppColors.textSecondary,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_sending,
                maxLength: 4000,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: _replyTo == null
                      ? 'Напишите сообщение'
                      : 'Введите ответ сотруднику',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Отправить',
              onPressed: _sending || _uploading ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
        if (_uploading)
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _readOnlyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Диалог доступен только для чтения.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontFamily: 'Gilroy',
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final GarageRequestMessage message;
  final GarageRequestMessage? replyTarget;
  final VoidCallback? onReply;

  const _MessageBubble({
    required this.message,
    required this.replyTarget,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final mine = message.isFromClient;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine
              ? context.brandPrimary.withValues(alpha: 0.1)
              : const Color(0xFFF3F5F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message.senderName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: mine
                          ? context.brandPrimary
                          : AppColors.textPrimary,
                      fontFamily: 'Gilroy',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _messageTypeLabel(message.messageType),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (replyTarget != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _translatedMessageText(
                  replyTarget!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            _translatedMessageText(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final attachment in message.attachments)
                _GarageChatAttachmentTile(attachment: attachment),
            ],
            if (onReply != null) ...[
              const SizedBox(height: 5),
              TextButton.icon(
                onPressed: onReply,
                icon: const Icon(Icons.reply_rounded, size: 17),
                label: const Text('Ответить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _messageTypeLabel(String value) {
  return switch (value) {
    'question' => 'Вопрос',
    'answer' => 'Ответ',
    _ => 'Комментарий',
  };
}

Widget _translatedMessageText(
  GarageRequestMessage message, {
  String prefix = '',
  TextStyle? style,
  int? maxLines,
  TextOverflow? overflow,
}) {
  final source = '$prefix${message.content}';
  final translated = message.contentRu?.trim().isNotEmpty == true
      ? '$prefix${message.contentRu!.trim()}'
      : null;
  if (message.isFromClient) {
    return Text(source, style: style, maxLines: maxLines, overflow: overflow);
  }
  return GarageTranslatedText(
    source,
    translatedText: translated,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );
}

class _GarageChatAttachmentTile extends StatelessWidget {
  final GarageMessageAttachment attachment;

  const _GarageChatAttachmentTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final fullUrl = ApiConfig.getMediaUrl(attachment.url);
    final uri = Uri.tryParse(fullUrl);
    if (attachment.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: InkWell(
          onTap: uri == null
              ? null
              : () => launchUrl(uri, mode: LaunchMode.externalApplication),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              fullUrl,
              width: 230,
              height: 170,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 230,
                height: 100,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(11),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(
            attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_garageChatFileSize(attachment.fileSize)),
          trailing: const Icon(Icons.open_in_new_rounded, size: 17),
          onTap: uri == null
              ? null
              : () => launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
      ),
    );
  }
}

String _garageChatMimeType(String fileName) {
  final extension = fileName.toLowerCase().split('.').last;
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'csv' => 'text/csv',
    'txt' => 'text/plain',
    'rtf' => 'application/rtf',
    'zip' => 'application/zip',
    'rar' => 'application/x-rar-compressed',
    '7z' => 'application/x-7z-compressed',
    _ => 'application/octet-stream',
  };
}

String _garageChatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}
