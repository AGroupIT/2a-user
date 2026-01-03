import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/glass_surface.dart';
import '../application/client_codes_controller.dart';
import 'client_switcher_sheet.dart';

class ClientSwitcherButton extends ConsumerWidget {
  const ClientSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientCodesControllerProvider);

    final label = state.when(
      data: (s) => (s.activeCode ?? 'Код клиента'),
      loading: () => '…',
      error: (_, _) => 'Код клиента',
    );

    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        barrierColor: Colors.black.withValues(alpha: 0.22),
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const ClientSwitcherSheet(),
      ),
      borderRadius: BorderRadius.circular(999),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(999),
        blur: 40,
        useLiquidEffect: true,
        saturation: 1.7,
        tintColor: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.50),
          width: 1.0,
        ),
        addHighlights: false,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        noiseOpacity: 0.0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
