import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Проверка на Desktop платформу
bool _isDesktop() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.linux ||
         defaultTargetPlatform == TargetPlatform.macOS;
}

/// Используем SharedPreferences на Web и Desktop
bool get _useSharedPreferences => kIsWeb || _isDesktop();

/// Keys for secure storage
class SecureStorageKeys {
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
}

/// Secure storage service for sensitive data
/// On Web, uses SharedPreferences (localStorage) as fallback
class SecureStorageService {
  FlutterSecureStorage? _storage;
  SharedPreferences? _prefs;
  
  SecureStorageService() {
    // На Web и Desktop используем SharedPreferences
    // FlutterSecureStorage используется только на мобильных платформах
    if (!_useSharedPreferences) {
      _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
    }
  }
  
  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save auth token securely
  Future<void> saveToken(String token) async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      await prefs.setString(SecureStorageKeys.authToken, token);
    } else {
      await _storage?.write(key: SecureStorageKeys.authToken, value: token);
    }
  }

  /// Get auth token
  Future<String?> getToken() async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      return prefs.getString(SecureStorageKeys.authToken);
    }
    return _storage?.read(key: SecureStorageKeys.authToken);
  }

  /// Delete auth token
  Future<void> deleteToken() async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      await prefs.remove(SecureStorageKeys.authToken);
    } else {
      await _storage?.delete(key: SecureStorageKeys.authToken);
    }
  }

  /// Save refresh token securely
  Future<void> saveRefreshToken(String token) async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      await prefs.setString(SecureStorageKeys.refreshToken, token);
    } else {
      await _storage?.write(key: SecureStorageKeys.refreshToken, value: token);
    }
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      return prefs.getString(SecureStorageKeys.refreshToken);
    }
    return _storage?.read(key: SecureStorageKeys.refreshToken);
  }

  /// Delete refresh token
  Future<void> deleteRefreshToken() async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      await prefs.remove(SecureStorageKeys.refreshToken);
    } else {
      await _storage?.delete(key: SecureStorageKeys.refreshToken);
    }
  }

  /// Save user ID
  Future<void> saveUserId(int userId) async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      await prefs.setString(SecureStorageKeys.userId, userId.toString());
    } else {
      await _storage?.write(
          key: SecureStorageKeys.userId, value: userId.toString());
    }
  }

  /// Get user ID
  Future<int?> getUserId() async {
    String? value;
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      value = prefs.getString(SecureStorageKeys.userId);
    } else {
      value = await _storage?.read(key: SecureStorageKeys.userId);
    }
    return value != null ? int.tryParse(value) : null;
  }

  /// Delete user ID
  Future<void> deleteUserId() async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      await prefs.remove(SecureStorageKeys.userId);
    } else {
      await _storage?.delete(key: SecureStorageKeys.userId);
    }
  }

  /// Clear all secure storage
  Future<void> clearAll() async {
    if (_useSharedPreferences) {
      final prefs = await _sharedPrefs;
      await prefs.remove(SecureStorageKeys.authToken);
      await prefs.remove(SecureStorageKeys.refreshToken);
      await prefs.remove(SecureStorageKeys.userId);
    } else {
      await _storage?.deleteAll();
    }
  }

  /// Migrate from SharedPreferences to secure storage
  Future<void> migrateFromSharedPreferences() async {
    // На Web и Desktop миграция не нужна - уже используем SharedPreferences
    if (_useSharedPreferences) return;
    
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
