import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';

void main() {
  group('ApiClient - Token Management', () {
    late ApiClient apiClient;

    setUp(() {
      apiClient = ApiClient();
    });

    test('should start without token', () {
      expect(apiClient.hasToken, false);
    });

    test('should set and retrieve token', () async {
      const testToken = 'test_token_123';

      await apiClient.setToken(testToken);

      expect(apiClient.hasToken, true);
      final retrieved = await apiClient.getToken();
      expect(retrieved, testToken);
    });

    test('should clear token', () async {
      const testToken = 'test_token_123';

      await apiClient.setToken(testToken);
      expect(apiClient.hasToken, true);

      await apiClient.clearToken();

      expect(apiClient.hasToken, false);
      final retrieved = await apiClient.getToken();
      expect(retrieved, null);
    });

    test('should handle multiple token updates', () async {
      await apiClient.setToken('token_1');
      expect(await apiClient.getToken(), 'token_1');

      await apiClient.setToken('token_2');
      expect(await apiClient.getToken(), 'token_2');

      await apiClient.setToken('token_3');
      expect(await apiClient.getToken(), 'token_3');
    });

    test('should handle empty token', () async {
      await apiClient.setToken('');

      expect(apiClient.hasToken, false);
      final retrieved = await apiClient.getToken();
      expect(retrieved, '');
    });

    test('should handle very long token', () async {
      final longToken = 'a' * 1000;

      await apiClient.setToken(longToken);

      expect(apiClient.hasToken, true);
      final retrieved = await apiClient.getToken();
      expect(retrieved, longToken);
    });

    test('should handle special characters in token', () async {
      const specialToken = 'token!@#\$%^&*()_+-={}[]|:";,.<>?/~`';

      await apiClient.setToken(specialToken);

      final retrieved = await apiClient.getToken();
      expect(retrieved, specialToken);
    });

    test('should handle token with spaces', () async {
      const tokenWithSpaces = 'token with spaces';

      await apiClient.setToken(tokenWithSpaces);

      final retrieved = await apiClient.getToken();
      expect(retrieved, tokenWithSpaces);
    });

    test('should handle token replacement', () async {
      await apiClient.setToken('old_token');
      await apiClient.setToken('new_token');

      final retrieved = await apiClient.getToken();
      expect(retrieved, 'new_token');
    });

    test('should handle clear without set', () async {
      await apiClient.clearToken();

      expect(apiClient.hasToken, false);
      expect(await apiClient.getToken(), null);
    });
  });

  group('ApiClient - Unauthorized Callback', () {
    late ApiClient apiClient;
    bool callbackCalled = false;

    setUp(() {
      apiClient = ApiClient();
      callbackCalled = false;
    });

    test('should allow setting unauthorized callback', () {
      expect(
        () => apiClient.setOnUnauthorizedCallback(() {
          callbackCalled = true;
        }),
        returnsNormally,
      );
    });

    test('should not call callback initially', () {
      apiClient.setOnUnauthorizedCallback(() {
        callbackCalled = true;
      });

      expect(callbackCalled, false);
    });

    test('should allow replacing callback', () {
      var callback1Called = false;
      var callback2Called = false;

      apiClient.setOnUnauthorizedCallback(() {
        callback1Called = true;
      });

      apiClient.setOnUnauthorizedCallback(() {
        callback2Called = true;
      });

      // Only second callback should be set
      expect(callback1Called, false);
      expect(callback2Called, false);
    });
  });

  group('ApiClient - Platform Detection', () {
    test('should work on current platform', () {
      final apiClient = ApiClient();

      // Should not throw
      expect(() => apiClient.hasToken, returnsNormally);
    });

    test('should handle token operations on web platform', () async {
      // This test runs on VM, but we test that the code handles both cases
      final apiClient = ApiClient();

      await apiClient.setToken('test_token');
      expect(apiClient.hasToken, true);

      final retrieved = await apiClient.getToken();
      expect(retrieved, 'test_token');
    });
  });

  group('ApiClient - Configuration', () {
    test('should be created successfully', () {
      expect(() => ApiClient(), returnsNormally);
    });

    test('should create multiple instances', () {
      final client1 = ApiClient();
      final client2 = ApiClient();

      expect(client1, isNotNull);
      expect(client2, isNotNull);
      expect(client1, isNot(same(client2)));
    });

    test('should share static in-memory token storage', () async {
      final client1 = ApiClient();
      final client2 = ApiClient();

      await client1.setToken('token_1');

      // Both clients share the same static _inMemoryToken
      expect(await client1.getToken(), 'token_1');
      expect(await client2.getToken(), 'token_1');

      await client2.setToken('token_2');

      // Both see the updated token
      expect(await client1.getToken(), 'token_2');
      expect(await client2.getToken(), 'token_2');
    });
  });

  group('ApiClient - Edge Cases', () {
    test('should handle rapid token changes', () async {
      final apiClient = ApiClient();

      for (var i = 0; i < 100; i++) {
        await apiClient.setToken('token_$i');
      }

      final finalToken = await apiClient.getToken();
      expect(finalToken, 'token_99');
    });

    test('should handle alternating set and clear', () async {
      final apiClient = ApiClient();

      for (var i = 0; i < 10; i++) {
        await apiClient.setToken('token_$i');
        expect(apiClient.hasToken, true);

        await apiClient.clearToken();
        expect(apiClient.hasToken, false);
      }
    });

    test('should handle token with newlines', () async {
      final apiClient = ApiClient();
      const tokenWithNewlines = 'token\nwith\nnewlines';

      await apiClient.setToken(tokenWithNewlines);

      final retrieved = await apiClient.getToken();
      expect(retrieved, tokenWithNewlines);
    });

    test('should handle unicode token', () async {
      final apiClient = ApiClient();
      const unicodeToken = 'токен_令牌_🔑';

      await apiClient.setToken(unicodeToken);

      final retrieved = await apiClient.getToken();
      expect(retrieved, unicodeToken);
    });

    test('should handle null after set', () async {
      final apiClient = ApiClient();

      await apiClient.setToken('test_token');
      await apiClient.clearToken();

      expect(apiClient.hasToken, false);
      expect(await apiClient.getToken(), null);
    });
  });

  group('ApiClient - Real-world Scenarios', () {
    test('should simulate login flow', () async {
      final apiClient = ApiClient();

      // Initially no token
      expect(apiClient.hasToken, false);

      // Login succeeds, set token
      await apiClient.setToken('user_session_token_abc123');
      expect(apiClient.hasToken, true);

      // Verify token persists
      final token = await apiClient.getToken();
      expect(token, 'user_session_token_abc123');
    });

    test('should simulate logout flow', () async {
      final apiClient = ApiClient();

      // User is logged in
      await apiClient.setToken('user_session_token');
      expect(apiClient.hasToken, true);

      // User logs out
      await apiClient.clearToken();
      expect(apiClient.hasToken, false);
      expect(await apiClient.getToken(), null);
    });

    test('should simulate token refresh flow', () async {
      final apiClient = ApiClient();

      // Initial token
      await apiClient.setToken('old_access_token');
      expect(await apiClient.getToken(), 'old_access_token');

      // Token refreshed
      await apiClient.setToken('new_access_token');
      expect(await apiClient.getToken(), 'new_access_token');
    });

    test('should simulate session expired flow', () async {
      final apiClient = ApiClient();

      // User logged in
      await apiClient.setToken('expired_token');
      apiClient.setOnUnauthorizedCallback(() {
        // Callback would trigger logout in real app
      });

      // Session expires, clear token
      await apiClient.clearToken();

      expect(apiClient.hasToken, false);
      expect(await apiClient.getToken(), null);
    });

    test('should handle multiple clients in same app', () async {
      // Multiple instances share the same secure storage on mobile,
      // but each has independent in-memory token
      final client1 = ApiClient();
      final client2 = ApiClient();

      await client1.setToken('token_1');

      // client2 gets the latest token from storage (both write to same storage)
      await client2.setToken('token_2');

      // Last write wins in shared storage
      final token2 = await client2.getToken();

      // client2 should have its own token
      expect(token2, 'token_2');
    });
  });
}
