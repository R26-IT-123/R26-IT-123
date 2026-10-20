class InputValidators {
  const InputValidators._();

  static String? requiredField(String? value, {required String message}) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? universityEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter the university email.';
    }
    if (!text.contains('@')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 6) {
      return 'Use at least 6 characters.';
    }
    return null;
  }

  static String? mobileNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter the mobile number.';
    }

    final normalized = text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.length < 10) {
      return 'Enter a valid mobile number.';
    }
    return null;
  }
}
