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

    test('payment target routeId keeps Invoice and Garage ids distinct', () {
      final invoice = NotificationItem.fromPushData({
        'type': 'payment_partially_covered',
        'targetType': 'invoice',
        'targetId': '71',
        'routeId': '71',
      });
      final garage = NotificationItem.fromPushData({
        'type': 'payment_fully_covered',
        'targetType': 'garage_invoice',
        'targetId': '55',
        'routeId': '44',
      });

      expect(invoice.type, NotificationType.invoice);
      expect(invoice.route, '/invoices?invoiceId=71');
      expect(garage.type, NotificationType.garage);
      expect(garage.relatedId, '55');
      expect(garage.route, '/garage/orders/44');
      expect(
        NotificationItem.routeFromPushData({
          'type': 'payment_partially_covered',
          'target_type': 'garage_invoice',
          'target_id': '56',
          'route_id': '45',
        }),
        '/garage/orders/45',
      );
    });

    test(
      'classifies all self-buyout events before generic payment aliases',
      () {
        const types = [
          'self_buyout_verification_approved',
          'self_buyout_verification_rejected',
          'self_buyout_payment_approved',
          'self_buyout_payment_rejected',
          'self_buyout_transfer_proof_uploaded',
          'self_buyout_completed',
          'self_buyout_cancelled',
        ];

        for (final type in types) {
          final item = NotificationItem.fromPushData({'type': type});
          expect(item.type, NotificationType.selfBuyout, reason: type);
          expect(item.route, '/self-buyout', reason: type);
        }
      },
    );

    test('classifies reminders, operator status and broadcasts', () {
      final deliveryReminder = NotificationItem.fromPushData({
        'type': 'assembly_delivery_method_reminder',
        'assemblyId': '1581',
      });
      final invoiceReminder = NotificationItem.fromPushData({
        'type': 'invoice_payment_reminder',
        'invoiceId': '71',
      });
      final operatorStatus = NotificationItem.fromPushData({
        'type': 'payment_operator_status_changed',
        'route': '/self-buyout',
      });
      final broadcast = NotificationItem.fromPushData({
        'type': 'broadcast',
        'broadcastId': '9',
      });

      expect(deliveryReminder.type, NotificationType.assemblyStatus);
      expect(deliveryReminder.route, '/tracks?assemblyId=1581');
      expect(invoiceReminder.type, NotificationType.invoice);
      expect(invoiceReminder.route, '/invoices?invoiceId=71');
      expect(operatorStatus.type, NotificationType.paymentStatus);
      expect(operatorStatus.route, '/self-buyout');
      expect(broadcast.type, NotificationType.broadcast);
      expect(broadcast.route, '/');
    });

    test('keeps current and legacy Garage aliases compatible', () {
      const types = [
        'garage_payment_approved',
        'garage_clarification_required',
        'garage_employee_reply',
        'garage_request_status_changed',
        'garage_part_purchased',
        'garage_purchase_started',
        'garage_order_status',
        'garage_order_completed',
        'garage_payment_rejected',
        'garage_refund_request_approved',
        'garage_refund_request_rejected',
        'garage_refund_completed',
      ];

      for (final type in types) {
        expect(
          NotificationItem.fromPushData({'type': type}).type,
          NotificationType.garage,
          reason: type,
        );
      }
    });

    test('keeps track and assembly legacy payloads working', () {
      final trackTransfer = NotificationItem.fromPushData({
        'type': 'track_client_code_changed',
        'trackId': '10',
      });
      final addedToAssembly = NotificationItem.fromPushData({
        'type': 'track_added_to_assembly',
        'assemblyId': '20',
      });
      final unknown = NotificationItem.fromPushData({
        'type': 'future_unknown_event',
      });

      expect(trackTransfer.type, NotificationType.trackStatus);
      expect(trackTransfer.route, '/tracks?trackId=10');
      expect(addedToAssembly.type, NotificationType.assemblyStatus);
      expect(addedToAssembly.route, '/tracks?assemblyId=20');
      expect(unknown.type, NotificationType.trackStatus);
      expect(unknown.route, '/tracks');
    });

    test('unknown payment target fails closed to a list route', () {
      expect(
        NotificationItem.routeFromPushData({
          'type': 'payment_partially_covered',
          'targetType': 'future_target',
          'targetId': '99',
        }),
        '/invoices',
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
