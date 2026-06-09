class RuntimePlatformInfo {
  const RuntimePlatformInfo({required this.device, required this.osVersion});

  final String device;
  final String osVersion;
}

Future<RuntimePlatformInfo> getRuntimePlatformInfo() async {
  return const RuntimePlatformInfo(device: 'unknown', osVersion: 'unknown');
}
