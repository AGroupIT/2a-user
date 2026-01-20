/// Проверка мобильной платформы - всегда false на Web
bool isMobilePlatformImpl() => false;

/// Проверка iOS - всегда false на Web
bool isIOSImpl() => false;

/// Проверка Android - всегда false на Web
bool isAndroidImpl() => false;

/// Проверка Desktop платформы - всегда false на Web
bool isDesktopImpl() => false;

/// Проверка Windows - всегда false на Web
bool isWindowsImpl() => false;

/// Проверка macOS - всегда false на Web
bool isMacOSImpl() => false;

/// Проверка Linux - всегда false на Web
bool isLinuxImpl() => false;

/// Получить название платформы
String getPlatformNameImpl() => 'web';
