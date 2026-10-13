import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/grocery_notification.dart';
import '../services/grocery_api_service.dart';
import '../services/grocery_notifications_service.dart';
import 'announcements_screen.dart';
import 'browse_item_requests_screen.dart';
import 'grocery_chat_screen.dart';

const _accent = Color(0xFFBE185D);

IconData iconForNotificationType(String type) {
  switch (type) {
    case 'item_request_accepted':
      return Icons.volunteer_activism_rounded;
    case 'announcement':
      return Icons.storefront_rounded;
    case 'item_request_posted':
      return Icons.edit_note_rounded;
    case 'item_request_received':
      return Icons.shopping_basket_rounded;
    case 'chat_message':
    default:
      return Icons.chat_bubble_rounded;
  }
}

String timeAgo(DateTime time) {
  final diff = DateTime.now().toUtc().difference(time.toUtc());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

void openNotificationTarget(BuildContext context, GroceryNotification n) {
  final chatId = n.data['chat_id'] as String?;
  if (chatId != null && chatId.isNotEmpty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroceryChatScreen(chatId: chatId),
      ),
    );
    return;
  }
  if (n.type == 'announcement') {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const AnnouncementsScreen(mode: AnnouncementsMode.requester),
      ),
    );
    return;
  }
  if (n.type == 'item_request_posted') {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BrowseItemRequestsScreen(),
      ),
    );
  }
}

/// Full notification inbox for grocery events — opened from the bell icon
/// on the grocery home screen, or via "See all" in its popup dropdown.
class GroceryNotificationsScreen extends StatefulWidget {
  const GroceryNotificationsScreen({super.key});

  @override
  State<GroceryNotificationsScreen> createState() =>
      _GroceryNotificationsScreenState();
}

class _GroceryNotificationsScreenState
    extends State<GroceryNotificationsScreen> {
  final _service = GroceryApiService();
  late Future<List<GroceryNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchNotifications();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      GroceryNotificationsService.markSeenNow(uid);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.fetchNotifications();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF111827)),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<GroceryNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Color(0xFFD1D5DB)),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load notifications.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final notifications = snapshot.data!;
            if (notifications.isEmpty) {
              return ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 48, color: Color(0xFFD1D5DB)),
                        SizedBox(height: 12),
                        Text(
                          'No grocery notifications yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _NotificationTile(notification: notifications[index]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final GroceryNotification notification;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openNotificationTarget(context, notification),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE7F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconForNotificationType(notification.type),
                color: _accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Text(
                        timeAgo(notification.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
