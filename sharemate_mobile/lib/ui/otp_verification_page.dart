import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../models/student_registration_data.dart';
import '../services/auth_service.dart';
import '../utils/input_validators.dart';
import 'auth_widgets.dart';
import 'student_home_page.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.authService,
    required this.registrationData,
  });

  final AuthService authService;
  final StudentRegistrationData registrationData;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _errorText;
  String? _infoText;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
      _infoText = null;
    });

    try {
      final credential = await widget.authService.verifyOtpAndSignIn(
        data: widget.registrationData,
        otp: _otpController.text,
      );
      final user = credential.user;
      if (!mounted || user == null) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => StudentHomePage(
            authService: widget.authService,
            user: user,
          ),
        ),
        (route) => false,
      );
    } on ApiException catch (error) {
      setState(() => _errorText = error.message);
    } on FirebaseAuthException catch (error) {
      setState(() => _errorText = error.message ?? 'Sign in failed after OTP verification.');
    } catch (error) {
      setState(() => _errorText = 'Verification failed. Please try again.');
      debugPrint('OTP verification failed: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _errorText = null;
      _infoText = null;
    });

    try {
      await widget.authService.resendOtp(
        email: widget.registrationData.universityEmail,
      );
      setState(() => _infoText = 'A new OTP has been sent to your email.');
    } on ApiException catch (error) {
      setState(() => _errorText = error.message);
    } catch (error) {
      setState(() => _errorText = 'Could not resend OTP right now.');
      debugPrint('OTP resend failed: $error');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCanvas(
      badge: 'Email Verification',
      title: 'Enter OTP',
      subtitle:
          'We sent a 6-digit verification code to ${widget.registrationData.universityEmail}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(
              label: '6-digit OTP',
              controller: _otpController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.verified_user_outlined,
              validator: (value) {
                final required = InputValidators.requiredField(
                  value,
                  message: 'Enter the OTP from your email.',
                );
                if (required != null) return required;
                final normalized = value!.trim();
                if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
                  return 'OTP must be 6 digits.';
                }
                return null;
              },
              onSubmitted: (_) => _verifyOtp(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 14),
              _StatusCard(
                message: _errorText!,
                color: const Color(0xFFFEF2F2),
                borderColor: const Color(0xFFFECACA),
                iconColor: const Color(0xFFEF4444),
                icon: Icons.error_outline_rounded,
              ),
            ],
            if (_infoText != null) ...[
              const SizedBox(height: 14),
              _StatusCard(
                message: _infoText!,
                color: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                iconColor: const Color(0xFF16A34A),
                icon: Icons.mark_email_read_outlined,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: primaryButtonStyle(),
                onPressed: _isSubmitting ? null : _verifyOtp,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify and continue'),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: secondaryButtonStyle(),
                onPressed: _isResending ? null : _resendOtp,
                child: _isResending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Resend OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.message,
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: iconColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
