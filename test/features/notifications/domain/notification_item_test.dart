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
      expect(item.route, '/tracks?trackId=58504&trackCode=TEST16041');
      expect(NotificationItem.notificationIdFromData(data), '466380');
      expect(
        NotificationItem.routeFromPushData(data),
        '/tracks?trackId=58504&trackCode=TEST16041',
      );
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

    test('keeps client code in entity routes when push data includes it', () {
      expect(
        NotificationItem.routeFromPushData({
          'type': 'track_status_changed',
          'entityId': '466380',
          'clientCode': '2A-TEST',
          'trackId': '58504',
          'trackCode': 'TEST16041',
        }),
        '/tracks?clientCode=2A-TEST&trackId=58504&trackCode=TEST16041',
      );
      expect(
        NotificationItem.routeFromPushData({
          'type': 'invoice_status_changed',
          'entityId': '466381',
          'clientCode': '2A-01',
          'invoiceId': '123',
        }),
        '/invoices?clientCode=2A-01&invoiceId=123',
      );
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

    test('keeps Garage aliases separate and opens Garage deep links', () {
      final item = NotificationItem.fromPushData({
        'type': 'garage_employee_question',
        'entityId': '3',
        'garageRequestId': '11',
        'route': '/garage/requests/11',
      });

      expect(item.type, NotificationType.garage);
      expect(item.type.displayName, 'Гараж');
      expect(item.route, '/garage/requests/11');
      expect(
        NotificationItem.routeFromPushData({
          'type': 'garage_payment_approved',
          'garageOrderId': '44',
        }),
        '/garage/orders/44',
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
