import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for secure storage
class SecureStorageKeys {
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
}

/// Secure storage service for sensitive data
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          // Note: encryptedSharedPreferences deprecated in v11, data auto-migrates
          aOptions: AndroidOptions(),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  /// Save auth token securely
  Future<void> saveToken(String token) async {
    await _storage.write(key: SecureStorageKeys.authToken, value: token);
  }

  /// Get auth token
  Future<String?> getToken() async {
    return _storage.read(key: SecureStorageKeys.authToken);
  }

  /// Delete auth token
  Future<void> deleteToken() async {
    await _storage.delete(key: SecureStorageKeys.authToken);
  }

  /// Save refresh token securely
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: SecureStorageKeys.refreshToken, value: token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return _storage.read(key: SecureStorageKeys.refreshToken);
  }

  /// Delete refresh token
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: SecureStorageKeys.refreshToken);
  }

  /// Save user ID
  Future<void> saveUserId(int userId) async {
    await _storage.write(
        key: SecureStorageKeys.userId, value: userId.toString());
  }

  /// Get user ID
  Future<int?> getUserId() async {
    final value = await _storage.read(key: SecureStorageKeys.userId);
    return value != null ? int.tryParse(value) : null;
  }

  /// Delete user ID
  Future<void> deleteUserId() async {
    await _storage.delete(key: SecureStorageKeys.userId);
  }

  /// Clear all secure storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Migrate from SharedPreferences to secure storage
  Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate token
    final token = prefs.getString('token');
    if (token != null) {
      await saveToken(token);
      await prefs.remove('token');
    }

    // Migrate user ID
    final userId = prefs.getInt('userId');
    if (userId != null) {
      await saveUserId(userId);
      await prefs.remove('userId');
    }
  }
}

/// Provider for secure storage service
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
