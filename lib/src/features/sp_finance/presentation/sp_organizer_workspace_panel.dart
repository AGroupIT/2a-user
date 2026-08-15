import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sp_organizer_provider.dart';
import 'sp_organizer_calculation_panel.dart';
import 'sp_organizer_fulfillment_panel.dart';
import 'sp_organizer_participants_panel.dart';

class SpOrganizerWorkspacePanel extends ConsumerWidget {
  final int purchaseId;
  final bool showParticipants;
  final bool showCalculation;
  final bool showFulfillment;

  const SpOrganizerWorkspacePanel({
    super.key,
    required this.purchaseId,
    this.showParticipants = true,
    this.showCalculation = true,
    this.showFulfillment = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref
        .watch(spOrganizerCapabilitiesProvider)
        .asData
        ?.value;
    final canShowParticipants =
        showParticipants && capabilities?.participants == true;
    final canShowCalculation =
        showCalculation && capabilities?.calculationProfiles == true;
    final canShowFulfillment =
        showFulfillment && capabilities?.fulfillmentOverview == true;
    final panels = <Widget>[
      if (canShowParticipants)
        SpOrganizerParticipantsPanel(purchaseId: purchaseId),
      if (canShowCalculation)
        SpOrganizerCalculationPanel(purchaseId: purchaseId),
      if (canShowFulfillment)
        SpOrganizerFulfillmentPanel(purchaseId: purchaseId),
    ];
    if (panels.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var index = 0; index < panels.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          panels[index],
        ],
      ],
    );
  }
}
