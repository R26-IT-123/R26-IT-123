import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/route_post.dart';
import '../services/routesharing_api_service.dart';
import 'booking_screen.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({super.key, required this.route});

  final RoutePost route;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final _api = RouteSharingApiService();
  PricingSuggestion? _pricing;
  bool _loadingPricing = true;

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      final p = await _api.getRoutePricing(widget.route.id);
      if (mounted) setState(() => _pricing = p);
    } on ApiException {
      // pricing optional — just hide the section
    } finally {
      if (mounted) setState(() => _loadingPricing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final p = _pricing;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────────
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
                    'Route Details',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Route header card ──────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.directions_car_rounded,
                                  color: Color(0xFFD97706),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      route.destination,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      'From ${route.startAddress ?? 'Pickup point'}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(
                              height: 1, color: Color(0xFFF3F4F6)),
                          const SizedBox(height: 16),
                          _DetailRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'Travel days',
                              value: _formatDays(route.travelDays)),
                          _DetailRow(
                              icon: Icons.access_time_rounded,
                              label: 'Departure',
                              value: route.departureTime),
                          _DetailRow(
                              icon: Icons.event_seat_rounded,
                              label: 'Seats available',
                              value:
                                  '${route.seatsAvailable} of ${route.totalSeats}'),
                          if (route.totalDistanceKm != null)
                            _DetailRow(
                                icon: Icons.straighten_rounded,
                                label: 'Distance',
                                value:
                                    '${route.totalDistanceKm!.toStringAsFixed(1)} km'),
                          if (route.driverName != null)
                            _DetailRow(
                                icon: Icons.person_rounded,
                                label: 'Driver',
                                value: route.driverName!),
                          if (route.avgRating != null)
                            _DetailRow(
                                icon: Icons.star_rounded,
                                label: 'Rating',
                                value:
                                    '${route.avgRating!.toStringAsFixed(1)} / 5.0'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Pricing card ───────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pricing',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'LKR ${route.pricePerTrip.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              const Text(
                                ' / trip',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              const Spacer(),
                              if (route.fairnessLabel != null)
                                _FairnessChip(
                                    label: route.fairnessLabel!),
                            ],
                          ),
                          if (route.pricePerKm != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'LKR ${route.pricePerKm!.toStringAsFixed(1)} per km',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                          if (!_loadingPricing && p != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFFDE68A)),
                              ),
                              child: Column(
                                children: [
                                  _CompareRow(
                                    label: 'Platform suggested range',
                                    value:
                                        'LKR ${p.suggestedMinFare.toStringAsFixed(0)} – ${p.suggestedMaxFare.toStringAsFixed(0)}',
                                  ),
                                  const SizedBox(height: 6),
                                  _CompareRow(
                                    label: 'PickMe / Uber equivalent',
                                    value:
                                        '~LKR ${p.pickmeEquivalent.toStringAsFixed(0)}',
                                    valueColor:
                                        const Color(0xFFEF4444),
                                  ),
                                  const SizedBox(height: 6),
                                  _CompareRow(
                                    label: 'You save vs. PickMe',
                                    value:
                                        '~LKR ${(p.pickmeEquivalent - route.pricePerTrip).toStringAsFixed(0)}',
                                    valueColor:
                                        const Color(0xFF16A34A),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── AI summary ─────────────────────────────────
                    if (route.aiSummary != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 15,
                                    color: Color(0xFF7C3AED)),
                                SizedBox(width: 6),
                                Text(
                                  'Passenger feedback summary',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              route.aiSummary!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Book button ────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: route.seatsAvailable > 0
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  BookingScreen(route: route),
                            ),
                          )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Text(route.seatsAvailable > 0
                      ? 'Book a Seat'
                      : 'No Seats Available'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDays(List<String> days) {
    if (days.length == 5 &&
        days.toSet().containsAll(['mon', 'tue', 'wed', 'thu', 'fri'])) {
      return 'Mon – Fri (full week)';
    }
    return days.map((d) => d[0].toUpperCase() + d.substring(1, 3)).join(', ');
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              )),
        ],
      ),
    );
  }
}

class _FairnessChip extends StatelessWidget {
  const _FairnessChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _color(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static Color _color(String label) {
    switch (label) {
      case 'Fair Price':
        return const Color(0xFF16A34A);
      case 'Above Average':
        return const Color(0xFFD97706);
      case 'High Price':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF2563EB);
    }
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF92400E))),
        Text(value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF92400E),
            )),
      ],
    );
  }
}
