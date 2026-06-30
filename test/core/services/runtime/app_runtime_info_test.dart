import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/services/runtime/app_runtime_info.dart';

void main() {
  test('runtime headers contain only ASCII-safe values', () {
    const snapshot = AppRuntimeSnapshot(
      appVersion: '1.0.0',
      buildNumber: '1',
      platform: 'macos',
      device: 'Остапенко’s MacBook Air · Mac14,15',
      osVersion: 'macOS 15.0',
    );

    final headers = snapshot.toHeaders();
    final device = headers['X-Device']!;

    expect(device, 's MacBook Air Mac14,15');
    expect(device.codeUnits.every((unit) => unit >= 0x20 && unit <= 0x7E), true);
  });
}
