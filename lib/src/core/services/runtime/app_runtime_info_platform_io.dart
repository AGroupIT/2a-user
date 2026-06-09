import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class RuntimePlatformInfo {
  const RuntimePlatformInfo({required this.device, required this.osVersion});

  final String device;
  final String osVersion;
}

Future<RuntimePlatformInfo> getRuntimePlatformInfo() async {
  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      final device = _joinParts([
        info.manufacturer,
        info.model,
        'brand=${info.brand}',
        'device=${info.device}',
      ]);
      final osVersion = _joinParts([
        'Android ${info.version.release}',
        'SDK ${info.version.sdkInt}',
        if ((info.version.incremental).trim().isNotEmpty)
          'build ${info.version.incremental}',
      ]);
      return RuntimePlatformInfo(device: device, osVersion: osVersion);
    }

    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      final device = _joinParts([info.name, info.model, info.utsname.machine]);
      final osVersion = _joinParts([
        '${info.systemName} ${info.systemVersion}',
        info.utsname.release,
      ]);
      return RuntimePlatformInfo(device: device, osVersion: osVersion);
    }

    if (Platform.isMacOS) {
      final info = await plugin.macOsInfo;
      final device = _joinParts([info.computerName, info.model]);
      final osVersion = _joinParts([
        'macOS ${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
        info.osRelease,
      ]);
      return RuntimePlatformInfo(device: device, osVersion: osVersion);
    }
  } catch (_) {
    // Если device_info_plus недоступен на конкретной платформе/сборке,
    // сохраняем старое безопасное поведение вместо падения runtime headers.
  }

  final os = Platform.operatingSystem;
  final version = Platform.operatingSystemVersion;
  final host = Platform.localHostname.trim();
  final device = host.isNotEmpty ? host : '$os device';

  return RuntimePlatformInfo(device: device, osVersion: version);
}

String _joinParts(Iterable<String?> parts) {
  final normalized = parts
      .map((part) => part?.trim() ?? '')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return normalized.isEmpty ? 'unknown' : normalized.join(' · ');
}
