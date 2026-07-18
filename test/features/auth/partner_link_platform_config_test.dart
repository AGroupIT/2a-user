import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android принимает HTTPS partner-connect и custom-scheme fallback', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    expect(manifest, contains('android:value="true"'));
    expect(manifest, contains('android:launchMode="singleTop"'));
    expect(manifest, contains('android:scheme="twoalogistic"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="prod-api.cp.2a-logistic.com"'));
    expect(manifest, contains('android:pathPrefix="/partner-connect/"'));
  });

  test('iOS принимает Universal Link и custom-scheme fallback', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final debugEntitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final releaseEntitlements = File(
      'ios/Runner/Release.entitlements',
    ).readAsStringSync();

    expect(infoPlist, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(infoPlist, contains('<true/>'));
    expect(infoPlist, contains('<string>twoalogistic</string>'));
    for (final entitlements in [debugEntitlements, releaseEntitlements]) {
      expect(
        entitlements,
        contains('<string>applinks:prod-api.cp.2a-logistic.com</string>'),
      );
    }
  });
}
