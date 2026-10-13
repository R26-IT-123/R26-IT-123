import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../models/student_registration_data.dart';
import '../services/auth_service.dart';
import '../utils/input_validators.dart';
import '../utils/sliit_options.dart';
import 'auth_widgets.dart';
import 'otp_verification_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedSemester;
  String? _selectedYear;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_selectedYear == null || _selectedSemester == null) {
      setState(() => _errorText = 'Select both study year and semester.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final registrationData = StudentRegistrationData(
      fullName: _fullNameController.text.trim(),
      universityEmail: _emailController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      year: _parseYear(_selectedYear!),
      semester: _parseSemester(_selectedSemester!),
      password: _passwordController.text,
    );

    try {
      await widget.authService.registerStudent(registrationData);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OtpVerificationPage(
            authService: widget.authService,
            registrationData: registrationData,
          ),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _errorText = error.message);
    } catch (error) {
      setState(() => _errorText = 'Registration failed. Check backend connection and try again.');
      debugPrint('Registration failed: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  int _parseYear(String value) => int.parse(value.substring(0, 1));

  int _parseSemester(String value) => int.parse(value.substring(value.length - 1));

  @override
  Widget build(BuildContext context) {
    return AuthCanvas(
      badge: 'New Student Account',
      title: 'Create account',
      subtitle: 'Join the ShareMate campus community',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              label: 'Full name',
              controller: _fullNameController,
              prefixIcon: Icons.person_outline_rounded,
              validator: (value) => InputValidators.requiredField(
                value,
                message: 'Enter your full name.',
              ),
            ),
            const SizedBox(height: 14),
            AuthField(
              label: 'University email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              validator: InputValidators.universityEmail,
            ),
            const SizedBox(height: 14),
            AuthField(
              label: 'Mobile number',
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: InputValidators.mobileNumber,
            ),
            const SizedBox(height: 14),
            _StyledDropdown(
              label: 'Study year',
              value: _selectedYear,
              items: SliitOptions.studyYears,
              icon: Icons.school_outlined,
              onChanged: (value) => setState(() => _selectedYear = value),
              validator: (value) =>
                  value == null ? 'Select your study year.' : null,
            ),
            const SizedBox(height: 14),
            _StyledDropdown(
              label: 'Semester',
              value: _selectedSemester,
              items: SliitOptions.semesters,
              icon: Icons.calendar_today_outlined,
              onChanged: (value) => setState(() => _selectedSemester = value),
              validator: (value) =>
                  value == null ? 'Select your semester.' : null,
            ),
            const SizedBox(height: 14),
            AuthField(
              label: 'Password',
              controller: _passwordController,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: InputValidators.password,
              onSubmitted: (_) => _register(),
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
                onPressed: _isSubmitting ? null : _register,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: secondaryButtonStyle(),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to log in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyledDropdown extends StatelessWidget {
  const _StyledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    required this.validator,
  });

  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        fillColor: const Color(0xFFF6F8F6),
        filled: true,
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF24AE59), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }
}
