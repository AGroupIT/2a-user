import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/services/chat_presence_service.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'logout finishes when remote device deactivation never responds',
    () async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'user_email': 'client@example.test',
        'user_domain': '',
        'client_id': 101,
        'client_name': 'Тестовый клиент',
        'client_data': jsonEncode({
          'id': 101,
          'fullName': 'Тестовый клиент',
          'codes': <Map<String, dynamic>>[],
        }),
        'device_id': 'device-test-101',
      });

      final apiClient = _HangingDeviceCleanupApiClient();
      final presenceService = _RecordingChatPresenceService(apiClient);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          chatPresenceServiceProvider.overrideWithValue(presenceService),
          logoutDeviceCleanupTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
        ],
      );
      addTearDown(container.dispose);

      final restored = await _waitForAuthLoaded(container);
      expect(restored.isLoggedIn, isTrue);

      final stopwatch = Stopwatch()..start();
      await container
          .read(authProvider.notifier)
          .logout()
          .timeout(const Duration(seconds: 1));
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(presenceService.wasStoppedForLogout, isTrue);
      expect(apiClient.clearTokenCalled, isTrue);
      expect(apiClient.deletedPath, '/devices');
      expect(apiClient.deletedData, {'deviceId': 'device-test-101'});
      expect(container.read(authProvider).isLoggedIn, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_logged_in'), isNull);
    },
  );
}

Future<AuthState> _waitForAuthLoaded(ProviderContainer container) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 1)) {
    final auth = container.read(authProvider);
    if (!auth.isLoading) return auth;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(authProvider);
}

class _HangingDeviceCleanupApiClient extends ApiClient {
  bool clearTokenCalled = false;
  String? deletedPath;
  dynamic deletedData;

  @override
  bool get hasToken => true;

  @override
  Future<bool> hasTokenAsync() async => true;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => Completer<Response<T>>().future;

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    deletedPath = path;
    deletedData = data;
    return Completer<Response<T>>().future;
  }

  @override
  Future<void> clearToken() async {
    clearTokenCalled = true;
  }
}

class _RecordingChatPresenceService extends ChatPresenceService {
  _RecordingChatPresenceService(super.apiClient);

  bool wasStoppedForLogout = false;

  @override
  void stopForLogout() {
    wasStoppedForLogout = true;
    super.stopForLogout();
  }
}
