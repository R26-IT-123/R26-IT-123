import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/api_client.dart';

class CommunityChatApiService {
  CommunityChatApiService({ApiClient? apiClient, FirebaseAuth? auth})
      : _apiClient = apiClient ?? ApiClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _auth;

  /// Tells the backend to push an FCM notification to every other student
  /// subscribed to the community chat topic. Non-critical — the message is
  /// already stored in Firestore regardless of whether this succeeds.
  Future<void> notifyNewMessage({
    required String senderName,
    required String text,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) return;
    await _apiClient.postJson(
      '/api/community-chat/notify',
      body: {'sender_name': senderName, 'text': text},
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
