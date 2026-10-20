import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../features/flts/models/bus_route.dart';
import '../features/flts/models/route_incident.dart';
import '../features/flts/services/flts_api_service.dart';
import '../features/flts/services/gps_sharing_service.dart';
import '../features/flts/services/incident_notifications_service.dart';
import '../features/flts/ui/bus_feedback_screen.dart';
import '../features/flts/ui/flts_map_screen.dart';
import '../features/flts/ui/friendzone_screen.dart';
import '../features/flts/ui/incident_notifications_screen.dart';
import '../features/timetable/ui/timetable_screen.dart';
import '../features/anie/ui/anie_home_screen.dart';
import '../features/community_chat/ui/community_chat_screen.dart';
import '../features/grocery/ui/grocery_home_screen.dart';
import '../features/routesharing/services/routesharing_api_service.dart';
import '../features/routesharing/ui/route_search_screen.dart';
import '../features/routesharing/ui/routesharing_home_screen.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import 'login_page.dart';
import 'profile_screen.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final User user;

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final UserProfileService _userProfileService = UserProfileService();
  UserProfile? _profile;
  int _selectedTab = 0;

  // Route-join notification listener
  StreamSubscription<DocumentSnapshot>? _routeActivitySub;
  DateTime? _lastShownActivityTime;

  // New route sharing notification banner
  Map<String, dynamic>? _latestNewRoute;
  StreamSubscription<QuerySnapshot>? _newRouteSub;

  // Route sharing push — re-registers the FCM token whenever it rotates
  // (reinstall, app data clear, periodic OS refresh). Without this, a
  // rotated token goes stale server-side and push silently stops working
  // for that user while everything else (bell, in-app) keeps working since
  // it doesn't depend on the token.
  StreamSubscription<String>? _fcmTokenRefreshSub;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _requestFcmPermission();
    _listenForNewRoutes();
  }

  Future<void> _requestFcmPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance.subscribeToTopic('community_chat');

    // Grocery feature — per-user topics the backend publishes to for
    // item-request/chat/announcement events (see grocery_service).
    final uid = widget.user.uid;
    await FirebaseMessaging.instance.subscribeToTopic('grocery_community');
    await FirebaseMessaging.instance.subscribeToTopic('grocery_requester_$uid');
    await FirebaseMessaging.instance.subscribeToTopic('grocery_shopper_$uid');
    await FirebaseMessaging.instance.subscribeToTopic('grocery_chat_$uid');

    // Route sharing feature — token-based (not topic-based). Register this
    // device's FCM token so route_sharing_service can reach it directly.
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await RouteSharingApiService().registerFcmToken(fcmToken);
      }
    } catch (e) {
      debugPrint('Route sharing FCM token registration failed: $e');
    }

    // Keep the registered token current if it rotates later in the session.
    _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await RouteSharingApiService().registerFcmToken(newToken);
      } catch (e) {
        debugPrint('Route sharing FCM token refresh registration failed: $e');
      }
    });
  }

  Future<void> _loadProfile() async {
    try {
      final idToken = await widget.authService.getIdToken(forceRefresh: true);

      final profile = await _userProfileService.fetchProfile(idToken: idToken);
      if (profile.fullName.isNotEmpty &&
          widget.user.displayName != profile.fullName) {
        await widget.user.updateDisplayName(profile.fullName);
      }
      setState(() {
        _profile = profile;
      });
      if (profile.preferredRouteId != null) {
        _startRouteActivityListener(profile.preferredRouteId!);
        FirebaseMessaging.instance
            .subscribeToTopic('flts_route_${profile.preferredRouteId}');
      }
    } on ApiException catch (error) {
      debugPrint(
        'StudentHomePage backend error: ${error.statusCode} ${error.message}',
      );
    } catch (error) {
      debugPrint('StudentHomePage load failed: $error');
    }
  }

  Future<void> _signOut() async {
    await Future.wait([
      widget.authService.signOut(),
      LoginPage.clearSavedCredentials(),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(authService: widget.authService),
      ),
      (route) => false,
    );
  }

  /// Called when returning from ProfileScreen — re-reads preferredRouteId from
  /// Firestore and restarts the notification listener if the route changed.
  Future<void> _refreshRoutePreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _profile == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      final newRouteId = doc.data()?['preferred_route_id'] as String?;
      final oldRouteId = _profile!.preferredRouteId;
      if (newRouteId == oldRouteId) return;

      // Update cached profile with new route
      setState(() {
        _profile = UserProfile(
          fullName: _profile!.fullName,
          universityEmail: _profile!.universityEmail,
          mobileNumber: _profile!.mobileNumber,
          studentId: _profile!.studentId,
          faculty: _profile!.faculty,
          academicYear: _profile!.academicYear,
          preferredRouteId: newRouteId,
        );
      });

      // Restart the notification listener for the new route
      if (newRouteId != null) {
        _startRouteActivityListener(newRouteId);
      } else {
        _routeActivitySub?.cancel();
        _routeActivitySub = null;
      }
    } catch (_) {}
  }

  // ── Route-join notification ──────────────────────────────────────────────

  void _startRouteActivityListener(String routeId) {
    _routeActivitySub?.cancel();
    _routeActivitySub = FirebaseFirestore.instance
        .collection('route_activity')
        .doc(routeId)
        .snapshots()
        .listen(_onRouteActivity);
  }

  void _onRouteActivity(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return;
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return;

    final joinerUid = data['lastJoinedUserId'] as String?;
    final joinerName = data['lastJoinedDisplayName'] as String? ?? 'A student';
    final joinedAt = (data['lastJoinedAt'] as Timestamp?)?.toDate();
    final eventRouteId = data['routeId'] as String?;

    if (joinerUid == null || joinedAt == null) return;

    // Hard guard: only notify if this event is for OUR preferred route
    if (eventRouteId == null || eventRouteId != _profile?.preferredRouteId)
      return;

    // Don't notify the person who just joined
    if (joinerUid == FirebaseAuth.instance.currentUser?.uid) return;

    // Don't re-show an event we already displayed
    if (_lastShownActivityTime != null &&
        !joinedAt.isAfter(_lastShownActivityTime!)) {
      return;
    }

    // Ignore stale events from a previous session (older than 30 seconds)
    if (DateTime.now().difference(joinedAt).inSeconds > 30) {
      _lastShownActivityTime = joinedAt;
      return;
    }

    _lastShownActivityTime = joinedAt;

    if (!mounted) return;

    final routeId = _profile?.preferredRouteId;
    final routeDest = routeId == null
        ? 'your route'
        : BusRoute.sliitRoutes
            .firstWhere((r) => r.id == routeId,
                orElse: () => BusRoute.sliitRoutes.first)
            .destination;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$joinerName is on your route!',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Live sharing started · SLIIT → $routeDest',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _listenForNewRoutes() {
    final since = DateTime.now().subtract(const Duration(minutes: 5));
    _newRouteSub = FirebaseFirestore.instance
        .collection('routesharing_routes')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted || snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      final data = doc.data();
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();
      if (createdAt == null || createdAt.isBefore(since)) return;
      // Don't show own published routes
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (data['driver_id'] == uid) return;
      if (mounted) setState(() => _latestNewRoute = {...data, 'id': doc.id});
    });
  }

  @override
  void dispose() {
    _routeActivitySub?.cancel();
    _newRouteSub?.cancel();
    _fcmTokenRefreshSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final displayName =
        profile?.fullName ?? widget.user.displayName ?? 'Student';
    final firstName = displayName.split(' ').first;
    final facultyYear = profile != null
        ? '${profile.faculty} · ${profile.academicYear}'
        : 'SLIIT Faculty of Computing';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (fixed — does not scroll) ─────────────────────
            _Header(
              firstName: firstName,
              facultyYear: facultyYear,
              onSignOut: _signOut,
              preferredRouteId: profile?.preferredRouteId,
            ),

            // ── Community Pulse (fixed — does not scroll) ────────────
            const _CommunityPulse(),

            // ── Active live-share banner (fixed — does not scroll) ───
            const _ActiveShareBanner(),

            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF24AE59),
                onRefresh: _loadProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── New Route Notification Banner ─────────────────
                      if (_latestNewRoute != null)
                        _NewRouteBanner(
                          routeData: _latestNewRoute!,
                          onDismiss: () =>
                              setState(() => _latestNewRoute = null),
                          onTap: () {
                            setState(() => _latestNewRoute = null);
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => const RouteSearchScreen(),
                            ));
                          },
                        ),

                      // ── Live Routes ───────────────────────────────────
                      _LiveRoutesSection(
                        preferredRouteId: _profile?.preferredRouteId,
                      ),

                      // ── Section label ────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF24AE59),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'What do you need today?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── 4 Module Cards ───────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _ModuleCard(
                                    title: 'Live Transit',
                                    subtitle: 'Track buses in real time',
                                    icon: Icons.directions_bus_rounded,
                                    accent: const Color(0xFF16A34A),
                                    bgColor: const Color(0xFFDCFCE7),
                                    badge: 'FLTS',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => FltsMapScreen(
                                            preferredRouteId:
                                                _profile?.preferredRouteId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _ModuleCard(
                                    title: 'Academic Notes',
                                    subtitle: 'Share notes, earn tokens',
                                    icon: Icons.menu_book_rounded,
                                    accent: const Color(0xFF2563EB),
                                    bgColor: const Color(0xFFDBEAFE),
                                    badge: 'ANIE',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const AnieHomeScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _ModuleCard(
                                    title: 'Route Sharing',
                                    subtitle: 'Weekly ride plans',
                                    icon: Icons.directions_car_rounded,
                                    accent: const Color(0xFFD97706),
                                    bgColor: const Color(0xFFFEF3C7),
                                    badge: 'RIDE',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const RouteSharingHomeScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _ModuleCard(
                                    title: 'Grocery',
                                    subtitle: 'Community store pickups',
                                    icon: Icons.shopping_bag_rounded,
                                    accent: const Color(0xFFBE185D),
                                    bgColor: const Color(0xFFFCE7F3),
                                    badge: 'SHOP',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const GroceryHomeScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _ModuleCard(
                                    title: 'Bus Timetable',
                                    subtitle: 'Public bus schedules islandwide',
                                    icon: Icons.schedule_rounded,
                                    accent: const Color(0xFF7C3AED),
                                    bgColor: const Color(0xFFEDE9FE),
                                    badge: 'TIMETABLE',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const TimetableScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── Community Banner ─────────────────────────────
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: _CommunityBanner(),
                      ),

                      // ── Active Highlights ────────────────────────────
                      // TODO: re-enable when live data is ready
                      // Padding(
                      //   padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      //   child: Row(
                      //     children: [
                      //       Container(
                      //         width: 4,
                      //         height: 22,
                      //         decoration: BoxDecoration(
                      //           color: const Color(0xFF2563EB),
                      //           borderRadius: BorderRadius.circular(2),
                      //         ),
                      //       ),
                      //       SizedBox(width: 10),
                      //       Text(
                      //         'Campus highlights',
                      //         style: TextStyle(
                      //           fontSize: 20,
                      //           fontWeight: FontWeight.w900,
                      //           color: Color(0xFF111827),
                      //           letterSpacing: -0.4,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // const SizedBox(height: 14),
                      // const _HighlightsRow(),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom Nav ────────────────────────────────────────
            _BottomNav(
              selectedIndex: _selectedTab,
              onSelected: (i) {
                if (i == 1) {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const CommunityChatScreen(),
                  ));
                  return;
                }
                if (i == 3 && _profile != null) {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                        builder: (_) => ProfileScreen(profile: _profile!),
                      ))
                      .then((_) => _refreshRoutePreference());
                  return;
                }
                setState(() => _selectedTab = i);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.facultyYear,
    required this.onSignOut,
    required this.preferredRouteId,
  });

  final String firstName;
  final String facultyYear;
  final Future<void> Function() onSignOut;
  final String? preferredRouteId;

  @override
  Widget build(BuildContext context) {
    // SLIIT is in Colombo — use the fixed Sri Lanka offset (UTC+5:30) instead
    // of the device's local hour, since a misconfigured device timezone would
    // otherwise show the wrong greeting.
    final sriLankaTime =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final hour = sriLankaTime.hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Good morning'
        : hour >= 12 && hour < 17
            ? 'Good afternoon'
            : hour >= 17 && hour < 21
                ? 'Good evening'
                : 'Good night';
    final displayName = firstName.isNotEmpty
        ? '${firstName[0].toUpperCase()}${firstName.substring(1)}'
        : firstName;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFF24AE59),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $displayName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  facultyYear,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _NotificationBell(routeId: preferredRouteId),
          IconButton(
            onPressed: onSignOut,
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
            tooltip: 'Sign out',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Bell — badge count from real incident reports on the route
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationBell extends StatefulWidget {
  const _NotificationBell({required this.routeId});

  final String? routeId;

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  final _anchorKey = GlobalKey();
  DateTime? _lastSeen;

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  @override
  void didUpdateWidget(_NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId) _loadLastSeen();
  }

  Future<void> _loadLastSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final lastSeen = await IncidentNotificationsService.getLastSeen(uid);
    if (mounted) setState(() => _lastSeen = lastSeen);
  }

  Future<void> _openInbox() async {
    final routeId = widget.routeId;
    if (routeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set your preferred route in Profile to get incident alerts.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Clear the badge the moment the tray opens — mirrors a real
    // notification tray, not just the full inbox screen.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await IncidentNotificationsService.markSeenNow(uid);
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
            child: _NotificationDropdown(routeId: routeId),
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

    _loadLastSeen();
  }

  @override
  Widget build(BuildContext context) {
    final routeId = widget.routeId;
    if (routeId == null) {
      return IconButton(
        key: _anchorKey,
        onPressed: _openInbox,
        icon: const Icon(
          Icons.notifications_outlined,
          color: Color(0xFF374151),
          size: 24,
        ),
      );
    }

    return StreamBuilder<List<RouteIncident>>(
      stream: IncidentNotificationsService.streamForRoute(routeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Notification bell stream error: ${snapshot.error}');
        }
        final count = IncidentNotificationsService.unseenCount(
          snapshot.data ?? [],
          _lastSeen,
        );
        return Stack(
          key: _anchorKey,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: _openInbox,
              icon: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF374151),
                size: 24,
              ),
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Dropdown — a preview popup anchored under the bell, like a
// real mobile app's notification tray, instead of jumping straight to a
// full screen.
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationDropdown extends StatelessWidget {
  const _NotificationDropdown({required this.routeId});

  final String routeId;

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
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
              child: StreamBuilder<List<RouteIncident>>(
                stream: IncidentNotificationsService.streamForRoute(routeId),
                builder: (context, snapshot) {
                  final incidents = (snapshot.data ?? []).take(5).toList();
                  if (incidents.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              size: 36, color: Color(0xFFD1D5DB)),
                          SizedBox(height: 10),
                          Text(
                            'No incidents reported on\nyour route yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: incidents.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (context, i) {
                      final incident = incidents[i];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  FltsMapScreen(preferredRouteId: routeId),
                            ),
                          );
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
                                  color: incident.active
                                      ? const Color(0xFFFFE4E4)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  incident.typeIcon,
                                  color: incident.active
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF9CA3AF),
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      incident.typeLabel,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    if (incident.description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        incident.description,
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
                                _timeAgo(incident.createdAt),
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
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        IncidentNotificationsScreen(routeId: routeId),
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
                    color: Color(0xFF24AE59),
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

// ─────────────────────────────────────────────────────────────────────────────
// Community Pulse Strip — real Firestore count
// ─────────────────────────────────────────────────────────────────────────────

class _CommunityPulse extends StatelessWidget {
  const _CommunityPulse();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('live_gps').snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final label = count == 0
            ? 'No students sharing live right now'
            : '$count student${count == 1 ? '' : 's'} sharing live on buses right now';

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const _PulseDot(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Live',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active live-share banner — shown only to the student whose own GPS share
// is currently running, so leaving this screen doesn't lose track of it.
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveShareBanner extends StatelessWidget {
  const _ActiveShareBanner();

  static String _routeLabelFor(String? routeId) {
    if (routeId == null) return 'your route';
    const returnSuffix = '_return';
    final isReversed = routeId.endsWith(returnSuffix);
    final baseId =
        isReversed ? routeId.substring(0, routeId.length - returnSuffix.length) : routeId;
    final matches = BusRoute.sliitRoutes.where((r) => r.id == baseId);
    if (matches.isEmpty) return 'your route';
    final base = matches.first;
    return isReversed ? base.returnTrip.displayName : base.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GpsSharingService.instance,
      builder: (context, _) {
        final service = GpsSharingService.instance;
        if (!service.isSharing) return const SizedBox.shrink();

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FltsMapScreen(
                    preferredRouteId: service.activeRouteId,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded,
                      color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "You're sharing live on ${_routeLabelFor(service.activeRouteId)} — tap to resume",
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14532D),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF16A34A), size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFF16A34A),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Module Card
// ─────────────────────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.bgColor,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color bgColor;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(top: BorderSide(color: accent, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accent, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Community Banner
// ─────────────────────────────────────────────────────────────────────────────

class _CommunityBanner extends StatelessWidget {
  const _CommunityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E6B35), Color(0xFF24AE59)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SLIIT Community',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'One account.\nEvery campus need.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Switch between passenger, driver, student, shopper — all from one profile.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              _StatBubble(value: '4', label: 'Modules'),
              const SizedBox(height: 10),
              _StatBubble(value: '1', label: 'Account'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  const _StatBubble({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campus Highlights
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightsRow extends StatelessWidget {
  const _HighlightsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Real live bus count from Firestore
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('live_gps').snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return _HighlightChip(
                icon: Icons.directions_bus_rounded,
                color: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                value: '$count',
                label: 'Sharing live',
              );
            },
          ),
          const SizedBox(width: 12),
          const _HighlightChip(
            icon: Icons.menu_book_rounded,
            color: Color(0xFFDBEAFE),
            iconColor: Color(0xFF2563EB),
            value: '--',
            label: 'Notes today',
          ),
          const SizedBox(width: 12),
          const _HighlightChip(
            icon: Icons.directions_car_rounded,
            color: Color(0xFFFEF3C7),
            iconColor: Color(0xFFD97706),
            value: '--',
            label: 'Rides open',
          ),
          const SizedBox(width: 12),
          const _HighlightChip(
            icon: Icons.shopping_bag_rounded,
            color: Color(0xFFFCE7F3),
            iconColor: Color(0xFFBE185D),
            value: '--',
            label: 'Shoppers near',
          ),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: iconColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Routes Section — real-time from Firestore
// ─────────────────────────────────────────────────────────────────────────────

class _LiveRoutesSection extends StatelessWidget {
  const _LiveRoutesSection({this.preferredRouteId});

  final String? preferredRouteId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('live_gps').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final Map<String, List<String>> routeMap = {};
        final Map<String, String> routeVehicleNumber = {};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final routeId = data['routeId']?.toString() ?? '';
          final name = data['displayName']?.toString() ?? 'Student';
          final vNum = data['vehicleNumber']?.toString() ?? '';
          if (routeId.isEmpty) continue;
          routeMap.putIfAbsent(routeId, () => []).add(name);
          if (vNum.isNotEmpty) routeVehicleNumber[routeId] = vNum;
        }

        if (routeMap.isEmpty) return const SizedBox.shrink();

        // Show every route with a live sharer, not just the student's own —
        // the student's preferred route (if live) is pinned to the top.
        final entries = routeMap.entries.toList()
          ..sort((a, b) {
            if (a.key == preferredRouteId) return -1;
            if (b.key == preferredRouteId) return 1;
            return 0;
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bus_rounded,
                    size: 16,
                    color: Color(0xFF16A34A),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Live buses right now',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            ...entries.map((entry) {
              final routeId = entry.key;
              final names = entry.value;
              final vehicleNum = routeVehicleNumber[routeId];
              final route = BusRoute.sliitRoutes.firstWhere(
                (r) => r.id == routeId,
                orElse: () => BusRoute(
                  id: routeId,
                  destination: routeId.replaceAll('route_', ''),
                  stops: const [],
                ),
              );

              return Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: routeId == preferredRouteId
                      ? Border.all(color: const Color(0xFF24AE59), width: 1)
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (vehicleNum != null && vehicleNum.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BusFeedbackScreen(vehicleNumber: vehicleNum),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FriendZoneScreen(route: route),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              color: Color(0xFF16A34A),
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
                                    Flexible(
                                      child: Text(
                                        '${route.origin} → ${route.destination}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (routeId == preferredRouteId) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF24AE59),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Your Route',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (vehicleNum != null &&
                                    vehicleNum.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.directions_bus_rounded,
                                        size: 12,
                                        color: Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        vehicleNum,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _VehicleRatingBadge(
                                          key: ValueKey(vehicleNum),
                                          vehicleNumber: vehicleNum,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF16A34A),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        '${names.length} student${names.length == 1 ? '' : 's'} sharing · ${names.take(2).join(', ')}${names.length > 2 ? '...' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle Rating Badge — shows prior feedback for a bus before boarding
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleRatingBadge extends StatefulWidget {
  const _VehicleRatingBadge({super.key, required this.vehicleNumber});

  final String vehicleNumber;

  @override
  State<_VehicleRatingBadge> createState() => _VehicleRatingBadgeState();
}

class _VehicleRatingBadgeState extends State<_VehicleRatingBadge> {
  late final Future<List<Map<String, dynamic>>> _feedbackFuture =
      FltsApiService().fetchFeedback(vehicleNumber: widget.vehicleNumber);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _feedbackFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const Text(
            '· tap for feedback',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            overflow: TextOverflow.ellipsis,
          );
        }

        final items = snapshot.data!;
        final total = items.fold<double>(
          0,
          (acc, item) => acc + ((item['rating'] as num?)?.toDouble() ?? 0),
        );
        final avg = total / items.length;

        return Row(
          children: [
            const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                '${avg.toStringAsFixed(1)} (${items.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: const Color(0xFFDCFCE7),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? const Color(0xFF24AE59)
                    : const Color(0xFF9CA3AF),
              );
            }),
          ),
          child: NavigationBar(
            height: 64,
            elevation: 0,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: Color(0xFF9CA3AF)),
                selectedIcon:
                    Icon(Icons.home_rounded, color: Color(0xFF24AE59)),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF9CA3AF)),
                selectedIcon:
                    Icon(Icons.chat_bubble_rounded, color: Color(0xFF24AE59)),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: Color(0xFF9CA3AF)),
                selectedIcon:
                    Icon(Icons.bar_chart_rounded, color: Color(0xFF24AE59)),
                label: 'Activity',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded,
                    color: Color(0xFF9CA3AF)),
                selectedIcon:
                    Icon(Icons.person_rounded, color: Color(0xFF24AE59)),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New Route Notification Banner
// ─────────────────────────────────────────────────────────────────────────────

class _NewRouteBanner extends StatelessWidget {
  const _NewRouteBanner({
    required this.routeData,
    required this.onDismiss,
    required this.onTap,
  });

  final Map<String, dynamic> routeData;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = routeData['start_location'] as Map<String, dynamic>?;
    final startAddr = (start?['address'] as String?) ?? 'Pickup';
    final destination = routeData['destination'] as String? ?? '';
    final price =
        (routeData['price_per_trip'] as num?)?.toStringAsFixed(0) ?? '--';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New ride available',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$startAddr → $destination',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LKR $price/trip · Tap to view',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFF9CA3AF)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
