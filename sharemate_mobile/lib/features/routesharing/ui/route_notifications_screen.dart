import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/route_notification.dart';
import '../services/route_notifications_service.dart';
import '../services/routesharing_api_service.dart';
import 'booking_requests_screen.dart';
import 'my_bookings_screen.dart';
import 'route_search_screen.dart';

const _accent = Color(0xFFD97706);

const _driverFacingTypes = {
  'booking_request',
  'passenger_absence',
  'slip_submitted',
};

IconData iconForRouteNotificationType(String type) {
  switch (type) {
    case 'booking_request':
      return Icons.pending_actions_rounded;
    case 'payment_required':
    case 'slip_submitted':
      return Icons.receipt_long_rounded;
    case 'booking_confirmed':
    case 'payment_verified':
      return Icons.check_circle_rounded;
    case 'booking_declined':
    case 'slip_rejected':
      return Icons.cancel_rounded;
    case 'passenger_absence':
      return Icons.person_off_rounded;
    case 'ride_started':
    case 'ride_ended':
      return Icons.directions_car_filled_rounded;
    case 'payment_marked':
      return Icons.payments_rounded;
    case 'new_route':
      return Icons.route_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

String timeAgo(DateTime time) {
  final diff = DateTime.now().toUtc().difference(time.toUtc());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

void openRouteNotificationTarget(BuildContext context, RouteNotification n) {
  if (n.type == 'new_route') {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RouteSearchScreen()),
    );
    return;
  }
  if (n.type == 'passenger_absence') {
    _showNotificationDetailsDialog(context, n);
    return;
  }
  if (_driverFacingTypes.contains(n.type)) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BookingRequestsScreen()),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()),
  );
}

void _showNotificationDetailsDialog(BuildContext context, RouteNotification n) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconForRouteNotificationType(n.type),
                color: _accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              n.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
      content: Text(
        n.body,
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close', style: TextStyle(color: _accent)),
        ),
      ],
    ),
  );
}

/// Full notification inbox for route-sharing events (bookings, payments,
/// rides, new routes) — opened from the bell icon, or via "See all" in its
/// popup dropdown. Shared between the rider home screen and the driver
/// dashboard since notifications are already scoped server-side by uid.
class RouteNotificationsScreen extends StatefulWidget {
  const RouteNotificationsScreen({super.key});

  @override
  State<RouteNotificationsScreen> createState() =>
      _RouteNotificationsScreenState();
}

class _RouteNotificationsScreenState extends State<RouteNotificationsScreen> {
  final _service = RouteSharingApiService();
  late Future<List<RouteNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchNotifications();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      RouteNotificationsService.markSeenNow(uid);
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
        child: FutureBuilder<List<RouteNotification>>(
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
                          'No route-sharing notifications yet.',
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

  final RouteNotification notification;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openRouteNotificationTarget(context, notification),
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
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconForRouteNotificationType(notification.type),
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
