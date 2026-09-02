import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'device preferences keep legacy defaults and persist server values',
    () async {
      SharedPreferences.setMockInitialValues({});

      expect(PushNotificationService.devicePreferences, (
        notificationsEnabled: true,
        soundEnabled: true,
        badgeEnabled: true,
      ));

      await PushNotificationService.applyDevicePreferences();
      expect(PushNotificationService.devicePreferences.soundEnabled, isTrue);

      await PushNotificationService.applyDevicePreferences(
        notificationsEnabled: true,
        soundEnabled: false,
        badgeEnabled: false,
      );

      expect(PushNotificationService.devicePreferences, (
        notificationsEnabled: true,
        soundEnabled: false,
        badgeEnabled: false,
      ));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('push_notifications_enabled'), isTrue);
      expect(prefs.getBool('push_sound_enabled'), isFalse);
      expect(prefs.getBool('push_badge_enabled'), isFalse);

      expect(
        localNotificationChannelId('chat_channel', soundEnabled: true),
        'chat_channel_sound',
      );
      expect(
        localNotificationChannelId('chat_channel', soundEnabled: false),
        'chat_channel_silent',
      );
    },
  );
}
