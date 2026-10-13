import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/api_client.dart';
import '../models/announcement.dart';
import '../models/chat.dart';
import '../models/grocery_notification.dart';
import '../models/item_request.dart';
import '../models/message.dart';
import '../models/trust_profile.dart';

class GroceryApiService {
  GroceryApiService({ApiClient? apiClient, FirebaseAuth? auth})
      : _api = apiClient ?? ApiClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _auth;

  static const _base = '/api/grocery';

  Future<Map<String, String>> _authHeader() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('No authenticated Firebase user.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  // ── Announcements ────────────────────────────────────────────────────────────

  Future<GroceryAnnouncement> postAnnouncement({
    required String supermarket,
    String message = '',
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/announcements',
      headers: h,
      body: {'supermarket': supermarket, 'message': message},
    );
    return GroceryAnnouncement.fromJson(json);
  }

  Future<List<GroceryAnnouncement>> fetchAnnouncements() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/announcements', headers: h);
    return list
        .map((e) => GroceryAnnouncement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> closeAnnouncement(String id) async {
    final h = await _authHeader();
    await _api.deleteJson('$_base/announcements/$id', headers: h);
  }

  // ── Requests ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendRequest(String announcementId) async {
    final h = await _authHeader();
    return _api.postJson(
      '$_base/announcements/$announcementId/requests',
      headers: h,
      body: {},
    );
  }

  Future<List<Map<String, dynamic>>> fetchRequestsForAnnouncement(
      String announcementId) async {
    final h = await _authHeader();
    final list = await _api.getList(
      '$_base/announcements/$announcementId/requests',
      headers: h,
    );
    return list.cast<Map<String, dynamic>>();
  }

  // ── Chats ─────────────────────────────────────────────────────────────────────

  Future<List<GroceryChat>> fetchMyChats() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/chats', headers: h);
    return list
        .map((e) => GroceryChat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroceryMessage> sendTextMessage({
    required String chatId,
    required String content,
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {'type': 'text', 'content': content},
    );
    return GroceryMessage.fromJson(json);
  }

  Future<GroceryMessage> sendItemList({
    required String chatId,
    required List<Map<String, dynamic>> items,
    String? imageUrl,
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {
        'type': 'item_list',
        'content': 'Item list',
        'items': items,
        if (imageUrl != null) 'item_image_url': imageUrl,
      },
    );
    return GroceryMessage.fromJson(json);
  }

  Future<GroceryMessage> sendBill({
    required String chatId,
    required double amount,
    String note = '',
    String? imageUrl,
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {
        'type': 'bill',
        'content': 'Bill',
        'bill_amount': amount,
        'bill_note': note,
        if (imageUrl != null) 'bill_image_url': imageUrl,
      },
    );
    return GroceryMessage.fromJson(json);
  }

  Future<GroceryMessage> sendImageMessage({
    required String chatId,
    required String imageUrl,
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {'type': 'image', 'content': '', 'image_url': imageUrl},
    );
    return GroceryMessage.fromJson(json);
  }

  Future<void> closeChat(String chatId) async {
    final h = await _authHeader();
    await _api.deleteJson('$_base/chats/$chatId', headers: h);
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    final h = await _authHeader();
    await _api.deleteJson('$_base/chats/$chatId/messages/$messageId', headers: h);
  }

  // ── Payment settlement ────────────────────────────────────────────────────────

  Future<GroceryMessage> sendPaymentIntent({
    required String chatId,
    required String method,
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {'type': 'payment_intent', 'content': 'Payment: $method', 'payment_method': method},
    );
    return GroceryMessage.fromJson(json);
  }

  Future<GroceryMessage> sendPaymentSlip({
    required String chatId,
    required String slipImageUrl,
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {'type': 'payment_slip', 'content': 'Payment slip', 'slip_image_url': slipImageUrl},
    );
    return GroceryMessage.fromJson(json);
  }

  Future<GroceryMessage> confirmPayment({required String chatId}) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {'type': 'payment_confirmed', 'content': 'Payment confirmed'},
    );
    return GroceryMessage.fromJson(json);
  }

  Future<GroceryMessage> markDelivered({required String chatId}) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {'type': 'delivery_confirmed', 'content': 'Items delivered'},
    );
    return GroceryMessage.fromJson(json);
  }

  Future<GroceryMessage> confirmReceipt({required String chatId}) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/chats/$chatId/messages',
      headers: h,
      body: {'type': 'receipt_confirmed', 'content': 'Receipt confirmed'},
    );
    return GroceryMessage.fromJson(json);
  }

  // ── Item Requests ────────────────────────────────────────────────────────────

  Future<GroceryItemRequest> postItemRequest({
    required String supermarket,
    required List<Map<String, dynamic>> items,
    String note = '',
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/item-requests',
      headers: h,
      body: {'supermarket': supermarket, 'items': items, 'note': note},
    );
    return GroceryItemRequest.fromJson(json);
  }

  Future<List<GroceryItemRequest>> fetchItemRequests() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/item-requests', headers: h);
    return list
        .map((e) => GroceryItemRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GroceryItemRequest>> fetchMyItemRequests() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/item-requests/mine', headers: h);
    return list
        .map((e) => GroceryItemRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> closeItemRequest(String id) async {
    final h = await _authHeader();
    await _api.deleteJson('$_base/item-requests/$id', headers: h);
  }

  Future<Map<String, dynamic>> contactRequester(String requestId) async {
    final h = await _authHeader();
    return _api.postJson(
      '$_base/item-requests/$requestId/contact',
      headers: h,
      body: {},
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────────

  Future<List<GroceryNotification>> fetchNotifications() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/notifications', headers: h);
    return list
        .map((e) => GroceryNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Trust & Feedback ─────────────────────────────────────────────────────────

  Future<void> submitFeedback({
    required String chatId,
    required int rating,
    String comment = '',
  }) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/feedback',
      headers: h,
      body: {'chat_id': chatId, 'rating': rating, 'comment': comment},
    );
  }

  Future<TrustProfile> getTrustProfile(String uid) async {
    final h = await _authHeader();
    final json = await _api.getJson('$_base/users/$uid/trust', headers: h);
    return TrustProfile.fromJson(json);
  }

  Future<bool> hasSubmittedFeedback(String chatId) async {
    final h = await _authHeader();
    final json = await _api.getJson('$_base/feedback/chat/$chatId/mine', headers: h);
    return json['submitted'] as bool? ?? false;
  }
}
