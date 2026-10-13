import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'config/firebase_config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'ui/splash_page.dart';

@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Runs in its own background isolate — no Dart state (including whether
  // Firebase/the notifications plugin were already set up) is shared with
  // the main isolate, so both need to be (re-)initialized here. Backend
  // pushes are data-only, so nothing shows unless we display it ourselves.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService.handleBackgroundMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  runApp(const ShareMateApp());
}

class ShareMateApp extends StatelessWidget {
  const ShareMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShareMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F2),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: FutureBuilder<FirebaseApp>(
        future: FirebaseConfig.initialize(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingScreen();
          }

          if (snapshot.hasError) {
            return _FirebaseErrorScreen(error: snapshot.error.toString());
          }

          // Firebase is ready — safe to touch FirebaseMessaging.onMessage now.
          PushNotificationService.initialize();

          return SplashPage(authService: AuthService());
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FirebaseErrorScreen extends StatelessWidget {
  const _FirebaseErrorScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Firebase initialization failed',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Check platform Firebase configuration. Web requires firebase_options.dart and Android requires android/app/google-services.json.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
