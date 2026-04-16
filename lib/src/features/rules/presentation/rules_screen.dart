import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
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

class _RulesScreenState extends ConsumerState<RulesScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _rulesListKey = GlobalKey();
  final GlobalKey _firstRuleKey = GlobalKey();


  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(rulesListProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    Future<void> onRefresh() async {
      ref.invalidate(rulesListProvider);
      await ref.read(rulesListProvider.future);
    }

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
        return TutorialScreenWrapper(
          screenKey: 'rules',
          steps: [
            TutorialStep(
              icon: Icons.rule_rounded,
              title: 'Правила оказания услуг',
              description: 'Здесь собраны все условия работы с нами: ограничения, ответственность и порядок доставки.',
              targetKey: _rulesListKey,
            ),
            TutorialStep(
              icon: Icons.open_in_new_rounded,
              title: 'Читать правило',
              description: 'Нажмите на карточку, чтобы открыть полный текст правила.',
              targetKey: _firstRuleKey,
            ),
          ],
          child: Builder(
          builder: (ctx) => Stack(
          children: [
          RefreshIndicator(
            onRefresh: onRefresh,
            color: ctx.brandPrimary,
            child: ListView.builder(
              controller: _scrollController,
              key: _rulesListKey,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                topPad * 0.7 + 16,
                16,
                24 + bottomPad,
              ),
              itemCount: items.length + 1, // +1 for header
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      tr(context, ru: 'Правила оказания услуг', zh: '服务规则'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  );
                }
                final item = items[i - 1];
                if (i == 1) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i == items.length ? 0 : 12,
                    ),
                    child: KeyedSubtree(key: _firstRuleKey, child: _RuleCard(item: item)),
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
          ScrollToTopButton(controller: _scrollController),
          ],
          ),
        ));
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
