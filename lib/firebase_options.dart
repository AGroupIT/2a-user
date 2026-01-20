// File generated for Firebase configuration
// Run `flutterfire configure` to update this file with your Firebase project settings

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android configuration from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD5d71JdVd3__JAaoQSlQzXsA1Jpbz3nnM',
    appId: '1:949693718080:android:c3e09cea22b5d8379a49a5',
    messagingSenderId: '949693718080',
    projectId: 'a-user',
    storageBucket: 'a-user.firebasestorage.app',
  );

  // iOS configuration (use same project, different app ID if needed)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA30Zv9Q7azXA5Y3_NpvfiM1gr2f1RRccE',
    appId: '1:949693718080:ios:17d100c16cd133409a49a5',
    messagingSenderId: '949693718080',
    projectId: 'a-user',
    storageBucket: 'a-user.firebasestorage.app',
    iosBundleId: 'com.twoalogistic.user',
  );

  // macOS configuration
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA30Zv9Q7azXA5Y3_NpvfiM1gr2f1RRccE',
    appId: '1:949693718080:ios:17d100c16cd133409a49a5',
    messagingSenderId: '949693718080',
    projectId: 'a-user',
    storageBucket: 'a-user.firebasestorage.app',
    iosBundleId: 'com.twoalogistic.user',
  );

  // Windows Desktop configuration (uses Web config)
  // Firebase for Windows Desktop uses web SDK internally
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDpIETRJbo2aMr0qELkpxZ0dacTiZrrG_0',
    appId: '1:949693718080:web:83f29ac197174e289a49a5',
    messagingSenderId: '949693718080',
    projectId: 'a-user',
    storageBucket: 'a-user.firebasestorage.app',
    authDomain: 'a-user.firebaseapp.com',
  );

  // Linux Desktop configuration (uses Web config)
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDpIETRJbo2aMr0qELkpxZ0dacTiZrrG_0',
    appId: '1:949693718080:web:83f29ac197174e289a49a5',
    messagingSenderId: '949693718080',
    projectId: 'a-user',
    storageBucket: 'a-user.firebasestorage.app',
    authDomain: 'a-user.firebaseapp.com',
  );

  // Web configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDpIETRJbo2aMr0qELkpxZ0dacTiZrrG_0',
    appId: '1:949693718080:web:83f29ac197174e289a49a5',
    messagingSenderId: '949693718080',
    projectId: 'a-user',
    storageBucket: 'a-user.firebasestorage.app',
    authDomain: 'a-user.firebaseapp.com',
    measurementId: 'G-KXFX1L6V3W',
  );
}
