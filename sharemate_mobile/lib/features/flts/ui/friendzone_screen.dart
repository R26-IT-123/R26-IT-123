import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/bus_route.dart';

class FriendZoneScreen extends StatelessWidget {
  const FriendZoneScreen({
    super.key,
    required this.route,
  });

  final BusRoute route;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF111827),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FriendZone',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              '${route.origin} → ${route.destination}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'FLTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16A34A),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('live_gps')
            .where('routeId', isEqualTo: route.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF24AE59)),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          final docs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              // ── Live count banner ────────────────────────────────
              _LiveCountBanner(count: docs.length),

              // ── Member list or empty state ───────────────────────
              Expanded(
                child: docs.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final userId =
                              data['userId']?.toString() ?? '';
                          final isMe = userId == currentUserId;

                          return _MemberCard(
                            displayName:
                                data['displayName']?.toString() ?? 'Student',
                            timestamp:
                                data['timestamp'] as Timestamp?,
                            isMe: isMe,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Count Banner
// ─────────────────────────────────────────────────────────────────────────────

class _LiveCountBanner extends StatelessWidget {
  const _LiveCountBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count == 0
                ? 'No students sharing right now'
                : '$count student${count == 1 ? '' : 's'} sharing live on this route',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member Card
// ─────────────────────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.displayName,
    required this.timestamp,
    required this.isMe,
  });

  final String displayName;
  final Timestamp? timestamp;
  final bool isMe;

  String _sharingDuration() {
    if (timestamp == null) return 'Just joined';
    final diff = DateTime.now().difference(timestamp!.toDate());
    if (diff.inSeconds < 60) return 'Just joined';
    if (diff.inMinutes < 60) {
      return 'Sharing since ${diff.inMinutes} min ago';
    }
    return 'Sharing since ${diff.inHours}h ago';
  }

  String get _initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'S';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFFF0FDF4)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFF3F4F6),
        ),
      ),
      child: Row(
        children: [
          // ── Avatar ─────────────────────────────────────────────
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF24AE59)
                      : const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isMe
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
              // Live dot
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // ── Name + duration ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? 'You' : displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF24AE59),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _sharingDuration(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // ── Live indicator ─────────────────────────────────────
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.group_outlined,
                size: 38,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No one on this route yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first — tap "I\'m on this bus"\non the map to start sharing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load FriendZone',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
