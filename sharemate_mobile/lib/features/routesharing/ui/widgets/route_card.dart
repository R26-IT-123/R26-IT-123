import 'package:flutter/material.dart';

import '../../models/route_post.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.onTap,
  });

  final RoutePost route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = _fairnessColor(route.fairnessLabel);

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // ── Route header ───────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${route.startAddress ?? 'Pickup'} → ${route.destination}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDays(route.travelDays)}  ·  Departs ${route.departureTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Price row ──────────────────────────────────────────
            Row(
              children: [
                // Seats available
                _Chip(
                  icon: Icons.event_seat_rounded,
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

                // Distance
                if (route.totalDistanceKm != null)
                  _Chip(
                    icon: Icons.straighten_rounded,
                    label:
                        '${route.totalDistanceKm!.toStringAsFixed(1)} km',
                    color: const Color(0xFFF3F4F6),
                    textColor: const Color(0xFF6B7280),
                  ),

                const Spacer(),

                // Price + fairness label
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'LKR ${route.pricePerTrip.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (route.fairnessLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: labelColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          route.fairnessLabel!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ── Driver year badge ──────────────────────────────────
            if (route.driverYear != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_rounded,
                            size: 11, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          '${route.driverYear}${_ordinal(route.driverYear!)} year driver',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // ── Published date ─────────────────────────────────────
            if (route.createdAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 11, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    'Published ${_formatPublished(route.createdAt!)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ],

            // ── Rating / summary ───────────────────────────────────
            if (route.aiSummary != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (route.avgRating != null) ...[
                    const Icon(Icons.star_rounded,
                        size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text(
                      route.avgRating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      '"${route.aiSummary!}"',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _ordinal(int n) {
    if (n == 1) return 'st';
    if (n == 2) return 'nd';
    if (n == 3) return 'rd';
    return 'th';
  }

  static String _formatPublished(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() > 1 ? "s" : ""} ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _formatDays(List<String> days) {
    if (days.length == 5 &&
        days.toSet().containsAll(['mon', 'tue', 'wed', 'thu', 'fri'])) {
      return 'Mon–Fri';
    }
    return days.map((d) => d[0].toUpperCase() + d.substring(1, 3)).join(', ');
  }

  static Color _fairnessColor(String? label) {
    switch (label) {
      case 'Fair Price':
        return const Color(0xFF16A34A);
      case 'Above Average':
        return const Color(0xFFD97706);
      case 'High Price':
        return const Color(0xFFEF4444);
      case 'Below Average':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
