import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_layout.dart';
import '../data/sp_organizer_provider.dart';
import 'sp_finance_ui.dart';
import 'sp_organizer_navigation.dart';
import 'sp_v2_help_sheet.dart';

class SpOrganizerShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const SpOrganizerShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref
        .watch(spOrganizerCapabilitiesProvider)
        .asData
        ?.value;
    final selected = SpOrganizerSection.values[navigationShell.currentIndex];
    final topPadding = AppLayout.topBarTotalHeight(context) * 0.7 + 16;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
          child: Column(
            children: [
              SpPageHeader(
                title: 'Совместные покупки',
                trailing: SpV2HelpButton(
                  onTap: () => showSpV2HelpSheet(context),
                ),
              ),
              if (capabilities?.hasOrganizerTools == true) ...[
                const SizedBox(height: 12),
                SpOrganizerNavigation(
                  capabilities: capabilities!,
                  selected: selected,
                  onSelected: _selectSection,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(child: navigationShell),
      ],
    );
  }

  void _selectSection(SpOrganizerSection section) {
    final index = section.index;
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
