import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/push_notification_service.dart';
import '../../clients/application/client_codes_controller.dart';
import '../application/notifications_controller.dart';
import 'notifications_sheet.dart';

class NotificationsBellButton extends ConsumerWidget {
  const NotificationsBellButton({super.key});

  static const _contentColor = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const Tooltip(
        message: 'Уведомления',
        child: SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: Icon(CupertinoIcons.bell, size: 19.6, color: _contentColor),
          ),
        ),
      );
    }

    // PU-M13 follow-up: badge берёт count из глобального
    // unreadNotificationsCountProvider, в который контроллер пишет backend
    // unreadCount по ВСЕМ уведомлениям (а не только по первой странице).
    // Контроллер всё ещё watch'им — иначе он autoDispose, и без него никто
    // не пишет в unreadNotificationsCountProvider.
    ref.watch(notificationsControllerProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Tooltip(
      message: 'Уведомления',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showModalBottomSheet<void>(
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
                context.push(route);
              },
              controller: controller,
            ),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: Icon(
                  CupertinoIcons.bell,
                  size: 19.6,
                  color: _contentColor,
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -3,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
