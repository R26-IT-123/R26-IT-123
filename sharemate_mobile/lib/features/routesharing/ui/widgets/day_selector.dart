import 'package:flutter/material.dart';

class RouteDateSlot {
  const RouteDateSlot({
    required this.dayKey,
    required this.dayName,
    required this.date,
  });

  final String dayKey; // 'mon', 'tue', etc.
  final String dayName; // 'Mon', 'Tue', etc.
  final DateTime date;
}

const _monthAbbr = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.slots,
    required this.selected,
    required this.onChanged,
  });

  final List<RouteDateSlot> slots;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Text(
        'No upcoming dates available for this route.',
        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = selected.contains(slot.dayKey);

        return GestureDetector(
          onTap: () {
            final next = Set<String>.from(selected);
            if (isSelected) {
              next.remove(slot.dayKey);
            } else {
              next.add(slot.dayKey);
            }
            onChanged(next);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 68,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD97706)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD97706)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot.dayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFFD97706),
                  ),
                ),
                Text(
                  '${slot.date.day}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFFD97706),
                    height: 1.1,
                  ),
                ),
                Text(
                  _monthAbbr[slot.date.month],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white70
                        : const Color(0xFFD97706).withValues(alpha: 0.7),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 2),
                  const Icon(Icons.check_circle_rounded,
                      size: 10, color: Colors.white),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
