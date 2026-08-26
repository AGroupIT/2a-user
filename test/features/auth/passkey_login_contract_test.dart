import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys/types.dart';

void main() {
  test(
    'passkey package accepts discoverable options without allowCredentials',
    () {
      final request = AuthenticateRequestType.fromJson({
        'challenge': 'test-challenge',
        'rpId': 'prod-api.cp.2a-logistic.com',
        'timeout': 60000,
        'userVerification': 'required',
      });

      expect(request.allowCredentials, isNull);
      expect(request.relyingPartyId, 'prod-api.cp.2a-logistic.com');
    },
  );

  test('native passkey login does not require a typed identifier', () {
    final service = File(
      'lib/src/features/auth/data/passkey_auth_service.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/src/features/auth/presentation/login_screen.dart',
    ).readAsStringSync();

    expect(service, contains('authenticate({String? login})'));
    expect(
      service,
      contains("if (normalizedLogin != null && normalizedLogin.isNotEmpty)"),
    );
    expect(screen, contains('passkeyService.authenticate();'));
    expect(screen, isNot(contains("_showError('Введите email или телефон')")));
  });

  test('passkey actions are gated by device capability', () {
    final service = File(
      'lib/src/features/auth/data/passkey_auth_service.dart',
    ).readAsStringSync();
    final login = File(
      'lib/src/features/auth/presentation/login_screen.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/src/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();

    expect(
      service,
      contains('availability.isUserVerifyingPlatformAuthenticatorAvailable'),
    );
    expect(service, contains('availability.hasBiometrics'));
    expect(login, contains('_passkeyAvailabilityChecked &&'));
    expect(login, contains('_passkeyAvailable'));
    expect(profile, contains('if (_passkeyAvailable) ...['));
    expect(profile, contains('unawaited(_loadPasskeyState())'));
  });

  test('server status remains source of truth for enrollment prompt', () {
    final screen = File(
      'lib/src/features/auth/presentation/login_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('getCurrentUserPasskeyStatus()'));
    expect(screen, contains('serverStatus.enabled'));
    expect(screen, isNot(contains('passkey_registered_v1_')));
  });
}
