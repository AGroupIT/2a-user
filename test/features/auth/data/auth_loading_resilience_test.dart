import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_colors.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/profile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth loading resilience', () {
    test(
      'restores logged-in state even when background auth refresh hangs',
      () async {
        SharedPreferences.setMockInitialValues({
          'is_logged_in': true,
          'user_email': 'client@example.com',
          'user_domain': '2a-logistic.ru',
          'auth_token': 'mock-token',
          'client_id': 101,
          'client_name': 'Тестовый Клиент',
          'client_data': jsonEncode({
            'id': 101,
            'fullName': 'Тестовый Клиент',
            'email': 'client@example.com',
            'agent': {'id': 1, 'domain': '2a-logistic.ru'},
            'codes': [
              {'id': 501, 'code': '2A-TEST'},
            ],
          }),
        });

        final apiClient = _HangingAuthRefreshApiClient();
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(apiClient)],
        );
        addTearDown(container.dispose);

        expect(container.read(authProvider).isLoading, isTrue);

        final restored = await _waitForAuthLoaded(container);

        expect(restored.isLoading, isFalse);
        expect(restored.isLoggedIn, isTrue);
        expect(restored.userEmail, 'client@example.com');
        expect(restored.clientName, 'Тестовый Клиент');

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(apiClient.requestedPaths, contains('/auth/me'));
      },
    );

    test('uses cached profile immediately when profile API hangs', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'mock-token',
        'client_profile_cache_v1': jsonEncode(_profileData()),
      });

      final apiClient = _HangingAuthRefreshApiClient();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);

      final profile = await container.read(clientProfileProvider.future);

      expect(profile?.fullName, 'Тестовый Клиент');
      expect(profile?.agent?.colorPrimary, '#FF5A1F');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(apiClient.requestedPaths, contains('/client/profile'));
    });

    test(
      'uses auth cached agent colors while profile is still loading',
      () async {
        SharedPreferences.setMockInitialValues({
          'is_logged_in': true,
          'user_email': 'client@example.com',
          'user_domain': '2a-logistic.ru',
          'auth_token': 'mock-token',
          'client_id': 101,
          'client_name': 'Тестовый Клиент',
          'client_data': jsonEncode(_profileData()),
        });

        final apiClient = _HangingAuthRefreshApiClient();
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(apiClient)],
        );
        addTearDown(container.dispose);

        final restored = await _waitForAuthLoaded(container);
        expect(restored.isLoading, isFalse);

        final colors = container.read(brandColorsProvider);

        expect(colors.primary, const Color(0xFFFF5A1F));
      },
    );
  });
}

Map<String, dynamic> _profileData() {
  return {
    'id': 101,
    'fullName': 'Тестовый Клиент',
    'email': 'client@example.com',
    'balance': 0,
    'isActive': true,
    'createdAt': '2026-05-20T00:00:00.000Z',
    'agent': {
      'id': 1,
      'name': '2A Logistic',
      'domain': '2a-logistic.ru',
      'colorPrimary': '#FF5A1F',
      'colorSecondary': '#111827',
    },
    'codes': [
      {'id': 501, 'code': '2A-TEST'},
    ],
  };
}

Future<AuthState> _waitForAuthLoaded(ProviderContainer container) async {
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < const Duration(seconds: 1)) {
    final state = container.read(authProvider);
    if (!state.isLoading) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  return container.read(authProvider);
}

class _HangingAuthRefreshApiClient extends ApiClient {
  final requestedPaths = <String>[];

  @override
  Future<bool> hasTokenAsync() async => true;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    requestedPaths.add(path);
    return Completer<Response<T>>().future;
  }
}
