import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/route_incident.dart';

/// Tracks which incident reports a student has already seen, so the home
/// page bell can show an unread count like a normal notification inbox.
class IncidentNotificationsService {
  static const _collection = 'route_incidents';

  /// Streams all incidents ever reported on [routeId], most recent first.
  /// Filtered client-side by createdAt instead of an `orderBy` query so no
  /// Firestore composite index is required alongside the route_id equality
  /// filter.
  static Stream<List<RouteIncident>> streamForRoute(String routeId) {
    return FirebaseFirestore.instance
        .collection(_collection)
        .where('route_id', isEqualTo: routeId)
        .snapshots()
        .map((snapshot) {
      final incidents = snapshot.docs
          .map((doc) => RouteIncident.fromJson(doc.data()))
          .toList();
      incidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return incidents;
    });
  }

  static String _lastSeenKey(String uid) => 'flts_incidents_last_seen_$uid';

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

  static int unseenCount(List<RouteIncident> incidents, DateTime? lastSeen) {
    if (lastSeen == null) return incidents.length;
    return incidents.where((i) => i.createdAt.isAfter(lastSeen)).length;
  }
}
