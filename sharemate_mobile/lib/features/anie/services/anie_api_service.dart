import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/api_client.dart';
import '../models/anie_topic.dart';
import '../models/note.dart';

class AnieApiService {
  AnieApiService({ApiClient? apiClient, FirebaseAuth? auth})
      : _api  = apiClient ?? ApiClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _auth;

  static const _base = '/api/anie';

  Future<Map<String, String>> _authHeader() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('No authenticated Firebase user.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<AnieTopic>> fetchTopics() async {
    final list = await _api.getList('$_base/topics');
    return list
        .map((e) => AnieTopic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ValidateNoteResult> validateNote({
    required String title,
    required String subject,
    required String topic,
    required List<String> fileUrls,
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/validate-note',
      headers: h,
      body: {
        'title':     title,
        'subject':   subject,
        'topic':     topic,
        'file_urls': fileUrls,
      },
    );
    return ValidateNoteResult.fromJson(json);
  }

  Future<Map<String, dynamic>> generateTopicPdf(String noteId) async {
    final h = await _authHeader();
    return _api.postJson(
      '$_base/generate-topic-pdf/$noteId',
      headers: h,
      body: {},
    );
  }

  Future<List<AnieNote>> fetchNotes({String? subject, String? topic}) async {
    final params = <String, String>{};
    if (subject != null) params['subject'] = subject;
    if (topic != null)   params['topic']   = topic;
    Map<String, String>? headers;
    try {
      headers = await _authHeader();
    } catch (_) {
      headers = null;
    }
    final list = await _api.getList(
      '$_base/notes',
      queryParams: params,
      headers: headers,
    );
    return list
        .map((e) => AnieNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AnieNoteDetail> fetchNoteDetail(String noteId) async {
    Map<String, String>? headers;
    try {
      headers = await _authHeader();
    } catch (_) {
      headers = null;
    }
    final json = await _api.getJson('$_base/notes/$noteId', headers: headers);
    return AnieNoteDetail.fromJson(json);
  }

  Future<int> fetchWalletBalance() async {
    final h = await _authHeader();
    final json = await _api.getJson('$_base/wallet', headers: h);
    return (json['balance'] as num).toInt();
  }

  Future<({bool purchased, int balance, String? topicPdfUrl})> purchaseNote(
    String noteId,
  ) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/notes/$noteId/purchase',
      headers: h,
      body: {},
    );
    return (
      purchased:    json['purchased'] as bool,
      balance:      (json['balance'] as num).toInt(),
      topicPdfUrl:  json['topic_pdf_url'] as String?,
    );
  }

  Future<int> incrementDownload(String noteId) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/notes/$noteId/download',
      headers: h,
      body: {},
    );
    return (json['download_count'] as num).toInt();
  }

  Future<({bool liked, int likeCount})> toggleLike(String noteId) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/notes/$noteId/like',
      headers: h,
      body: {},
    );
    return (
      liked:     json['liked'] as bool,
      likeCount: (json['like_count'] as num).toInt(),
    );
  }

  Future<List<AnieComment>> fetchComments(String noteId) async {
    final list = await _api.getList('$_base/notes/$noteId/comments');
    return list
        .map((e) => AnieComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AnieComment> postComment(String noteId, String text) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/notes/$noteId/comments',
      headers: h,
      body: {'text': text},
    );
    return AnieComment.fromJson(json);
  }
}
