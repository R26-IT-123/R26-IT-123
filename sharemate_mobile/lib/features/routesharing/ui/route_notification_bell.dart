import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/route_notification.dart';
import '../services/route_notifications_service.dart';
import '../services/routesharing_api_service.dart';
import 'route_notifications_screen.dart';

const _accent = Color(0xFFD97706);

/// Bell icon with an unread badge for route sharing — tapping it opens a
/// preview popup anchored under the bell, mirroring the app's other
/// notification trays (grocery, FLTS). Shared between the rider home screen
/// and the driver dashboard since notifications are already uid-scoped
/// server-side.
///
/// Backed by the REST `/api/routesharing/notifications` endpoint rather than
/// a live Firestore stream (route sharing talks to Firestore only through
/// the backend), so it's refreshed on open and on a light poll.
class RouteNotificationBell extends StatefulWidget {
  const RouteNotificationBell({super.key});

  @override
  State<RouteNotificationBell> createState() => _RouteNotificationBellState();
}

class _RouteNotificationBellState extends State<RouteNotificationBell> {
  final _service = RouteSharingApiService();
  final _anchorKey = GlobalKey();

  List<RouteNotification> _notifications = [];
  DateTime? _lastSeen;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final results = await _service.fetchNotifications();
      final lastSeen = await RouteNotificationsService.getLastSeen(uid);
      if (!mounted) return;
      setState(() {
        _notifications = results;
        _lastSeen = lastSeen;
      });
    } catch (e) {
      debugPrint('RouteNotificationBell load failed: $e');
    }
  }

  Future<void> _openInbox() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Clear the badge the moment the tray opens — mirrors a real
      // notification tray, not just the full inbox screen.
      await RouteNotificationsService.markSeenNow(uid);
    }
    if (!mounted) return;

    final anchorBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    double top = 90;
    if (anchorBox != null && overlayBox != null) {
      final anchorBottomLeft =
          anchorBox.localToGlobal(Offset(0, anchorBox.size.height));
      top = anchorBottomLeft.dy + 8;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) => Stack(
        children: [
          Positioned(
            right: 16,
            top: top,
            child: _RouteNotificationDropdown(notifications: _notifications),
          ),
        ],
      ),
      transitionBuilder: (dialogContext, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
    );

    _load();
  }

  @override
  Widget build(BuildContext context) {
    final count =
        RouteNotificationsService.unseenCount(_notifications, _lastSeen);
    return Stack(
      key: _anchorKey,
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _openInbox,
          icon: const Icon(Icons.notifications_outlined,
              color: _accent, size: 22),
          tooltip: 'Notifications',
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RouteNotificationDropdown extends StatelessWidget {
  const _RouteNotificationDropdown({required this.notifications});

  final List<RouteNotification> notifications;

  @override
  Widget build(BuildContext context) {
    final preview = notifications.take(5).toList();

    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF9CA3AF)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            Flexible(
              child: preview.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              size: 36, color: Color(0xFFD1D5DB)),
                          SizedBox(height: 10),
                          Text(
                            'No route-sharing notifications yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: preview.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (context, i) {
                        final n = preview[i];
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            openRouteNotificationTarget(context, n);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    iconForRouteNotificationType(n.type),
                                    color: _accent,
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      if (n.body.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          n.body,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeAgo(n.createdAt),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RouteNotificationsScreen(),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'See all',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
