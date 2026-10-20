import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/grocery_api_service.dart';
import 'grocery_chat_screen.dart';

enum AnnouncementsMode { shopper, requester }

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, required this.mode});

  final AnnouncementsMode mode;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _service = GroceryApiService();
  final _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _accent = Color(0xFFBE185D);
  static const _bgLight = Color(0xFFFCE7F3);

  bool _requesting = false;

  Future<void> _sendRequest(String announcementId) async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final result = await _service.sendRequest(announcementId);
      final chatId = result['chat_id'] as String;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroceryChatScreen(chatId: chatId, isShopper: false),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _closeAnnouncement(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close announcement?'),
        content: const Text(
            'This will remove your announcement from the community feed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.closeAnnouncement(id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isShopperMode = widget.mode == AnnouncementsMode.shopper;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────
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
                      Text(
                        isShopperMode
                            ? 'Your Announcement'
                            : 'Active Shoppers',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        isShopperMode
                            ? 'See who requested items from you'
                            : 'Tap a shopper to request items',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('grocery_announcements')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final now = DateTime.now();

                  // Filter: not expired
                  final active = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final exp = (data['expires_at'] as Timestamp?)?.toDate();
                    return exp != null && exp.isAfter(now);
                  }).toList();

                  // In shopper mode, show only MY announcement
                  final filtered = isShopperMode
                      ? active
                          .where((doc) =>
                              (doc.data() as Map<String, dynamic>)['shopper_id'] ==
                              _myUid)
                          .toList()
                      : active;

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: _bgLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                color: _accent,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              isShopperMode
                                  ? 'Your announcement is live!'
                                  : 'No active shoppers right now',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isShopperMode
                                  ? 'When peers request items, they will appear here.'
                                  : 'Check back soon — when a student heads to the supermarket, you\'ll see them here.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9CA3AF),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final ann = GroceryAnnouncement.fromFirestore(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      );
                      final isOwn = ann.shopperId == _myUid;

                      return _AnnouncementCard(
                        announcement: ann,
                        isOwn: isOwn,
                        isShopperMode: isShopperMode,
                        requesting: _requesting,
                        onRequest: () => _sendRequest(ann.id),
                        onClose: () => _closeAnnouncement(ann.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.isOwn,
    required this.isShopperMode,
    required this.requesting,
    required this.onRequest,
    required this.onClose,
  });

  final GroceryAnnouncement announcement;
  final bool isOwn;
  final bool isShopperMode;
  final bool requesting;
  final VoidCallback onRequest;
  final VoidCallback onClose;

  static const _accent = Color(0xFFBE185D);
  static const _bgLight = Color(0xFFFCE7F3);

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = announcement.shopperName.isNotEmpty
        ? announcement.shopperName[0].toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isOwn
            ? Border.all(color: _accent.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 12,
              offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isOwn ? _accent : _bgLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isOwn ? Colors.white : _accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isOwn ? 'You' : announcement.shopperName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _bgLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _timeAgo(announcement.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              // Supermarket badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 12, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      announcement.supermarket,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (announcement.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              announcement.message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Action buttons ─────────────────────────────────
          if (isOwn)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: requesting ? null : onRequest,
                icon: requesting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text('Request Items'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
