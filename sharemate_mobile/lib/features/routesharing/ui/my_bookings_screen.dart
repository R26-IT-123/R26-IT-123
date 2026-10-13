import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/booking.dart';
import '../models/route_post.dart';
import '../services/routesharing_api_service.dart';
import 'payment_slip_screen.dart';
import 'ride_tracking_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _api = RouteSharingApiService();
  List<Booking> _bookings = [];
  Map<String, RoutePost> _routeMap = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _trackRide(BuildContext context, Booking booking) async {
    try {
      final sessionFut = _api.getActiveSessionForRoute(booking.routeId);
      final routeFut = _api.getRoute(booking.routeId);
      final session = await sessionFut;
      final route = await routeFut;
      if (!context.mounted) return;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Ride hasn\'t started yet. Try again when the driver starts.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RideTrackingScreen(
            sessionId: session.id,
            driverId: session.driverId,
            route: route,
            passengerId: FirebaseAuth.instance.currentUser?.uid,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load ride data.')),
      );
    }
  }

  Future<void> _reportAbsence(BuildContext context, Booking booking) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      helpText: "Select the day you'll miss",
      selectableDayPredicate: (date) =>
          booking.daysSelected.contains(_weekdayKeys[date.weekday - 1]),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFD97706)),
        ),
        child: child!,
      ),
    );
    if (picked == null || !context.mounted) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Absence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Let the driver know you won't be riding on "
              '${_BookingCard._formatDate(picked)}.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706)),
            child: const Text('Notify Driver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await _api.notifyAbsence(
        bookingId: booking.id,
        rideDate: _isoDate(picked),
        reason: reasonCtrl.text.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Driver notified. Thanks for letting them know!')),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to notify driver.')),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listMyBookings();
      list.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

      final routeIds = list.map((b) => b.routeId).toSet();
      final routeMap = <String, RoutePost>{};
      await Future.wait(routeIds.map((id) async {
        try {
          routeMap[id] = await _api.getRoute(id);
        } catch (_) {}
      }));

      if (mounted) {
        setState(() {
          _bookings = list;
          _routeMap = routeMap;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load bookings.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                  const Text(
                    'My Bookings',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD97706)),
                    )
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : _bookings.isEmpty
                          ? _EmptyView(onRetry: _load)
                          : RefreshIndicator(
                              color: const Color(0xFFD97706),
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 16, 16, 24),
                                itemCount: _bookings.length,
                                itemBuilder: (_, i) => _BookingCard(
                                  booking: _bookings[i],
                                  route: _routeMap[_bookings[i].routeId],
                                  onUploadSlip: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PaymentSlipScreen(
                                          bookingId: _bookings[i].id,
                                          driverId: _bookings[i].driverId,
                                        ),
                                      ),
                                    );
                                    _load();
                                  },
                                  onTrackRide: _bookings[i].isConfirmed
                                      ? () => _trackRide(context, _bookings[i])
                                      : null,
                                  onReportAbsence: _bookings[i].isConfirmed
                                      ? () => _reportAbsence(context, _bookings[i])
                                      : null,
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

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onUploadSlip,
    this.onTrackRide,
    this.onReportAbsence,
    this.route,
  });

  final Booking booking;
  final RoutePost? route;
  final VoidCallback onUploadSlip;
  final VoidCallback? onTrackRide;
  final VoidCallback? onReportAbsence;

  @override
  Widget build(BuildContext context) {
    final status = booking.status;
    final statusInfo = _statusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusInfo.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusInfo.icon,
                    size: 20, color: statusInfo.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.isWeekly ? 'Weekly booking' : 'Daily booking',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Text(
                      _formatDays(booking.daysSelected),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusInfo.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusInfo.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusInfo.color,
                  ),
                ),
              ),
            ],
          ),

          // ── Route info ─────────────────────────────────────────
          if (route != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route_rounded,
                      size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${route!.startAddress ?? 'Start'} → ${route!.destination}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // ── Fare row ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fare',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              Text(
                'LKR ${booking.fareAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          if (booking.createdAt != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Booked on',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                Text(
                  _formatDate(booking.createdAt!),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ],

          if (booking.seatNumber != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Seat',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                Text(
                  '#${booking.seatNumber}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ],

          if (booking.priority) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      size: 12, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text(
                    'Priority seat',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Track ride CTA ─────────────────────────────────────
          if (onTrackRide != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTrackRide,
                icon: const Icon(Icons.my_location_rounded, size: 16),
                label: const Text('Track Ride'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],

          // ── Report absence CTA ─────────────────────────────────
          if (onReportAbsence != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReportAbsence,
                icon: const Icon(Icons.person_off_outlined, size: 16),
                label: const Text("Can't make it on a ride day?"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],

          // ── Upload slip CTA ─────────────────────────────────────
          if (booking.isBookingApproved) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onUploadSlip,
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: const Text('Upload Payment Slip'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],

          if (booking.isPaymentUploaded) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 14, color: Color(0xFF7C3AED)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment slip submitted — awaiting driver approval',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (booking.holdExpiresAt != null &&
              (booking.isPendingApproval || booking.isBookingApproved)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 13, color: Color(0xFFD97706)),
                const SizedBox(width: 4),
                Text(
                  booking.isBookingApproved
                      ? 'Upload slip by ${_formatExpiry(booking.holdExpiresAt!)}'
                      : 'Hold expires ${_formatExpiry(booking.holdExpiresAt!)}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFD97706)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _formatDays(List<String> days) {
    if (days.length == 5) return 'Mon – Fri';
    return days
        .map((d) => d[0].toUpperCase() + d.substring(1, 3))
        .join(', ');
  }

  static String _formatExpiry(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inMinutes < 1) return 'soon';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    return 'in ${diff.inHours}h';
  }

  static _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'confirmed':
        return _StatusInfo(
          label: 'Confirmed',
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFFF0FDF4),
          icon: Icons.check_circle_rounded,
        );
      case 'booking_approved':
        return _StatusInfo(
          label: 'Upload Slip',
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          icon: Icons.receipt_long_rounded,
        );
      case 'payment_uploaded':
        return _StatusInfo(
          label: 'Slip Submitted',
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF5F3FF),
          icon: Icons.hourglass_top_rounded,
        );
      case 'pending_approval':
        return _StatusInfo(
          label: 'Pending',
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
          icon: Icons.hourglass_empty_rounded,
        );
      case 'declined':
        return _StatusInfo(
          label: 'Declined',
          color: const Color(0xFFEF4444),
          bgColor: const Color(0xFFFEF2F2),
          icon: Icons.cancel_rounded,
        );
      case 'expired':
        return _StatusInfo(
          label: 'Expired',
          color: const Color(0xFF6B7280),
          bgColor: const Color(0xFFF3F4F6),
          icon: Icons.timer_off_rounded,
        );
      case 'cancelled':
        return _StatusInfo(
          label: 'Cancelled',
          color: const Color(0xFF6B7280),
          bgColor: const Color(0xFFF3F4F6),
          icon: Icons.do_not_disturb_on_rounded,
        );
      default:
        return _StatusInfo(
          label: status,
          color: const Color(0xFF6B7280),
          bgColor: const Color(0xFFF3F4F6),
          icon: Icons.circle_outlined,
        );
    }
  }
}

class _StatusInfo {
  const _StatusInfo({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;
}

// ── Empty / error views ───────────────────────────────────────────────────────

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
                  style:
                      const TextStyle(color: Color(0xFF6B7280))),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bookmark_border_rounded,
                  size: 56, color: Color(0xFFD1D5DB)),
              const SizedBox(height: 14),
              const Text(
                'No bookings yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Find a route and book your first seat.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFD97706)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
}
