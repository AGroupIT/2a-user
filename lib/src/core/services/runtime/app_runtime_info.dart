import 'package:package_info_plus/package_info_plus.dart';

import '../platform_helper.dart';
import 'app_runtime_info_platform.dart';

class AppRuntimeSnapshot {
  const AppRuntimeSnapshot({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.device,
    required this.osVersion,
  });

  final String appVersion;
  final String buildNumber;
  final String platform;
  final String device;
  final String osVersion;

  Map<String, String> toHeaders() {
    return {
      'X-App-Version': _safeHttpHeaderValue(appVersion),
      'X-Build-Number': _safeHttpHeaderValue(buildNumber),
      'X-Platform': _safeHttpHeaderValue(platform),
      'X-Device': _safeHttpHeaderValue(device),
      'X-OS-Version': _safeHttpHeaderValue(osVersion),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'platform': platform,
      'device': device,
      'osVersion': osVersion,
    };
  }
}

class AppRuntimeInfo {
  AppRuntimeInfo._();

  static final AppRuntimeInfo instance = AppRuntimeInfo._();

  Future<PackageInfo>? _packageInfoFuture;
  Future<RuntimePlatformInfo>? _platformInfoFuture;

  Future<AppRuntimeSnapshot> snapshot() async {
    final info = await (_packageInfoFuture ??= PackageInfo.fromPlatform());
    final platformInfo = await (_platformInfoFuture ??=
        getRuntimePlatformInfo());

    return AppRuntimeSnapshot(
      appVersion: info.version,
      buildNumber: info.buildNumber,
      platform: getPlatformNameImpl(),
      device: platformInfo.device.trim(),
      osVersion: platformInfo.osVersion.trim(),
    );
  }

  Future<Map<String, String>> headers() async => (await snapshot()).toHeaders();
}

String _safeHttpHeaderValue(String value) {
  final ascii = value
      .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final safe = ascii.isEmpty ? 'unknown' : ascii;
  if (safe.length <= 160) return safe;
  return safe.substring(0, 160).trimRight();
}
