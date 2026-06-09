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
      'X-App-Version': appVersion,
      'X-Build-Number': buildNumber,
      'X-Platform': platform,
      'X-Device': device,
      'X-OS-Version': osVersion,
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
      device: _trimHeader(platformInfo.device),
      osVersion: _trimHeader(platformInfo.osVersion),
    );
  }

  Future<Map<String, String>> headers() async => (await snapshot()).toHeaders();

  String _trimHeader(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 160) return trimmed;
    return trimmed.substring(0, 160);
  }
}
