import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/blurred_media_backdrop.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/ui/quill_delta_viewer.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/rules_provider.dart';

const _ruleDetailTextColor = Color(0xFF2F2F2F);
const _ruleDetailMutedTextColor = Color(0x992F2F2F);

BoxDecoration _ruleDetailCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), offset: Offset(3, 4), blurRadius: 25),
    ],
  );
}

class RuleDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  const RuleDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<RuleDetailScreen> createState() => _RuleDetailScreenState();
}

class _RuleDetailScreenState extends ConsumerState<RuleDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncItem = ref.watch(ruleItemProvider(widget.slug));
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    Widget buildFrame({required List<Widget> children}) {
      return Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 16,
              16,
              bottomPad + 16,
            ),
            children: children,
          ),
          ScrollToTopButton(controller: _scrollController),
        ],
      );
    }

    return asyncItem.when(
      loading: () => buildFrame(
        children: const [
          AppPageHeader(title: 'Правило', showBack: true),
          SizedBox(height: 15),
          _RuleDetailStateCard(
            icon: Icons.rule_rounded,
            title: 'Загружаем правило',
            message: 'Получаем актуальный текст правила.',
            isLoading: true,
          ),
        ],
      ),
      error: (e, _) {
        final errorInfo = ErrorUtils.getErrorInfo(e);
        return buildFrame(
          children: [
            AppPageHeader(
              title: tr(context, ru: 'Правило', zh: '规则'),
              showBack: true,
            ),
            const SizedBox(height: 15),
            _RuleDetailStateCard(
              icon: errorInfo.icon,
              title: errorInfo.title,
              message: errorInfo.message,
              isError: true,
            ),
          ],
        );
      },
      data: (item) {
        if (item == null) {
          return buildFrame(
            children: [
              AppPageHeader(
                title: tr(context, ru: 'Правило', zh: '规则'),
                showBack: true,
              ),
              const SizedBox(height: 15),
              _RuleDetailStateCard(
                icon: Icons.article_outlined,
                title: tr(context, ru: 'Правило не найдено', zh: '未找到规则'),
                message: tr(
                  context,
                  ru: 'Правило могло быть удалено или снято с публикации.',
                  zh: '该规则可能已被删除或取消发布。',
                ),
                isError: true,
              ),
            ],
          );
        }

        return TutorialScreenWrapper(
          screenKey: 'rule_detail',
          steps: const [
            TutorialStep(
              icon: Icons.rule_rounded,
              title: 'Текст правила',
              description:
                  'Здесь отображается полное содержание правила. Прокрутите вниз, чтобы прочитать его целиком.',
            ),
            TutorialStep(
              icon: Icons.image_rounded,
              title: 'Изображения',
              description:
                  'Нажмите на любое изображение в правиле, чтобы открыть его на весь экран и увеличить.',
            ),
          ],
          child: buildFrame(
            children: [
              AppPageHeader(
                title: tr(context, ru: 'Правило', zh: '规则'),
                showBack: true,
              ),
              const SizedBox(height: 15),
              Container(
                decoration: _ruleDetailCardDecoration(),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${item.order}',
                          style: TextStyle(
                            color: context.brandPrimary,
                            fontFamily: 'Gilroy',
                            fontSize: 20,
                            height: 24 / 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: _ruleDetailTextColor,
                              fontFamily: 'Gilroy',
                              fontSize: 20,
                              height: 25 / 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              Container(
                decoration: _ruleDetailCardDecoration(),
                padding: const EdgeInsets.all(16),
                child: QuillDeltaViewer(
                  jsonContent: item.content,
                  linkColor: context.brandPrimary,
                  onImageTap: (imageUrl) =>
                      _openImageFullscreen(context, imageUrl),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Открывает изображение в полноэкранном режиме
  void _openImageFullscreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }
}

class _RuleDetailStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool isLoading;
  final bool isError;

  const _RuleDetailStateCard({
    required this.icon,
    required this.title,
    this.message,
    this.isLoading = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isError ? const Color(0xFFE53935) : context.brandPrimary;
    return Container(
      decoration: _ruleDetailCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(icon, color: accent, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ruleDetailTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: _ruleDetailMutedTextColor,
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      height: 16 / 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Полноэкранный просмотрщик изображения с зумом
class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullscreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlurredMediaBackdrop(
        imageUrl: imageUrl,
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}
