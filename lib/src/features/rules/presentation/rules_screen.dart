import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/services/auto_refresh_service.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/rules_provider.dart';
import '../domain/rule_item.dart';

class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen>
    with AutoRefreshMixin {
  // Showcase keys
  final _showcaseKeyHeader = GlobalKey();
  final _showcaseKeyRuleCard = GlobalKey();

  // Флаг чтобы showcase не запускался повторно при rebuild
  bool _showcaseStarted = false;

  @override
  void initState() {
    super.initState();
    startAutoRefresh(() {
      ref.invalidate(rulesListProvider);
    });
  }

  void _startShowcaseIfNeeded(BuildContext showcaseContext) {
    // Проверяем локальный флаг чтобы не запускать повторно при rebuild
    if (_showcaseStarted) return;
    
    final showcaseState = ref.read(showcaseProvider(ShowcasePage.rules));
    if (!showcaseState.shouldShow) return;
    
    _showcaseStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ShowCaseWidget.of(
        showcaseContext,
      ).startShowCase([
        _showcaseKeyHeader,
        _showcaseKeyRuleCard,
      ]);
    });
  }

  void _onShowcaseComplete() {
    ref.read(showcaseNotifierProvider(ShowcasePage.rules)).markAsSeen();
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(rulesListProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    Future<void> onRefresh() async {
      ref.invalidate(rulesListProvider);
      await ref.read(rulesListProvider.future);
    }

    return ShowcaseWrapper(
      onComplete: _onShowcaseComplete,
      child: Builder(
        builder: (showcaseContext) {
          // Запускаем showcase если нужно
          _startShowcaseIfNeeded(showcaseContext);

          return asyncItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) {
              final errorInfo = ErrorUtils.getErrorInfo(e);
              return EmptyState(
                icon: errorInfo.icon,
                title: errorInfo.title,
                message: errorInfo.message,
              );
            },
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.rule_folder_outlined,
                  title: tr(context, ru: 'Правила не найдены', zh: '未找到规则'),
                );
              }
              return Builder(
                builder: (ctx) => RefreshIndicator(
                  onRefresh: onRefresh,
                  color: ctx.brandPrimary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topPad * 0.7 + 6,
                      16,
                      24 + bottomPad,
                    ),
                    itemCount: items.length + 1, // +1 for header
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Showcase(
                            key: _showcaseKeyHeader,
                            title: tr(context, ru: '📋 Правила и условия', zh: '📋 规则和条款'),
                            description: tr(
                              context,
                              ru: 'Важные правила работы с компанией:\n• Условия оказания услуг\n• Права и обязанности клиентов\n• Порядок работы и процедуры\n• Правила упаковки и маркировки\n• Потяните вниз для обновления ⬇️',
                              zh: '与公司合作的重要规则：\n• 服务条款\n• 客户的权利和义务\n• 工作流程和程序\n• 包装和标记规则\n• 下拉刷新 ⬇️',
                            ),
                            targetPadding: getShowcaseTargetPadding(),
                            tooltipPosition: TooltipPosition.bottom,
                            tooltipBackgroundColor: Colors.white,
                            textColor: Colors.black87,
                            titleTextStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                            descTextStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                            onTargetClick: () {
                              if (mounted) {
                                ShowCaseWidget.of(showcaseContext).next();
                              }
                            },
                            disposeOnTap: false,
                            child: Text(
                              tr(context, ru: 'Правила оказания услуг', zh: '服务规则'),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        );
                      }
                      final item = items[i - 1];
                      if (i == 1) {
                        // Первая карточка правил - оборачиваем в Showcase
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i == items.length ? 0 : 12,
                          ),
                          child: Showcase(
                            key: _showcaseKeyRuleCard,
                            title: tr(context, ru: '📄 Карточка правила', zh: '📄 规则卡片'),
                            description: tr(
                              context,
                              ru: 'Каждое правило содержит:\n• 🔢 Номер правила в порядке важности\n• 📝 Название и краткое описание\n• 👆 Нажмите для чтения полного текста\n• Полная версия с форматированием и изображениями\n• Важно ознакомиться со всеми правилами',
                              zh: '每条规则包含：\n• 🔢 按重要性排序的规则编号\n• 📝 名称和简短描述\n• 👆 点击阅读完整文本\n• 带格式和图片的完整版本\n• 熟悉所有规则很重要',
                            ),
                            targetPadding: getShowcaseTargetPadding(),
                            tooltipPosition: TooltipPosition.bottom,
                            tooltipBackgroundColor: Colors.white,
                            textColor: Colors.black87,
                            titleTextStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                            descTextStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                            onBarrierClick: _onShowcaseComplete,
                            onToolTipClick: _onShowcaseComplete,
                            child: _RuleCard(item: item),
                          ),
                        );
                      }
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i == items.length ? 0 : 12,
                        ),
                        child: _RuleCard(item: item),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
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
                    gradient: LinearGradient(
                      colors: [context.brandPrimary, context.brandSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${item.order}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
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
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.excerpt,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 13,
                          height: 1.3,
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
                  color: Color(0xFFCCCCCC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
