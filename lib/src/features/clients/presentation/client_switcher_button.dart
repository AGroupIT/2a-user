import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/pixso_top_menu_surface.dart';
import '../application/client_codes_controller.dart';
import 'client_switcher_sheet.dart';

class ClientSwitcherButton extends ConsumerWidget {
  const ClientSwitcherButton({super.key});

  static const _contentColor = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientCodesControllerProvider);

    final label = state.when(
      data: (s) => (s.activeCode ?? 'Код клиента'),
      loading: () => '…',
      error: (_, _) => 'Код клиента',
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => showBlurredModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.22),
          useSafeArea: true,
          isScrollControlled: true,
          builder: (_) => const ClientSwitcherSheet(),
        ),
        borderRadius: BorderRadius.circular(18),
        child: PixsoTopMenuSurface(
          minWidth: 108,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.brandPrimary,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.32),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, maxWidth: 92),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    color: _contentColor,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 18 / 15,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 18,
                child: Icon(
                  CupertinoIcons.chevron_down,
                  color: _contentColor,
                  size: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
