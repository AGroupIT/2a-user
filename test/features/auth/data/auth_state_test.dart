import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('should create state with default values', () {
      const state = AuthState();

      expect(state.isLoggedIn, false);
      expect(state.userEmail, null);
      expect(state.userDomain, null);
      expect(state.isLoading, true); // По умолчанию isLoading = true
      expect(state.error, null);
      expect(state.clientId, null);
      expect(state.clientName, null);
      expect(state.clientData, null);
    });

    test('should create state with custom values', () {
      final clientData = {'id': 1, 'fullName': 'Test Client'};
      final state = AuthState(
        isLoggedIn: true,
        userEmail: 'test@example.com',
        userDomain: 'testdomain',
        isLoading: false,
        error: 'Test error',
        clientId: 1,
        clientName: 'Test Client',
        clientData: clientData,
      );

      expect(state.isLoggedIn, true);
      expect(state.userEmail, 'test@example.com');
      expect(state.userDomain, 'testdomain');
      expect(state.isLoading, false);
      expect(state.error, 'Test error');
      expect(state.clientId, 1);
      expect(state.clientName, 'Test Client');
      expect(state.clientData, clientData);
    });

    test('should copy state with new values', () {
      const original = AuthState(
        isLoggedIn: false,
        isLoading: false,
      );

      final updated = original.copyWith(
        isLoggedIn: true,
        userEmail: 'test@example.com',
        userDomain: 'testdomain',
        isLoading: true,
        error: 'Error',
        clientId: 42,
        clientName: 'New Client',
        clientData: {'test': 'data'},
      );

      expect(updated.isLoggedIn, true);
      expect(updated.userEmail, 'test@example.com');
      expect(updated.userDomain, 'testdomain');
      expect(updated.isLoading, true);
      expect(updated.error, 'Error');
      expect(updated.clientId, 42);
      expect(updated.clientName, 'New Client');
      expect(updated.clientData, {'test': 'data'});
    });

    test('should keep original values when copyWith without parameters', () {
      final clientData = {'id': 1};
      final original = AuthState(
        isLoggedIn: true,
        userEmail: 'test@example.com',
        userDomain: 'testdomain',
        isLoading: false,
        error: 'Error',
        clientId: 1,
        clientName: 'Test Client',
        clientData: clientData,
      );

      final updated = original.copyWith();

      expect(updated.isLoggedIn, original.isLoggedIn);
      expect(updated.userEmail, original.userEmail);
      expect(updated.userDomain, original.userDomain);
      expect(updated.isLoading, original.isLoading);
      expect(updated.error, original.error);
      expect(updated.clientId, original.clientId);
      expect(updated.clientName, original.clientName);
      expect(updated.clientData, original.clientData);
    });

    test('should clear error when clearError is true', () {
      const original = AuthState(error: 'Test error', isLoading: false);

      final updated = original.copyWith(clearError: true);

      expect(updated.error, null);
    });

    test('should keep error when clearError is false', () {
      const original = AuthState(error: 'Test error', isLoading: false);

      final updated = original.copyWith(clearError: false);

      expect(updated.error, 'Test error');
    });

    test('should replace error when copyWith with new error', () {
      const original = AuthState(error: 'Old error', isLoading: false);

      final updated = original.copyWith(error: 'New error');

      expect(updated.error, 'New error');
    });

    test('should update only specified fields', () {
      const original = AuthState(
        isLoggedIn: false,
        isLoading: false,
        error: 'Test error',
      );

      final updated = original.copyWith(isLoggedIn: true);

      expect(updated.isLoggedIn, true);
      expect(updated.isLoading, false);
      expect(updated.error, 'Test error');
    });

    test('should handle multiple copyWith calls', () {
      const original = AuthState(isLoading: true);

      final step1 = original.copyWith(isLoggedIn: true);
      final step2 = step1.copyWith(userEmail: 'test@example.com');
      final step3 = step2.copyWith(isLoading: false, clearError: true);

      expect(step3.isLoggedIn, true);
      expect(step3.userEmail, 'test@example.com');
      expect(step3.isLoading, false);
      expect(step3.error, null);
    });

    test('should handle null clientId', () {
      const state = AuthState(
        isLoggedIn: true,
        clientId: null,
        isLoading: false,
      );

      expect(state.clientId, null);
    });

    test('should handle zero clientId', () {
      const state = AuthState(
        isLoggedIn: true,
        clientId: 0,
        isLoading: false,
      );

      expect(state.clientId, 0);
    });

    test('should handle empty strings', () {
      const state = AuthState(
        isLoggedIn: true,
        userEmail: '',
        userDomain: '',
        clientName: '',
        isLoading: false,
      );

      expect(state.userEmail, '');
      expect(state.userDomain, '');
      expect(state.clientName, '');
    });

    test('should handle complex clientData', () {
      final complexData = {
        'id': 1,
        'fullName': 'Test Client',
        'email': 'test@example.com',
        'agent': {
          'domain': 'testdomain',
          'name': 'Test Agent',
        },
        'nested': {
          'deep': {
            'value': 123,
          },
        },
      };

      final state = AuthState(
        isLoggedIn: true,
        clientData: complexData,
        isLoading: false,
      );

      expect(state.clientData, complexData);
      expect(state.clientData!['agent'], isA<Map<String, dynamic>>());
      expect(state.clientData!['nested']['deep']['value'], 123);
    });

    test('should handle long email addresses', () {
      const longEmail = 'very.long.email.address.with.many.dots@subdomain.example.com';
      const state = AuthState(
        userEmail: longEmail,
        isLoading: false,
      );

      expect(state.userEmail, longEmail);
    });

    test('should handle unicode in client name', () {
      const unicodeName = 'Иван Петров 李明 محمد';
      const state = AuthState(
        clientName: unicodeName,
        isLoading: false,
      );

      expect(state.clientName, unicodeName);
    });

    test('should handle special characters in domain', () {
      const domain = 'test-domain_123.example';
      const state = AuthState(
        userDomain: domain,
        isLoading: false,
      );

      expect(state.userDomain, domain);
    });

    test('should handle very long error messages', () {
      final longError = 'Error: ${'a' * 500}';
      final state = AuthState(
        error: longError,
        isLoading: false,
      );

      expect(state.error, longError);
      expect(state.error!.length, greaterThan(500));
    });

    test('should handle real-world logged in state', () {
      final state = AuthState(
        isLoggedIn: true,
        userEmail: 'client@example.com',
        userDomain: 'domain123',
        isLoading: false,
        clientId: 42,
        clientName: 'John Doe',
        clientData: {
          'id': 42,
          'fullName': 'John Doe',
          'email': 'client@example.com',
          'agent': {
            'domain': 'domain123',
          },
        },
      );

      expect(state.isLoggedIn, true);
      expect(state.userEmail, 'client@example.com');
      expect(state.userDomain, 'domain123');
      expect(state.isLoading, false);
      expect(state.error, null);
      expect(state.clientId, 42);
      expect(state.clientName, 'John Doe');
      expect(state.clientData, isNotNull);
    });

    test('should handle real-world logged out state', () {
      const state = AuthState(
        isLoggedIn: false,
        isLoading: false,
      );

      expect(state.isLoggedIn, false);
      expect(state.userEmail, null);
      expect(state.userDomain, null);
      expect(state.isLoading, false);
      expect(state.error, null);
      expect(state.clientId, null);
      expect(state.clientName, null);
      expect(state.clientData, null);
    });

    test('should handle error state during login', () {
      const state = AuthState(
        isLoggedIn: false,
        isLoading: false,
        error: 'Неверный email или пароль',
      );

      expect(state.isLoggedIn, false);
      expect(state.isLoading, false);
      expect(state.error, 'Неверный email или пароль');
    });

    test('should handle loading state', () {
      const state = AuthState(
        isLoggedIn: false,
        isLoading: true,
      );

      expect(state.isLoggedIn, false);
      expect(state.isLoading, true);
      expect(state.error, null);
    });
  });
}
