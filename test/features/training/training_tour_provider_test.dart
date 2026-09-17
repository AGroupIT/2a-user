import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/persistence/shared_preferences_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/training/application/training_tour_provider.dart';

const _initialAuth = AuthState(
  isLoggedIn: true,
  isLoading: false,
  userDomain: 'company-a',
  clientId: 17,
  clientName: 'Before refresh',
);
const _steps = ['cabinet', 'warehouse', 'tracks'];

class _TestAuth extends AuthNotifier {
  @override
  AuthState build() => _initialAuth;

  void replace(AuthState next) => state = next;
}

class _TestCode extends Notifier<String?> {
  @override
  String? build() => 'CODE-A';

  void replace(String? next) => state = next;
}

final _codeProvider = NotifierProvider<_TestCode, String?>(_TestCode.new);

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_TestAuth.new),
      activeClientCodeProvider.overrideWith((ref) => ref.watch(_codeProvider)),
    ],
  );
  container.listen(trainingTourControllerProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'profile name refresh keeps the active controller and current step',
    () async {
      final container = await _container();
      final original = container.read(trainingTourControllerProvider)!;
      original.start(_steps);
      original.next();
      await original.settled;

      (container.read(authProvider.notifier) as _TestAuth).replace(
        _initialAuth.copyWith(clientName: 'After refresh'),
      );
      final refreshed = container.read(trainingTourControllerProvider)!;

      expect(identical(refreshed, original), isTrue);
      expect(refreshed.active, isTrue);
      expect(refreshed.currentId, 'warehouse');
      expect(refreshed.viewed, {'cabinet'});
    },
  );

  for (final changedScope in ['client', 'domain', 'code']) {
    test(
      '$changedScope switch creates an inactive tour with isolated resume',
      () async {
        final container = await _container();
        final auth = container.read(authProvider.notifier) as _TestAuth;
        final code = container.read(_codeProvider.notifier);
        final original = container.read(trainingTourControllerProvider)!;
        original.start(_steps);
        original.next();
        // Switch while the previous account's serialized save may still be pending.
        switch (changedScope) {
          case 'client':
            auth.replace(_initialAuth.copyWith(clientId: 18));
          case 'domain':
            auth.replace(_initialAuth.copyWith(userDomain: 'company-b'));
          case 'code':
            code.replace('CODE-B');
        }
        final other = container.read(trainingTourControllerProvider)!;
        expect(identical(other, original), isFalse);
        expect(other.scopeKey, isNot(original.scopeKey));
        expect(other.active, isFalse);
        expect(other.currentId, isNull);
        expect(other.resumeId, isNull);
        expect(other.viewed, isEmpty);

        other.start(_steps);
        expect(other.currentId, 'cabinet');
        await Future.wait([original.settled, other.settled]);
        auth.replace(_initialAuth);
        code.replace('CODE-A');
        final restored = container.read(trainingTourControllerProvider)!;
        expect(identical(restored, original), isFalse);
        expect(restored.active, isFalse);
        expect(restored.resumeId, 'warehouse');
        restored.start(_steps);
        expect(restored.currentId, 'warehouse');
        expect(restored.viewed, {'cabinet'});
        await restored.settled;
      },
    );
  }

  test(
    'logout removes the controller and login requires explicit start',
    () async {
      final container = await _container();
      final auth = container.read(authProvider.notifier) as _TestAuth;
      final original = container.read(trainingTourControllerProvider)!;
      original.start(_steps);
      original.next();
      await original.settled;

      auth.replace(const AuthState(isLoggedIn: false, isLoading: false));
      expect(container.read(trainingTourControllerProvider), isNull);
      auth.replace(_initialAuth.copyWith(clientId: 99));
      final other = container.read(trainingTourControllerProvider)!;
      expect(other.active, isFalse);
      expect(other.resumeId, isNull);
      expect(other.viewed, isEmpty);

      auth.replace(_initialAuth);
      final relogged = container.read(trainingTourControllerProvider)!;
      expect(identical(relogged, original), isFalse);
      expect(relogged.active, isFalse);
      expect(relogged.currentId, isNull);
      expect(relogged.resumeId, 'warehouse');
      relogged.start(_steps);
      expect(relogged.currentId, 'warehouse');
      await relogged.settled;
    },
  );
}
