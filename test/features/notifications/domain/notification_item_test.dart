import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/notifications/domain/notification_item.dart';

void main() {
  group('NotificationItem push tap routing', () {
    test('builds track route and notification id from FCM data', () {
      final data = {
        'type': 'track_status_changed',
        'entityId': '466380',
        'trackId': '58504',
        'trackCode': 'TEST16041',
        'status': 'in_warehouse',
      };

      final item = NotificationItem.fromPushData(
        data,
        title: 'Статус трека изменен',
        body: 'TEST16041',
      );

      expect(item.id, '466380');
      expect(item.type, NotificationType.trackStatus);
      expect(item.route, '/tracks?trackId=58504');
      expect(NotificationItem.notificationIdFromData(data), '466380');
      expect(NotificationItem.routeFromPushData(data), '/tracks?trackId=58504');
    });

    test('builds assembly route from assembly notification data', () {
      final data = {
        'type': 'assembly_status_changed',
        'entityId': '466381',
        'assemblyId': '1581',
      };

      final item = NotificationItem.fromPushData(data);

      expect(item.id, '466381');
      expect(item.type, NotificationType.assemblyStatus);
      expect(item.route, '/tracks?assemblyId=1581');
    });

    test('routes support and payment chat notifications to matching chats', () {
      expect(
        NotificationItem.routeFromPushData({
          'type': 'support_message',
          'entityId': '1',
        }),
        '/support',
      );
      expect(
        NotificationItem.routeFromPushData({
          'type': 'payment_chat_message',
          'entityId': '2',
        }),
        '/payment-chat',
      );
    });

    test('encodes and decodes local notification tap payload', () {
      final payload = NotificationItem.tapPayloadFromPushData({
        'type': 'track_status_changed',
        'entityId': '466380',
        'trackId': '58504',
      });

      final target = NotificationItem.tapTargetFromPayload(payload);

      expect(target.notificationId, '466380');
      expect(target.route, '/tracks?trackId=58504');
    });
  });
}
