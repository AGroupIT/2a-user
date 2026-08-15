import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/client_partner_invite_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/partner_link_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/registration_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'регистрация передаёт подписанное приглашение и ключ идемпотентности',
    () async {
      const token =
          '123e4567-e89b-12d3-a456-426614174000.1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      final api = _RegistrationApiClient();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(registrationProvider.notifier)
          .register(
            fullName: 'Новый Клиент',
            phone: '+7 999 111-00-02',
            email: 'NEW@EXAMPLE.TEST',
            password: 'secure-password',
            confirmPassword: 'secure-password',
            phoneVerificationToken: 'verified-phone-token',
            agentCode: 'MUST-NOT-LEAK',
            referralCode: 'MUST-NOT-LEAK',
            partnerLinkToken: 'MUST-NOT-LEAK',
            clientPartnerInviteToken: token,
            registrationIdempotencyKey: 'registration-attempt-123',
          );

      expect(success, isFalse);
      expect(api.requestData?['clientPartnerInviteToken'], token);
      expect(
        api.requestData?['registrationIdempotencyKey'],
        'registration-attempt-123',
      );
      expect(api.requestData?.containsKey('agentCode'), isFalse);
      expect(api.requestData?.containsKey('referralCode'), isFalse);
      expect(api.requestData?.containsKey('partnerLinkToken'), isFalse);
    },
  );

  test('201 очищает приглашения и передаёт данные в автологин', () async {
    const token =
        '123e4567-e89b-12d3-a456-426614174000.1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    final api = _RegistrationApiClient(success: true);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(_RecordingAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final inviteNotifier = container.read(clientPartnerInviteProvider.notifier);
    final partnerLinkNotifier = container.read(partnerLinkProvider.notifier);
    expect(await inviteNotifier.captureToken(token), isTrue);
    expect(await partnerLinkNotifier.captureToken('A' * 40), isTrue);
    final idempotencyKey = container
        .read(clientPartnerInviteProvider)
        .registrationIdempotencyKey;

    final success = await container
        .read(registrationProvider.notifier)
        .register(
          fullName: 'Новый Клиент',
          phone: '+7 999 111-00-02',
          email: 'NEW@EXAMPLE.TEST',
          password: 'secure-password',
          confirmPassword: 'secure-password',
          phoneVerificationToken: 'verified-phone-token',
          agentCode: 'OVERRIDE',
          referralCode: 'OVERRIDE',
          partnerLinkToken: 'B' * 40,
          clientPartnerInviteToken: token,
          registrationIdempotencyKey: idempotencyKey,
        );

    expect(success, isTrue);
    expect(api.requestData?.containsKey('agentCode'), isFalse);
    expect(api.requestData?.containsKey('referralCode'), isFalse);
    expect(api.requestData?.containsKey('partnerLinkToken'), isFalse);
    expect(
      container.read(clientPartnerInviteProvider).phase,
      ClientPartnerInvitePhase.idle,
    );
    expect(container.read(partnerLinkProvider).phase, PartnerLinkPhase.idle);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_client_partner_invite_v1'), isNull);
    expect(
      prefs.getString('pending_client_partner_registration_key_v1'),
      isNull,
    );
    expect(prefs.getString('pending_partner_link_token_v1'), isNull);
    final auth =
        container.read(authProvider.notifier) as _RecordingAuthNotifier;
    expect(auth.receivedToken, 'registered-token');
    expect(auth.receivedUser?['id'], 42);
    expect(container.read(authProvider).isLoggedIn, isTrue);
  });

  test('201 с ошибкой автологина очищает invite и возвращает false', () async {
    const token =
        '123e4567-e89b-12d3-a456-426614174000.1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    final api = _RegistrationApiClient(success: true);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(_FailingAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final inviteNotifier = container.read(clientPartnerInviteProvider.notifier);
    expect(await inviteNotifier.captureToken(token), isTrue);

    final success = await container
        .read(registrationProvider.notifier)
        .register(
          fullName: 'Новый Клиент',
          phone: '+7 999 111-00-02',
          email: 'NEW@EXAMPLE.TEST',
          password: 'secure-password',
          confirmPassword: 'secure-password',
          phoneVerificationToken: 'verified-phone-token',
          clientPartnerInviteToken: token,
          registrationIdempotencyKey: container
              .read(clientPartnerInviteProvider)
              .registrationIdempotencyKey,
        );

    expect(success, isFalse);
    expect(container.read(authProvider).isLoggedIn, isFalse);
    expect(
      container.read(registrationProvider).error,
      'Аккаунт создан, но не удалось войти автоматически. Войдите вручную.',
    );
    expect(
      container.read(clientPartnerInviteProvider).phase,
      ClientPartnerInvitePhase.idle,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_client_partner_invite_v1'), isNull);
    expect(
      prefs.getString('pending_client_partner_registration_key_v1'),
      isNull,
    );
  });
}

class _RegistrationApiClient extends ApiClient {
  _RegistrationApiClient({this.success = false});

  final bool success;
  Map<String, dynamic>? requestData;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requestData = Map<String, dynamic>.from(data as Map);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: success ? 201 : 400,
      data:
          (success
                  ? {
                      'token': 'registered-token',
                      'user': {
                        'id': 42,
                        'email': 'new@example.test',
                        'fullName': 'Новый Клиент',
                      },
                    }
                  : {'error': 'Тестовый ответ'})
              as T,
    );
  }
}

class _RecordingAuthNotifier extends AuthNotifier {
  String? receivedToken;
  Map<String, dynamic>? receivedUser;

  @override
  AuthState build() => const AuthState(isLoggedIn: false, isLoading: false);

  @override
  Future<bool> loginWithData({
    required String token,
    required Map<String, dynamic> userData,
  }) async {
    receivedToken = token;
    receivedUser = userData;
    state = AuthState(
      isLoggedIn: true,
      isLoading: false,
      clientId: userData['id'] as int?,
      clientData: userData,
    );
    return true;
  }
}

class _FailingAuthNotifier extends _RecordingAuthNotifier {
  @override
  Future<bool> loginWithData({
    required String token,
    required Map<String, dynamic> userData,
  }) async {
    receivedToken = token;
    receivedUser = userData;
    return false;
  }
}
