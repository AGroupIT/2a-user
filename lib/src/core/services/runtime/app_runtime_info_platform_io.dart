import 'dart:io';

class RuntimePlatformInfo {
  const RuntimePlatformInfo({required this.device, required this.osVersion});

  final String device;
  final String osVersion;
}

RuntimePlatformInfo getRuntimePlatformInfo() {
  final os = Platform.operatingSystem;
  final version = Platform.operatingSystemVersion;
  final host = Platform.localHostname.trim();
  final device = host.isNotEmpty ? host : '$os device';

  return RuntimePlatformInfo(device: device, osVersion: version);
}
