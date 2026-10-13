import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/booking.dart';
import '../models/ride_session.dart';
import '../models/route_post.dart';
import '../services/routesharing_api_service.dart';
import 'active_ride_screen.dart';
import 'bank_account_screen.dart';
import 'booking_requests_screen.dart';
import 'driver_feedback_screen.dart';
import 'publish_route_screen.dart';
import 'route_notification_bell.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _api = RouteSharingApiService();

  List<RoutePost> _routes = [];
  List<Booking> _pendingBookings = [];
  Map<String, RideSession> _activeSessions = {};
  Map<String, dynamic>? _ratingProfile;
  bool _hasBankAccount = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _pickRideDate(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today.subtract(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFD97706)),
        ),
        child: child!,
      ),
    );
    if (picked == null) return null;
    return '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getDriverRoutes(),
        _api.listDriverBookings(),
      ]);
      final routes = results[0] as List<RoutePost>;
      final bookings = results[1] as List<Booking>;

      final now = DateTime.now();
      final visibleRoutes = routes.where((r) {
        if (r.status == 'inactive') return false;
        final end = r.endDate != null ? DateTime.tryParse(r.endDate!) : null;
        if (end != null && end.isBefore(now)) return false;
        return true;
      }).toList();

      final activeRoutes = visibleRoutes.where((r) => r.status == 'active').toList();
      final activeSessions = <String, RideSession>{};
      if (activeRoutes.isNotEmpty) {
        final sessions = await Future.wait(
          activeRoutes.map((r) => _api.getActiveSessionForRoute(r.id)),
        );
        for (var i = 0; i < activeRoutes.length; i++) {
          final s = sessions[i];
          if (s != null) activeSessions[activeRoutes[i].id] = s;
        }
      }

      visibleRoutes.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

      final driverId = FirebaseAuth.instance.currentUser?.uid ?? '';
      Map<String, dynamic>? ratingProfile;
      if (driverId.isNotEmpty) {
        try {
          ratingProfile = await _api.getDriverRatingProfile(driverId);
        } catch (_) {}
      }

      var hasBankAccount = false;
      try {
        final driverProfile = await _api.getDriverProfile();
        hasBankAccount = [
          driverProfile['bank_account_holder'],
          driverProfile['bank_name'],
          driverProfile['bank_account_number'],
          driverProfile['bank_branch'],
        ].any((v) => v != null && (v as String).isNotEmpty);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _routes = visibleRoutes;
          _pendingBookings = bookings
              .where((b) =>
                  b.status == 'pending_approval' ||
                  b.status == 'pending_payment')
              .toList();
          _activeSessions = activeSessions;
          _ratingProfile = ratingProfile;
          _hasBankAccount = hasBankAccount;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load dashboard.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteRoute(RoutePost route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text(
          'Delete the route to "${route.destination}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deactivateRoute(route.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete route.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF374151)),
                  ),
                  const Expanded(
                    child: Text(
                      'Driver Dashboard',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const RouteNotificationBell(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 20, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD97706)))
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          color: const Color(0xFFD97706),
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // ── Stats row ──────────────────────
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: 'My routes',
                                        value: '${_routes.length}',
                                        icon:
                                            Icons.route_rounded,
                                        color: const Color(
                                            0xFF2563EB),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        label: 'Pending requests',
                                        value:
                                            '${_pendingBookings.length}',
                                        icon: Icons
                                            .pending_actions_rounded,
                                        color: _pendingBookings
                                                .isNotEmpty
                                            ? const Color(
                                                0xFFD97706)
                                            : const Color(
                                                0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // ── Bank account details ────────────
                                _BankAccountCard(
                                  hasAccount: _hasBankAccount,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<bool>(
                                        builder: (_) =>
                                            const BankAccountScreen(),
                                      ),
                                    );
                                    if (context.mounted) _load();
                                  },
                                ),
                                const SizedBox(height: 16),

                                // ── Rating profile ──────────────────
                                if (_ratingProfile != null) ...[
                                  _RatingCard(
                                    profile: _ratingProfile!,
                                    driverId: FirebaseAuth.instance.currentUser?.uid ?? '',
                                  ),
                                  const SizedBox(height: 20),
                                ] else
                                  const SizedBox(height: 4),

                                // ── Pending requests CTA ────────────
                                if (_pendingBookings.isNotEmpty) ...[
                                  _SectionHeader(
                                    title: 'Booking requests',
                                    trailing: TextButton(
                                      onPressed: () async {
                                        await Navigator.of(context)
                                            .push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const BookingRequestsScreen(),
                                          ),
                                        );
                                        _load();
                                      },
                                      child: const Text(
                                        'View all',
                                        style: TextStyle(
                                            color: Color(0xFFD97706),
                                            fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...List.generate(
                                    _pendingBookings
                                                .length >
                                            2
                                        ? 2
                                        : _pendingBookings.length,
                                    (i) => _PendingBookingTile(
                                      booking: _pendingBookings[i],
                                      onTap: () async {
                                        await Navigator.of(context)
                                            .push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const BookingRequestsScreen(),
                                          ),
                                        );
                                        _load();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // ── My routes ───────────────────────
                                _SectionHeader(
                                  title: 'My routes',
                                  trailing: FilledButton.icon(
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const PublishRouteScreen(),
                                        ),
                                      );
                                      _load();
                                    },
                                    icon: const Icon(
                                        Icons.add_rounded,
                                        size: 16),
                                    label: const Text('New Route'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFD97706),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8),
                                      textStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w700),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                if (_routes.isEmpty)
                                  _EmptyRoutes(
                                    onPublish: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const PublishRouteScreen(),
                                        ),
                                      );
                                      _load();
                                    },
                                  )
                                else
                                  ..._routes.map(
                                    (r) => _DriverRouteCard(
                                      route: r,
                                      activeSession: _activeSessions[r.id],
                                      onDelete: () => _deleteRoute(r),
                                      onManage: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const BookingRequestsScreen(),
                                          ),
                                        );
                                        _load();
                                      },
                                      onStartRide: () async {
                                        final existing = _activeSessions[r.id];
                                        if (existing != null) {
                                          if (!context.mounted) return;
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => ActiveRideScreen(
                                                routeId: r.id,
                                                rideDate: existing.rideDate,
                                                route: r,
                                                existingSession: existing,
                                              ),
                                            ),
                                          );
                                        } else {
                                          final date = await _pickRideDate(context);
                                          if (date == null || !context.mounted) return;
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => ActiveRideScreen(
                                                routeId: r.id,
                                                rideDate: date,
                                                route: r,
                                              ),
                                            ),
                                          );
                                        }
                                        if (context.mounted) _load();
                                      },
                                    ),
                                  ),

                                const SizedBox(height: 24),
                              ],
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

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Pending booking tile ──────────────────────────────────────────────────────

