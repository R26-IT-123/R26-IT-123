import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    // Make status bar transparent so image bleeds through
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full screen background image ────────────────────────────
          Image.asset(
            'assets/images/welcomescreen.jpg',
            fit: BoxFit.cover,
          ),

          // ── Dark overlay — top stays dark, fades to deeper dark bottom
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55000000), // light dark top
                  Color(0x22000000), // clear middle — let image breathe
                  Color(0xCC000000), // dark lower
                  Color(0xF2000000), // near black at bottom panel
                ],
                stops: [0.0, 0.35, 0.62, 1.0],
              ),
            ),
          ),

          // ── Top branding ────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Row(
                children: [
                  // SM badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF24AE59),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'SM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ShareMate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom content panel ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tagline
                    const Text(
                      'Move smart.\nShare more.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Transit · Rides · Notes · Grocery\nAll in one campus community.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 15,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Log in button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF24AE59),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  LoginPage(authService: authService),
                            ),
                          );
                        },
                        child: const Text('Log in'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Create account button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  RegisterPage(authService: authService),
                            ),
                          );
                        },
                        child: const Text('Create an account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
