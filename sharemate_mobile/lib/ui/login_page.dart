import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_client.dart';
import '../services/auth_service.dart';
import '../utils/input_validators.dart';
import 'auth_widgets.dart';
import 'register_page.dart';
import 'student_home_page.dart';

const _kRememberMe  = 'remember_me';
const _kSavedEmail  = 'saved_email';
const _kSavedPass   = 'saved_password';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});

  final AuthService authService;

  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRememberMe);
    await prefs.remove(_kSavedEmail);
    await prefs.remove(_kSavedPass);
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting  = false;
  bool _rememberMe    = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_kRememberMe) ?? false;
    if (!remember) return;
    final email    = prefs.getString(_kSavedEmail)  ?? '';
    final password = prefs.getString(_kSavedPass)   ?? '';
    if (email.isNotEmpty && password.isNotEmpty && mounted) {
      setState(() {
        _rememberMe = true;
        _emailController.text    = email;
        _passwordController.text = password;
      });
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberMe, true);
    await prefs.setString(_kSavedEmail, email);
    await prefs.setString(_kSavedPass, password);
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final email    = _emailController.text;
      final password = _passwordController.text;

      final credential = await widget.authService.signInStudent(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (!mounted || user == null) return;

      if (_rememberMe) {
        await _saveCredentials(email, password);
      } else {
        await LoginPage.clearSavedCredentials();
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              StudentHomePage(authService: widget.authService, user: user),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _errorText = error.message);
    } on FirebaseAuthException catch (error) {
      setState(() => _errorText = _mapError(error));
    } catch (error) {
      setState(() => _errorText = 'Login failed. Check credentials and try again.');
      debugPrint('Login failed: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _mapError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid university email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Login failed. Check credentials and try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCanvas(
      badge: 'Student Login',
      title: 'Welcome back',
      subtitle: 'Sign in to your ShareMate account',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(
              label: 'University email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              validator: InputValidators.universityEmail,
            ),
            const SizedBox(height: 14),
            AuthField(
              label: 'Password',
              controller: _passwordController,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: InputValidators.password,
              onSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 10),

            // ── Remember me ──────────────────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      activeColor: const Color(0xFF24AE59),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Remember me',
                    style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                  ),
                ],
              ),
            ),

            if (_errorText != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: primaryButtonStyle(),
                onPressed: _isSubmitting ? null : _signIn,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Log in'),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: secondaryButtonStyle(),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RegisterPage(authService: widget.authService),
                    ),
                  );
                },
                child: const Text('Create an account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
