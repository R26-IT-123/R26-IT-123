import 'package:flutter/material.dart';

import 'driver_dashboard_screen.dart';
import 'route_notification_bell.dart';
import 'route_search_screen.dart';

class RouteSharingHomeScreen extends StatelessWidget {
  const RouteSharingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF374151)),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'RIDE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Route Sharing',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Weekly commitment-based ride sharing',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const RouteNotificationBell(),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // ── Hero banner ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Not just a ride — a commitment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Share your weekly\ncommute with SLIIT peers.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cheaper than PickMe/Uber. Fixed schedule. Reserved seat.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'I want to…',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Book a Seat ────────────────────────────────
                    _OptionCard(
                      icon: Icons.search_rounded,
                      title: 'Book a Seat',
                      subtitle:
                          'Find drivers going your way. Book daily or weekly — cancel-free.',
                      accent: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RouteSearchScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Vehicle Sharing ────────────────────────────
                    _OptionCard(
                      icon: Icons.directions_car_rounded,
                      title: 'Vehicle Sharing',
                      subtitle:
                          'Publish your weekly route, manage bookings and earn back fuel costs.',
                      accent: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFEF3C7),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DriverDashboardScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── How it works strip ─────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How it works',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _HowStep(
                              num: '1',
                              text:
                                  'Driver publishes weekly route with price.'),
                          _HowStep(
                              num: '2',
                              text:
                                  'Passenger books daily or full-week seat.'),
                          _HowStep(
                              num: '3',
                              text:
                                  'Weekly bookers pay upfront. Daily bookers pay after each ride.'),
                          _HowStep(
                              num: '4',
                              text:
                                  'Driver approves booking. Seat reserved.'),
                          const _HowStep(
                              num: '5',
                              text:
                                  'Track driver live on ride day.'),
                        ],
                      ),
                    ),
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accent),
          ],
        ),
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.num, required this.text});

  final String num;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}
