import 'package:flutter/material.dart';

class UploaderAvatar extends StatelessWidget {
  const UploaderAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 10,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius:          radius,
        backgroundColor: const Color(0xFFDBEAFE),
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return CircleAvatar(
      radius:          radius,
      backgroundColor: const Color(0xFFDBEAFE),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize:   radius * 0.85,
          fontWeight: FontWeight.w800,
          color:      const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}
