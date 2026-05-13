import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/rules_provider.dart';
import '../domain/rule_item.dart';

const _rulesTextColor = Color(0xFF2F2F2F);
const _rulesMutedTextColor = Color(0x992F2F2F);

BoxDecoration _rulesCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), offset: Offset(3, 4), blurRadius: 25),
    ],
  );
}

class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _rulesListKey = GlobalKey();
  final GlobalKey _firstRuleKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(rulesListProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    Future<void> onRefresh() async {
      ref.invalidate(rulesListProvider);
      await ref.read(rulesListProvider.future);
    }

    Widget buildFrame({required List<Widget> children}) {
      return Stack(
        children: [
          RefreshIndicator(
            onRefresh: onRefresh,
            color: context.brandPrimary,
            child: ListView(
              controller: _scrollController,
              key: _rulesListKey,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                topPad * 0.7 + 16,
                16,
                bottomPad + 16,
              ),
              children: children,
            ),
          ),
          ScrollToTopButton(controller: _scrollController),
        ],
      );
    }

    return asyncItems.when(
      loading: () => buildFrame(
        children: const [
          AppPageHeader(title: 'Правила', showBack: true),
          SizedBox(height: 15),
          _RulesStateCard(
            icon: Icons.rule_rounded,
            title: 'Загружаем правила',
            message: 'Получаем актуальные условия оказания услуг.',
            isLoading: true,
          ),
        ],
      ),
      error: (e, _) {
        final errorInfo = ErrorUtils.getErrorInfo(e);
        return buildFrame(
          children: [
            AppPageHeader(
              title: tr(context, ru: 'Правила', zh: '规则'),
              showBack: true,
            ),
            const SizedBox(height: 15),
            _RulesStateCard(
              icon: errorInfo.icon,
              title: errorInfo.title,
              message: errorInfo.message,
              isError: true,
            ),
          ],
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return buildFrame(
            children: [
              AppPageHeader(
                title: tr(context, ru: 'Правила', zh: '规则'),
                showBack: true,
              ),
              const SizedBox(height: 15),
              _RulesStateCard(
                icon: Icons.rule_folder_outlined,
                title: tr(context, ru: 'Правила не найдены', zh: '未找到规则'),
                message: tr(
                  context,
                  ru: 'Здесь появятся актуальные условия работы и доставки.',
                  zh: '这里将显示最新服务和配送规则。',
                ),
              ),
            ],
          );
        }
        return TutorialScreenWrapper(
          screenKey: 'rules',
          steps: [
            TutorialStep(
              icon: Icons.rule_rounded,
              title: 'Правила оказания услуг',
              description:
                  'Здесь собраны все условия работы с нами: ограничения, ответственность и порядок доставки.',
              targetKey: _rulesListKey,
            ),
            TutorialStep(
              icon: Icons.open_in_new_rounded,
              title: 'Читать правило',
              description:
                  'Нажмите на карточку, чтобы открыть полный текст правила.',
              targetKey: _firstRuleKey,
            ),
          ],
          child: buildFrame(
            children: [
              AppPageHeader(
                title: tr(context, ru: 'Правила', zh: '规则'),
                showBack: true,
              ),
              const SizedBox(height: 15),
              for (var i = 0; i < items.length; i++) ...[
                if (i == 0)
                  KeyedSubtree(
                    key: _firstRuleKey,
                    child: _RuleCard(item: items[i]),
                  )
                else
                  _RuleCard(item: items[i]),
                if (i != items.length - 1) const SizedBox(height: 15),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _RulesStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool isLoading;
  final bool isError;

  const _RulesStateCard({
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
      decoration: _rulesCardDecoration(),
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
                    color: _rulesTextColor,
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
                      color: _rulesMutedTextColor,
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

class _RuleCard extends StatelessWidget {
  final RuleItem item;
  const _RuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _rulesCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/rules/${item.slug}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
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
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        height: 24 / 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: _rulesTextColor,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 20 / 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.excerpt,
                        style: const TextStyle(
                          color: _rulesMutedTextColor,
                          fontFamily: 'Gilroy',
                          fontSize: 13,
                          height: 16 / 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Arrow
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Color(0x662F2F2F),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
