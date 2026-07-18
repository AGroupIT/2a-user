import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/registration_provider.dart';

void main() {
  test(
    'регистрация передаёт partnerLinkToken и не требует кода агента',
    () async {
      const token =
          'abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ-1234';
      final api = _RegistrationApiClient();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(registrationProvider.notifier)
          .register(
            fullName: 'Клиент По Ссылке',
            phone: '+7 999 111-00-01',
            email: 'CLIENT@EXAMPLE.TEST',
            password: 'secure-password',
            confirmPassword: 'secure-password',
            phoneVerificationToken: 'verified-phone-token',
            partnerLinkToken: token,
          );

      expect(success, isFalse);
      expect(api.requestPath, '/register');
      expect(api.requestData?['partnerLinkToken'], token);
      expect(api.requestData?.containsKey('agentCode'), isFalse);
      expect(api.requestData?['email'], 'client@example.test');
    },
  );
}

class _RegistrationApiClient extends ApiClient {
  String? requestPath;
  Map<String, dynamic>? requestData;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requestPath = path;
    requestData = Map<String, dynamic>.from(data as Map);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 400,
      data: {'error': 'Тестовый ответ без создания аккаунта'} as T,
    );
  }
}
