import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../data/fake_rules_repository.dart';
import '../domain/rule_item.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(rulesListProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить правила',
        message: e.toString(),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.rule_folder_outlined,
            title: 'Правила не найдены',
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, 24 + bottomPad),
          itemCount: items.length + 1, // +1 for header
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  'Правила оказания услуг',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              );
            }
            final item = items[i - 1];
            return Padding(
              padding: EdgeInsets.only(bottom: i == items.length ? 0 : 12),
              child: _RuleCard(item: item),
            );
          },
        );
      },
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
