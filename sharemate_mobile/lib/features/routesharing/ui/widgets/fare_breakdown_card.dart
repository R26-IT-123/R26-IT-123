import 'package:flutter/material.dart';

import '../../models/booking.dart';

class FareBreakdownCard extends StatelessWidget {
  const FareBreakdownCard({super.key, required this.fare});

  final FareBreakdown fare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              const Text(
                'Fare Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fare.isUpfront
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fare.isUpfront ? 'Pay upfront' : 'Pay after ride',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fare.isUpfront
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (fare.routeDistanceKm != null) ...[
            _Row('Route distance',
                '${fare.routeDistanceKm!.toStringAsFixed(1)} km'),
            if (fare.pricePerKm != null)
              _Row('Price per km',
                  'LKR ${fare.pricePerKm!.toStringAsFixed(1)}/km'),
            const Divider(height: 20, color: Color(0xFFFDE68A)),
          ],
          if (fare.passengerBoardingLabel != null)
            _Row('Your boarding', fare.passengerBoardingLabel!,
                valueColor: const Color(0xFFD97706)),
          _Row('Price per trip', 'LKR ${fare.pricePerTrip.toStringAsFixed(0)}'),
          _Row('Days selected', '${fare.daysCount} day${fare.daysCount == 1 ? '' : 's'}'),
          if (fare.hasDiscount) ...[
            _Row(
              'Weekly discount (${fare.discountPct.toStringAsFixed(0)}%)',
              '− LKR ${fare.discountAmount.toStringAsFixed(0)}',
              valueColor: const Color(0xFF16A34A),
            ),
          ],
          const Divider(height: 20, color: Color(0xFFFDE68A)),
          _Row(
            fare.combinedTotal != null ? 'Your seat total' : 'Total payable',
            'LKR ${fare.totalFare.toStringAsFixed(0)}',
            bold: true,
          ),
          if (fare.combinedTotal != null) ...[
            const SizedBox(height: 6),
            if (fare.friendBoardingLabel != null)
              _Row("Friend's boarding", fare.friendBoardingLabel!,
                  valueColor: const Color(0xFFD97706)),
            if (fare.friendPricePerTrip != null)
              _Row("Friend's price/trip",
                  'LKR ${fare.friendPricePerTrip!.toStringAsFixed(0)}'),
            _Row("Friend's seat total",
                'LKR ${fare.friendSeatSubtotal!.toStringAsFixed(0)}'),
            const Divider(height: 20, color: Color(0xFFFDE68A)),
            _Row('Combined total', 'LKR ${fare.combinedTotal!.toStringAsFixed(0)}',
                bold: true),
          ],
          if (fare.savingVsPickme != null && fare.savingVsPickme! > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded,
                      size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Saving ~LKR ${fare.savingVsPickme!.toStringAsFixed(0)} vs PickMe/Uber',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value,
      {this.bold = false, this.valueColor});

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ??
                    (bold ? const Color(0xFF111827) : const Color(0xFF374151)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
