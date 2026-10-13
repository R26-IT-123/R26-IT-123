import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class FirebaseConfig {
  const FirebaseConfig._();

  static Future<FirebaseApp> initialize() {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
