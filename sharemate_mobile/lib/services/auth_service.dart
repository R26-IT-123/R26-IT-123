import 'package:firebase_auth/firebase_auth.dart';

import '../config/api_client.dart';
import '../models/student_registration_data.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, ApiClient? apiClient})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _apiClient = apiClient ?? ApiClient();

  final FirebaseAuth _firebaseAuth;
  final ApiClient _apiClient;

  Future<void> registerStudent(StudentRegistrationData data) async {
    await _apiClient.postJson(
      '/api/auth/register',
      body: {
        'email': data.universityEmail.trim(),
        'password': data.password,
        'full_name': data.fullName.trim(),
        'contact_number': data.mobileNumber.trim(),
        'year': data.year,
        'semester': data.semester,
      },
    );
  }

  Future<void> resendOtp({required String email}) async {
    await _apiClient.postJson(
      '/api/auth/resend-otp',
      body: {'email': email.trim()},
    );
  }

  Future<UserCredential> verifyOtpAndSignIn({
    required StudentRegistrationData data,
    required String otp,
  }) async {
    await _apiClient.postJson(
      '/api/auth/verify-otp',
      body: {
        'email': data.universityEmail.trim(),
        'otp': otp.trim(),
      },
    );

    final credential = await signInStudent(
      email: data.universityEmail,
      password: data.password,
    );
    await credential.user?.updateDisplayName(data.fullName.trim());
    await credential.user?.reload();
    return credential;
  }

  Future<UserCredential> signInStudent({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/api/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    final customToken = response['custom_token'] as String;
    return _firebaseAuth.signInWithCustomToken(customToken);
  }

  Future<String> getIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase user is available.');
    }

    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError('Firebase returned an empty ID token.');
    }
    return token;
  }

  Future<void> signOut() => _firebaseAuth.signOut();
}
