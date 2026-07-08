// Firebase Options placeholder file for Boss Food Corner.
// To connect to your live Firebase project, configure this file or run `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCdVKWIQ11nRGeT8LI5Aj_vD9sogDmpEV4',
    appId: '1:396156381082:web:f0dd28a3b9edddba587c23',
    messagingSenderId: '396156381082',
    projectId: 'bossfoodcorner-e1fc8',
    authDomain: 'bossfoodcorner-e1fc8.firebaseapp.com',
    storageBucket: 'bossfoodcorner-e1fc8.firebasestorage.app',
    measurementId: 'G-8ZYFMPY96E',
  );
}
