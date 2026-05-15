// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class RuntimePlatformInfo {
  const RuntimePlatformInfo({required this.device, required this.osVersion});

  final String device;
  final String osVersion;
}

RuntimePlatformInfo getRuntimePlatformInfo() {
  final navigator = html.window.navigator;
  final platform = navigator.platform ?? 'web';
  final userAgent = navigator.userAgent;

  return RuntimePlatformInfo(
    device: platform.isEmpty ? 'web' : platform,
    osVersion: userAgent.isEmpty ? 'web' : userAgent,
  );
}
