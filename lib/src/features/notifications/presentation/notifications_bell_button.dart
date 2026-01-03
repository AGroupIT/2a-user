import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../clients/application/client_codes_controller.dart';
import '../application/notifications_controller.dart';
import 'notifications_sheet.dart';

class NotificationsBellButton extends ConsumerWidget {
  const NotificationsBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return IconButton(
        tooltip: 'Уведомления',
        onPressed: null,
        icon: const Icon(Icons.notifications_none_rounded),
      );
    }

    final itemsAsync = ref.watch(notificationsControllerProvider(clientCode));
    final unreadCount = itemsAsync.value?.where((n) => !n.isRead).length ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Уведомления',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.white,
            barrierColor: Colors.black.withValues(alpha: 0.22),
            useSafeArea: true,
            isScrollControlled: true,
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, controller) => NotificationsSheet(
                clientCode: clientCode,
                onNavigate: (route) {
                  Navigator.of(context).pop();
                  context.go(route);
                },
                controller: controller,
              ),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
