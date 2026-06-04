import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';

import 'more_sheet.dart';

class MoreButton extends StatelessWidget {
  const MoreButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Меню',
      icon: const Icon(Icons.more_horiz_rounded),
      onPressed: () => showBlurredModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.22),
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const MoreSheet(),
      ),
    );
  }
}