class _PendingBookingTile extends StatelessWidget {
  const _PendingBookingTile({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPendingPayment = booking.status == 'pending_payment';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPendingPayment
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPendingPayment
                    ? Icons.receipt_rounded
                    : Icons.person_add_rounded,
                size: 18,
                color: isPendingPayment
                    ? const Color(0xFFD97706)
                    : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPendingPayment
                        ? 'Payment slip review'
                        : '${booking.isWeekly ? "Weekly" : "Daily"} booking request',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'LKR ${booking.fareAmount.toStringAsFixed(0)} · ${booking.daysSelected.length} day${booking.daysSelected.length > 1 ? "s" : ""}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// ── Driver route card ─────────────────────────────────────────────────────────

class _DriverRouteCard extends StatelessWidget {
  const _DriverRouteCard({
    required this.route,
    required this.onManage,
    required this.onStartRide,
    required this.onDelete,
    this.activeSession,
  });

  final RoutePost route;
  final VoidCallback onManage;
  final VoidCallback onStartRide;
  final VoidCallback onDelete;
  final RideSession? activeSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (route.startAddress != null) ...[
                      Text(
                        route.startAddress!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward_rounded,
                                size: 12, color: Color(0xFFD97706)),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      route.destination,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Departs ${route.departureTime}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: route.status == 'active'
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  route.status == 'active' ? 'Active' : route.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: route.status == 'active'
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _InfoChip(
                label:
                    '${route.seatsAvailable}/${route.totalSeats} seats',
                color: route.seatsAvailable > 0
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                textColor: route.seatsAvailable > 0
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              _InfoChip(
                label:
                    'LKR ${route.pricePerTrip.toStringAsFixed(0)}/trip',
                color: const Color(0xFFFEF3C7),
                textColor: const Color(0xFFD97706),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete route',
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onManage,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
                child: const Text('Manage',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          if (route.status == 'active') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStartRide,
                icon: Icon(
                  activeSession != null
                      ? Icons.play_arrow_rounded
                      : Icons.play_circle_rounded,
                  size: 16,
                ),
                label: Text(activeSession != null ? 'Resume Ride' : 'Start Ride'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor),
      ),
    );
  }
}

// ── Empty routes ──────────────────────────────────────────────────────────────

class _EmptyRoutes extends StatelessWidget {
  const _EmptyRoutes({required this.onPublish});
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.add_road_rounded,
              size: 48, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          const Text(
            'No routes published yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Publish your weekly commute and start earning back fuel costs.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Publish First Route'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bank account card ─────────────────────────────────────────────────────────

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({required this.hasAccount, required this.onTap});

  final bool hasAccount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_rounded,
                size: 20, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAccount
                      ? 'Bank details on file'
                      : 'Add your bank details to receive payments',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: Text(hasAccount ? 'Edit' : 'Add'),
          ),
        ],
      ),
    );
  }
}

// ── Rating card ───────────────────────────────────────────────────────────────

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.profile, required this.driverId});
  final Map<String, dynamic> profile;
  final String driverId;

  @override
  Widget build(BuildContext context) {
    final avgRating = (profile['overall_avg_rating'] as num?)?.toDouble() ?? 0;
    final totalRides = (profile['total_rides'] as num?)?.toInt() ?? 0;
    final latestSummary = profile['ai_summary'] as String?;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              const Text(
                'Your Rating',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DriverFeedbackScreen(
                      profile: profile,
                      driverId: driverId,
                    ),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: const Text('View Feedback'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < avgRating.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 18,
                        color: const Color(0xFFD97706),
                      );
                    }),
                  ),
                  Text(
                    '$totalRides ride${totalRides == 1 ? '' : 's'} completed',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ],
          ),
          if (latestSummary != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    latestSummary,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'AI summary · recent passengers',
                style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
