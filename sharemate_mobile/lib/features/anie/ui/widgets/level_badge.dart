import 'package:flutter/material.dart';

class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.large = false});

  final String level;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (level) {
      'Advanced' => (const Color(0xFF166534), const Color(0xFFDCFCE7)),
      'Medium'   => (const Color(0xFF92400E), const Color(0xFFFEF3C7)),
      _          => (const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 8,
        vertical:   large ? 6  : 3,
      ),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(large ? 10 : 6),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize:   large ? 13 : 10,
          fontWeight: FontWeight.w700,
          color:      color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
