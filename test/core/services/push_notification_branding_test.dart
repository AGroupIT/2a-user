import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/branding/company_branding_provider.dart';
import 'package:twoalogisticcabineuser/src/core/services/push_notification_service.dart';

class _PushService extends Mock implements PushNotificationService {}

class _Name extends Notifier<String> {
  @override
  String build() => 'TeamTime';
  void change(String name) => state = name;
}

final _nameProvider = NotifierProvider<_Name, String>(_Name.new);

void main() {
  test('channel descriptions use agent name and preserve channel settings', () {
    final channels = companyNotificationChannels('IOP Cargo');
    expect(channels.map((c) => c.id), ['fcm_channel', 'fcm_channel_silent']);
    expect(channels.map((c) => c.description), [
      'Важные уведомления IOP Cargo',
      'Уведомления IOP Cargo без звука',
    ]);
    expect(channels.map((c) => c.playSound), [true, false]);
  });

  test(
    'push branding follows company provider when the agent changes',
    () async {
      final service = _PushService();
      when(() => service.updateCompanyName(any())).thenAnswer((_) async {});
      final container = ProviderContainer(
        overrides: [
          pushNotificationServiceProvider.overrideWithValue(service),
          companyNameProvider.overrideWith((ref) => ref.watch(_nameProvider)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        pushNotificationBrandingProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      verify(() => service.updateCompanyName('TeamTime')).called(1);
      container.read(_nameProvider.notifier).change('IOP Cargo');
      await container.pump();
      verify(() => service.updateCompanyName('IOP Cargo')).called(1);
      container.read(_nameProvider.notifier).change(fallbackCompanyName);
      await container.pump();
      verify(() => service.updateCompanyName(fallbackCompanyName)).called(1);
    },
  );
}
