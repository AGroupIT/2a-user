import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/services/update_gate_provider.dart';
import 'package:twoalogisticcabineuser/src/core/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('показывает необязательное обновление как banner state', () async {
    const update = UpdateInfo(
      latestVersion: '1.2.26+57',
      minVersion: '1.0.0',
      downloadUrl: 'https://example.test/user.apk',
      storeUrl: '',
      rustoreUrl: '',
      size: 100,
      sha256: '',
      changelog: 'Исправления',
      isForced: false,
    );
    final container = ProviderContainer(
      overrides: [
        appUpdateCheckerProvider.overrideWithValue(() async => update),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appUpdateGateProvider.notifier).check(reason: 'test');

    final state = container.read(appUpdateGateProvider);
    expect(state.phase, AppUpdateGatePhase.optional);
    expect(state.update, same(update));
  });

  test(
    '426 всегда переводит приложение в required и обычная проверка не снимает блок',
    () async {
      final container = ProviderContainer(
        overrides: [
          appUpdateCheckerProvider.overrideWithValue(() async => null),
        ],
      );
      addTearDown(container.dispose);

      container.read(appUpdateGateProvider.notifier).requireFromServer({
        'code': 'APP_UPDATE_REQUIRED',
        'update': {
          'latestVersion': '1.2.26+57',
          'minVersion': '1.2.25+56',
          'downloadUrl': 'https://example.test/user.apk',
          'changelog': 'Обязательное обновление',
        },
      });

      expect(
        container.read(appUpdateGateProvider).phase,
        AppUpdateGatePhase.required,
      );
      expect(
        container.read(appUpdateGateProvider).update?.minVersion,
        '1.2.25+56',
      );
      expect(
        container.read(appUpdateGateProvider).update?.rustoreUrl,
        UpdateService.defaultRustoreUrl,
      );

      await container
          .read(appUpdateGateProvider.notifier)
          .check(reason: 'resume');
      expect(
        container.read(appUpdateGateProvider).phase,
        AppUpdateGatePhase.required,
      );
    },
  );

  test('закрытие optional banner сохраняет cooldown', () async {
    const update = UpdateInfo(
      latestVersion: '1.2.26+57',
      minVersion: '1.0.0',
      downloadUrl: 'https://example.test/user.apk',
      storeUrl: '',
      rustoreUrl: '',
      size: 0,
      sha256: '',
      changelog: '',
      isForced: false,
    );
    final container = ProviderContainer(
      overrides: [
        appUpdateCheckerProvider.overrideWithValue(() async => update),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appUpdateGateProvider.notifier).check(reason: 'test');
    await container.read(appUpdateGateProvider.notifier).dismissOptional();
    await container
        .read(appUpdateGateProvider.notifier)
        .check(reason: 'resume');

    expect(
      container.read(appUpdateGateProvider).phase,
      AppUpdateGatePhase.idle,
    );
  });
}
