import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/booking.dart';
import '../models/route_post.dart';
import '../services/routesharing_api_service.dart';
import 'booking_request_detail_screen.dart';

class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  final _api = RouteSharingApiService();
  List<Booking> _bookings = [];
  Map<String, RoutePost> _routeMap = {};
  bool _loading = true;
  String? _error;
  int? _yearFilter; // null = all years

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.listDriverBookings(),
        _api.getDriverRoutes(),
      ]);
      final bookings = results[0] as List<Booking>;
      final routes = results[1] as List<RoutePost>;
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _routeMap = {for (final r in routes) r.id: r};
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load requests.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Derive the driver's own year from any route in the map
    final driverYear = _routeMap.values.isNotEmpty
        ? _routeMap.values.first.driverYear
        : null;

    // Apply year filter then sort: same year as driver first, then descending
    List<Booking> filtered = _yearFilter == null
        ? _bookings
        : _bookings.where((b) => b.passengerYear == _yearFilter).toList();

    int yearPriority(int? y) {
      if (y == null) return 99;
      if (driverYear != null && y == driverYear) return 0;
      return 4 - y + 1;
    }
    filtered = [...filtered]
      ..sort((a, b) => yearPriority(a.passengerYear).compareTo(yearPriority(b.passengerYear)));

    final pending =
        filtered.where((b) => b.status == 'pending_approval').toList();
    final others =
        filtered.where((b) => b.status != 'pending_approval').toList();

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
                      'Booking Requests',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  if (pending.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${pending.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Year filter chips ────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _YearChip(
                      label: 'All',
                      selected: _yearFilter == null,
                      onTap: () => setState(() => _yearFilter = null),
                    ),
                    const SizedBox(width: 8),
                    ...([4, 3, 2, 1].map((y) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _YearChip(
                        label: '${y}${_ordinal(y)} Year',
                        selected: _yearFilter == y,
                        priority: y == driverYear,
                        onTap: () => setState(() =>
                            _yearFilter = _yearFilter == y ? null : y),
                      ),
                    ))),
                  ],
                ),
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD97706)))
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : _bookings.isEmpty
                          ? _EmptyView(onRetry: _load)
                          : RefreshIndicator(
                              color: const Color(0xFFD97706),
                              onRefresh: _load,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 16, 16, 24),
                                children: [
                                  if (pending.isNotEmpty) ...[
                                    const _SectionLabel('Needs action'),
                                    const SizedBox(height: 8),
                                    ...pending.map((b) =>
                                        _RequestCard(
                                          booking: b,
                                          route: _routeMap[b.routeId],
                                          driverYear: driverYear,
                                          onTap: () async {
                                            await Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    BookingRequestDetailScreen(
                                                        bookingId: b.id),
                                              ),
                                            );
                                            _load();
                                          },
                                        )),
                                    const SizedBox(height: 16),
                                  ],
                                  if (others.isNotEmpty) ...[
                                    const _SectionLabel('All requests'),
                                    const SizedBox(height: 8),
                                    ...others.map((b) => _RequestCard(
                                          booking: b,
                                          route: _routeMap[b.routeId],
                                          driverYear: driverYear,
                                          onTap: () async {
                                            await Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    BookingRequestDetailScreen(
                                                        bookingId: b.id),
                                              ),
                                            );
                                            _load();
                                          },
                                        )),
                                  ],
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ordinal(int n) {
  if (n == 1) return 'st';
  if (n == 2) return 'nd';
  if (n == 3) return 'rd';
  return 'th';
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.priority = false,
  });

  final String label;
  final bool selected;
  final bool priority;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color activeColor =
        priority ? const Color(0xFFD97706) : const Color(0xFF2563EB);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (priority && selected) ...[
              Icon(Icons.star_rounded, size: 12, color: activeColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? activeColor : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.booking,
    required this.onTap,
    this.route,
    this.driverYear,
  });

  final Booking booking;
  final RoutePost? route;
  final int? driverYear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(booking.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
        child: Row(
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
                  Row(
                    children: [
                      Text(
                        '${booking.isWeekly ? "Weekly" : "Daily"} booking',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (booking.passengerYear != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: booking.passengerYear == driverYear
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (booking.passengerYear == driverYear) ...[
                                const Icon(Icons.star_rounded,
                                    size: 9, color: Color(0xFFD97706)),
                                const SizedBox(width: 2),
                              ],
                              Text(
                                '${booking.passengerYear}${_ordinal(booking.passengerYear!)} yr',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: booking.passengerYear == driverYear
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (route != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.trip_origin_rounded,
                            size: 10, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            route!.startAddress ?? 'Start',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF374151)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 10, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            route!.destination,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF374151)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '${_formatDays(booking.daysSelected)}  ·  LKR ${booking.fareAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusInfo.bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusInfo.color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: Color(0xFF9CA3AF)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDays(List<String> days) {
    if (days.length == 5) return 'Mon–Fri';
    return days
        .map((d) => d[0].toUpperCase() + d.substring(1, 3))
        .join(', ');
  }

  static _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'pending_approval':
        return _StatusInfo(
          label: 'Pending',
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          icon: Icons.pending_actions_rounded,
        );
      case 'pending_payment':
        return _StatusInfo(
          label: 'Awaiting slip',
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
          icon: Icons.receipt_rounded,
        );
      case 'confirmed':
        return _StatusInfo(
          label: 'Confirmed',
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFFF0FDF4),
          icon: Icons.check_circle_rounded,
        );
      case 'declined':
        return _StatusInfo(
          label: 'Declined',
          color: const Color(0xFFEF4444),
          bgColor: const Color(0xFFFEF2F2),
          icon: Icons.cancel_rounded,
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
              const Icon(Icons.inbox_rounded,
                  size: 56, color: Color(0xFFD1D5DB)),
              const SizedBox(height: 14),
              const Text(
                'No booking requests yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Requests from passengers will appear here.',
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
