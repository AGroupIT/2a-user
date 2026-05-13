import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.white,
          barrierColor: Colors.black.withValues(alpha: 0.22),
          useSafeArea: true,
          isScrollControlled: true,
          builder: (_) => const ClientSwitcherSheet(),
        ),
        borderRadius: BorderRadius.circular(10),
        child: PixsoTopMenuSurface(
          minWidth: 92,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 51),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    color: _contentColor,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    height: 18 / 16,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const SizedBox(
                width: 11,
                height: 16,
                child: Icon(
                  CupertinoIcons.chevron_down,
                  color: _contentColor,
                  size: 13.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
