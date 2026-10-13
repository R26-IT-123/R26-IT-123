import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS yet.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS yet.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows yet.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux yet.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for Fuchsia.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCOrb8ijbu8DF8LRRKFSR4EAnH8E6WyyoY',
    appId: '1:986328446136:web:7e868f46cd0e056695704d',
    messagingSenderId: '986328446136',
    projectId: 'sharemate-d7299',
    authDomain: 'sharemate-d7299.firebaseapp.com',
    storageBucket: 'sharemate-d7299.firebasestorage.app',
    measurementId: 'G-T5TR9H4C2H',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAo1Mj5X2SOnoDZW1aem2AzeFKXGf1C9VY',
    appId: '1:986328446136:android:b1851f27da63bcc695704d',
    messagingSenderId: '986328446136',
    projectId: 'sharemate-d7299',
    storageBucket: 'sharemate-d7299.firebasestorage.app',
  );
}
