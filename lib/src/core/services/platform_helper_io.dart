import 'dart:io';

/// Проверка мобильной платформы (Android или iOS)
bool isMobilePlatformImpl() {
  return Platform.isAndroid || Platform.isIOS;
}

/// Проверка iOS
bool isIOSImpl() {
  return Platform.isIOS;
}

/// Проверка Android  
bool isAndroidImpl() {
  return Platform.isAndroid;
}

/// Проверка Desktop платформы
bool isDesktopImpl() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

/// Проверка Windows
bool isWindowsImpl() {
  return Platform.isWindows;
}

/// Проверка macOS
bool isMacOSImpl() {
  return Platform.isMacOS;
}

/// Проверка Linux
bool isLinuxImpl() {
  return Platform.isLinux;
}

/// Получить название платформы
String getPlatformNameImpl() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}
