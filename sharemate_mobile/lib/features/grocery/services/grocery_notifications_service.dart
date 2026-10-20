import 'package:shared_preferences/shared_preferences.dart';

import '../models/grocery_notification.dart';

/// Tracks which grocery notifications a student has already seen, so the
/// bell in the grocery home screen can show an unread count like a normal
/// notification inbox.
class GroceryNotificationsService {
  static String _lastSeenKey(String uid) => 'grocery_notifications_last_seen_$uid';

  static Future<DateTime?> getLastSeen(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSeenKey(uid));
    return iso == null ? null : DateTime.tryParse(iso);
  }

  static Future<void> markSeenNow(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastSeenKey(uid),
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static int unseenCount(
    List<GroceryNotification> notifications,
    DateTime? lastSeen,
  ) {
    if (lastSeen == null) return notifications.length;
    return notifications
        .where((n) => n.createdAt.isAfter(lastSeen))
        .length;
  }
}
