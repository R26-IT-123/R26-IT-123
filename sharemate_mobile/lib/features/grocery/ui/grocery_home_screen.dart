import 'package:flutter/material.dart';

import 'announcements_screen.dart';
import 'browse_item_requests_screen.dart';
import 'grocery_notification_bell.dart';
import 'my_chats_screen.dart';
import 'post_announcement_screen.dart';
import 'post_item_request_screen.dart';

class GroceryHomeScreen extends StatelessWidget {
  const GroceryHomeScreen({super.key});

  static const _accent = Color(0xFFBE185D);
  static const _bgLight = Color(0xFFFCE7F3);
  static const _gradStart = Color(0xFF9D174D);
  static const _gradEnd = Color(0xFFBE185D);

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
                              color: _bgLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SHOP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Grocery',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Community store pickups',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const GroceryNotificationBell(),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const MyChatsScreen()),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        color: _accent, size: 22),
                    tooltip: 'My chats',
                  ),
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
                          colors: [_gradStart, _gradEnd],
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
                              'Community grocery shopping',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Help your peers.\nGet help in return.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Students going to the supermarket pick up items for those who cannot.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'What would you like to do?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Going to Market ────────────────────────────
                    _OptionCard(
                      icon: Icons.storefront_rounded,
                      title: 'Going to Market',
                      subtitle:
                          'Let your peers know you\'re heading to a supermarket. They can send you their lists.',
                      accent: _accent,
                      bgColor: _bgLight,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PostAnnouncementScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── I Need Items ───────────────────────────────
                    _OptionCard(
                      icon: Icons.shopping_basket_rounded,
                      title: 'I Need Items',
                      subtitle:
                          'See who is at a supermarket right now and request them to pick up your items.',
                      accent: const Color(0xFF0369A1),
                      bgColor: const Color(0xFFE0F2FE),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const AnnouncementsScreen(mode: AnnouncementsMode.requester),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Post My Needs ──────────────────────────────
                    _OptionCard(
                      icon: Icons.edit_note_rounded,
                      title: 'Post My Needs',
                      subtitle:
                          'Post the items you need. Any shopper heading to that supermarket can offer to help.',
                      accent: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFEDE9FE),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PostItemRequestScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Help Someone ───────────────────────────────
                    _OptionCard(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'Help Someone',
                      subtitle:
                          'Going shopping? Browse open item requests from peers and offer to pick up their items.',
                      accent: const Color(0xFF059669),
                      bgColor: const Color(0xFFD1FAE5),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BrowseItemRequestsScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── How it works ───────────────────────────────
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
                          const _HowStep(
                              num: '1',
                              text:
                                  'A student going to the supermarket posts an announcement.'),
                          const _HowStep(
                              num: '2',
                              text:
                                  'Other students tap to request items from that shopper.'),
                          const _HowStep(
                              num: '3',
                              text:
                                  'A private chat opens — the requester sends their item list.'),
                          const _HowStep(
                              num: '4',
                              text:
                                  'After shopping, the shopper adds the bill in the chat.'),
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
              color: Color(0xFFFCE7F3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFBE185D),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}
