import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/services/push_notification_service.dart';

class _Messaging extends Mock implements FirebaseMessaging {}

class _Settings extends Mock implements NotificationSettings {}

void main() {
  tearDown(() => PushNotificationService.setMessagingForTesting(null));

  testWidgets(
    'Web support timeout is transient and a later check can succeed',
    (tester) async {
      final messaging = _Messaging();
      final pending = Completer<bool>();
      when(() => messaging.isSupported()).thenAnswer((_) => pending.future);
      final check = expectLater(
        checkWebPushSupport(messaging),
        throwsA(isA<TimeoutException>()),
      );
      await tester.pump(const Duration(seconds: 3));
      await check;
      when(() => messaging.isSupported()).thenAnswer((_) async => true);
      expect(await checkWebPushSupport(messaging), true);
      pending.complete(false);
      await tester.pump();
    },
  );

  testWidgets(
    'initialization failures keep one backoff loop despite reentrant scheduling',
    (tester) async {
      PushNotificationService.setMessagingForTesting(null);
      PushNotificationService.setActiveClient(1);
      var attempts = 0;
      late Future<void> Function() retry;
      retry = () async {
        attempts++;
        if (attempts == 1) {
          unawaited(
            PushNotificationService.runInitializationRetryForTesting(retry),
          );
          throw StateError('transient initialization failure');
        }
        PushNotificationService.setMessagingForTesting(_Messaging());
      };
      final loop = PushNotificationService.runInitializationRetryForTesting(
        retry,
      );
      await PushNotificationService.runInitializationRetryForTesting(retry);
      await tester.pump(const Duration(seconds: 30));
      expect(attempts, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(attempts, 1);
      await tester.pump(const Duration(seconds: 30));
      await loop;
      expect(attempts, 2);
    },
  );

  testWidgets('iOS waits for APNs token before requesting an FCM address', (
    tester,
  ) async {
    final messaging = _Messaging();
    when(() => messaging.getAPNSToken()).thenAnswer((_) async => null);
    when(() => messaging.getToken()).thenAnswer((_) async => 'fcm-after-apns');
    PushNotificationService.setMessagingForTesting(messaging, isIOS: true);
    expect(await PushNotificationService.getFCMToken(), isNull);
    verifyNever(() => messaging.getToken());
    when(() => messaging.getAPNSToken()).thenAnswer((_) async => 'apns-ready');
    expect(await PushNotificationService.getFCMToken(), 'fcm-after-apns');
  });

  testWidgets(
    'Web background registration never requests permission automatically',
    (tester) async {
      final messaging = _Messaging();
      final settings = _Settings();
      when(
        () => settings.authorizationStatus,
      ).thenReturn(AuthorizationStatus.denied);
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => settings);
      PushNotificationService.setMessagingForTesting(messaging, isWeb: true);
      expect(await PushNotificationService.getFCMToken(), isNull);
      verifyNever(() => messaging.getToken(vapidKey: any(named: 'vapidKey')));
      when(
        () => settings.authorizationStatus,
      ).thenReturn(AuthorizationStatus.authorized);
      when(
        () => messaging.getToken(vapidKey: any(named: 'vapidKey')),
      ).thenAnswer((_) async => 'web-token');
      expect(await PushNotificationService.getFCMToken(), 'web-token');
    },
  );

  testWidgets(
    'hung token request returns null and a subsequent attempt recovers',
    (tester) async {
      final messaging = _Messaging();
      final stalled = Completer<String?>();
      when(() => messaging.getToken()).thenAnswer((_) => stalled.future);
      PushNotificationService.setMessagingForTesting(messaging);

      var completed = false;
      String? result;
      final request = PushNotificationService.getFCMToken().then((token) {
        completed = true;
        result = token;
      });
      await tester.pump(const Duration(seconds: 9));
      expect(completed, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(completed, isTrue);
      expect(result, isNull);
      await request;

      when(() => messaging.getToken()).thenAnswer((_) async => 'new-token');
      expect(await PushNotificationService.getFCMToken(), 'new-token');
      verify(() => messaging.getToken()).called(2);

      // An SDK operation can still finish after timeout; it must not complete the
      // expired call again or replace its failure result.
      stalled.complete('late-token');
      await tester.pump();
      expect(result, isNull);
    },
  );

  testWidgets(
    'SDK failure stays nullable and does not prevent another request',
    (tester) async {
      final messaging = _Messaging();
      when(
        () => messaging.getToken(),
      ).thenAnswer((_) async => throw StateError('offline'));
      PushNotificationService.setMessagingForTesting(messaging);
      expect(await PushNotificationService.getFCMToken(), isNull);
      when(
        () => messaging.getToken(),
      ).thenAnswer((_) async => 'recovered-token');
      expect(await PushNotificationService.getFCMToken(), 'recovered-token');
    },
  );
}
