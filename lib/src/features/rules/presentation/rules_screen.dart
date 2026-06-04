import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/rules_provider.dart';
import '../domain/rule_item.dart';
import 'rules_ui.dart';

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

    List<Widget> baseHeader() {
      return [
        RulesPageHeader(
          title: tr(context, ru: 'Правила', zh: '规则'),
        ),
        const SizedBox(height: 12),
        RulesHeroCard(
          icon: Icons.verified_user_rounded,
          title: tr(context, ru: 'Правила оказания услуг', zh: '服务规则'),
          subtitle: tr(
            context,
            ru: 'Актуальные условия работы, доставки, хранения и ответственности сторон.',
            zh: '服务、配送、仓储和双方责任的最新规则。',
          ),
        ),
        const SizedBox(height: 14),
      ];
    }

    return asyncItems.when(
      loading: () => buildFrame(
        children: [
          ...baseHeader(),
          RulesStateCard(
            icon: Icons.rule_rounded,
            title: tr(context, ru: 'Загружаем правила', zh: '正在加载规则'),
            message: tr(
              context,
              ru: 'Получаем актуальные условия оказания услуг.',
              zh: '正在获取最新服务规则。',
            ),
            isLoading: true,
          ),
        ],
      ),
      error: (e, _) {
        final errorInfo = ErrorUtils.getErrorInfo(e);
        return buildFrame(
          children: [
            ...baseHeader(),
            RulesStateCard(
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
              ...baseHeader(),
              RulesStateCard(
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
              ...baseHeader(),
              for (var i = 0; i < items.length; i++) ...[
                if (i == 0)
                  KeyedSubtree(
                    key: _firstRuleKey,
                    child: _RuleCard(item: items[i]),
                  )
                else
                  _RuleCard(item: items[i]),
                if (i != items.length - 1) const SizedBox(height: 12),
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

class _RuleCard extends StatelessWidget {
  final RuleItem item;
  const _RuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final orderLabel = item.order > 0 ? item.order.toString() : '•';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/rules/${item.slug}'),
        child: Container(
          decoration: RulesUi.cardDecoration(),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.brandPrimary,
                      context.brandPrimary.withValues(alpha: 0.78),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    orderLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        height: 21 / 17,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (item.excerpt.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        item.excerpt,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontSize: 13.5,
                          height: 18 / 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
