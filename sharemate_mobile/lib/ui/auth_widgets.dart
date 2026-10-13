import 'package:flutter/material.dart';

class AuthCanvas extends StatelessWidget {
  const AuthCanvas({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.badge = 'Campus Mobility',
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Green gradient background ───────────────────────────────
          Container(
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0E6B35),
                  Color(0xFF1B9E50),
                  Color(0xFF33C261),
                  Color(0xFF80D9A0),
                ],
                stops: [0.0, 0.25, 0.45, 0.62],
              ),
            ),
          ),

          // ── Decorative circles ──────────────────────────────────────
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // ── Full layout ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),

                // Header text
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Share',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: 'Mate',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB8F5CE),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── White scrollable panel ────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(36)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.onSubmitted,
    this.prefixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        fillColor: const Color(0xFFF6F8F6),
        filled: true,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: const Color(0xFF9CA3AF), size: 20)
            : null,
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
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

ButtonStyle primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF24AE59),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 18),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

ButtonStyle secondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF1A1A1A),
    side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
    padding: const EdgeInsets.symmetric(vertical: 18),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}
