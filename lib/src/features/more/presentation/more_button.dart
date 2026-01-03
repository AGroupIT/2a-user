import 'package:flutter/material.dart';

import 'more_sheet.dart';

class MoreButton extends StatelessWidget {
  const MoreButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Меню',
      icon: const Icon(Icons.more_horiz_rounded),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        barrierColor: Colors.black.withValues(alpha: 0.22),
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const MoreSheet(),
      ),
    );
  }
}
