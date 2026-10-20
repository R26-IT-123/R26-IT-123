import 'package:flutter/material.dart';

import '../../models/route_post.dart';

class BoardingSelector extends StatelessWidget {
  const BoardingSelector({
    super.key,
    required this.title,
    required this.waypoints,
    required this.selected,
    required this.pricePerTrip,
    required this.onChanged,
  });

  final String title;
  final List<Waypoint> waypoints;
  final Waypoint? selected; // null = full route
  final double pricePerTrip;
  final ValueChanged<Waypoint?> onChanged;

  double _price(Waypoint? stop) {
    if (stop == null || waypoints.isEmpty) return pricePerTrip;
    final remaining = waypoints.length + 1 - stop.order;
    return pricePerTrip * remaining / (waypoints.length + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select where you will board the vehicle.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 12),

          // Full route option
          _BoardingOption(
            label: 'Full route',
            sublabel: 'Board at start location',
            price: pricePerTrip,
            isSelected: selected == null,
            onTap: () => onChanged(null),
          ),

          // Waypoint options
          ...waypoints.map((wp) => _BoardingOption(
                label: 'Stop ${wp.order}',
                sublabel: wp.address,
                price: _price(wp),
                isSelected: selected?.order == wp.order,
                onTap: () => onChanged(wp),
              )),
        ],
      ),
    );
  }
}

class _BoardingOption extends StatelessWidget {
  const _BoardingOption({
    required this.label,
    required this.sublabel,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final double price;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFFBEB)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD97706)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFD97706)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFFD97706)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF92400E)
                          : const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              'LKR ${price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? const Color(0xFFD97706)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
