import 'clipboard_helper_platform.dart'
    if (dart.library.html) 'clipboard_helper_web.dart'
    as platform;

class AppClipboard {
  const AppClipboard._();

  static Future<bool> copyText(String text) {
    return platform.copyText(text);
  }
}
