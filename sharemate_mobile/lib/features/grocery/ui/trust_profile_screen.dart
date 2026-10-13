import 'package:flutter/material.dart';

import '../models/trust_profile.dart';
import '../services/grocery_api_service.dart';

class TrustProfileScreen extends StatefulWidget {
  const TrustProfileScreen({
    super.key,
    required this.uid,
    required this.displayName,
  });

  final String uid;
  final String displayName;

  @override
  State<TrustProfileScreen> createState() => _TrustProfileScreenState();
}

class _TrustProfileScreenState extends State<TrustProfileScreen> {
  final _service = GroceryApiService();
  TrustProfile? _profile;
  bool _loading = true;
  String? _error;

  static const _accent = Color(0xFFBE185D);
  static const _gold   = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _service.getTrustProfile(widget.uid);
      if (mounted) setState(() { _profile = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // App bar
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.displayName,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                        ),
                        const Text(
                          'Trust Profile',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: _accent)))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
            else
              Expanded(child: _buildBody(_profile!)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TrustProfile p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── Overall score card ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: p.hasAnyData ? _buildScoreContent(p) : _buildEmpty(),
          ),

          if (p.hasAnyData) ...[

            // ── Split scores ─────────────────────────────────────────
            if (p.shopperCount > 0 || p.requesterCount > 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (p.shopperCount > 0)
                    Expanded(child: _SplitCard(
                      label: 'As Shopper',
                      icon: Icons.shopping_cart_rounded,
                      avg: p.shopperAvg,
                      count: p.shopperCount,
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFEDE9FE),
                    )),
                  if (p.shopperCount > 0 && p.requesterCount > 0) const SizedBox(width: 12),
                  if (p.requesterCount > 0)
                    Expanded(child: _SplitCard(
                      label: 'As Requester',
                      icon: Icons.shopping_basket_rounded,
                      avg: p.requesterAvg,
                      count: p.requesterCount,
                      color: const Color(0xFF059669),
                      bgColor: const Color(0xFFD1FAE5),
                    )),
                ],
              ),
            ],

            // ── Badges ───────────────────────────────────────────────
            if (p.badges.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Earned badges',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: p.badges.map((b) => _BadgePill(badge: b)).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // ── Bar chart ────────────────────────────────────────────
            if (p.recentRatings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Rating trend',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        const SizedBox(width: 6),
                        Text('(last ${p.recentRatings.length} trips)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _BarChart(ratings: p.recentRatings),
                  ],
                ),
              ),
            ],

            // ── Comments ─────────────────────────────────────────────
            if (p.recentRatings.any((r) => r.comment.isNotEmpty)) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What peers say',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 12),
                    ...p.recentRatings
                        .where((r) => r.comment.isNotEmpty)
                        .map((r) => _CommentCard(rating: r)),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildScoreContent(TrustProfile p) {
    return Column(
      children: [
        const Icon(Icons.verified_rounded, color: _accent, size: 28),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              p.totalRatings > 0 ? p.avgRating.toStringAsFixed(1) : '—',
              style: const TextStyle(
                fontSize: 52, fontWeight: FontWeight.w900, color: Color(0xFF111827), height: 1),
            ),
            if (p.totalRatings > 0)
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 4),
                child: Text('/ 5',
                    style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (p.totalRatings > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Icon(
              i < p.avgRating.floor()
                  ? Icons.star_rounded
                  : (i < p.avgRating ? Icons.star_half_rounded : Icons.star_outline_rounded),
              color: _gold, size: 20,
            )),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          p.totalRatings > 0
              ? '${p.totalRatings} ${p.totalRatings == 1 ? 'rating' : 'ratings'}'
              : 'No ratings yet',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF0369A1)),
              const SizedBox(width: 6),
              Text(
                '${p.completedTrips} completed ${p.completedTrips == 1 ? 'trip' : 'trips'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Column(
      children: [
        const Icon(Icons.star_outline_rounded, color: Color(0xFFD1D5DB), size: 40),
        const SizedBox(height: 12),
        Text(
          'No activity yet',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.displayName} hasn\'t completed any grocery trips yet.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Split score card ──────────────────────────────────────────────────────────

class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.label,
    required this.icon,
    required this.avg,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final IconData icon;
  final double avg;
  final int count;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            avg.toStringAsFixed(1),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color, height: 1),
          ),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.star_rounded, size: 12, color: const Color(0xFFF59E0B)),
            const SizedBox(width: 3),
            Text(
              '$count ${count == 1 ? 'rating' : 'ratings'}',
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Badge pill ────────────────────────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.badge});
  final String badge;

  static const _badges = {
    'reliable_shopper': (
      icon: Icons.local_shipping_rounded,
      label: 'Reliable Shopper',
      color: Color(0xFF059669),
      bg: Color(0xFFD1FAE5),
    ),
    'trusted_payer': (
      icon: Icons.payments_rounded,
      label: 'Trusted Payer',
      color: Color(0xFF0369A1),
      bg: Color(0xFFE0F2FE),
    ),
    'community_helper': (
      icon: Icons.volunteer_activism_rounded,
      label: 'Community Helper',
      color: Color(0xFF7C3AED),
      bg: Color(0xFFEDE9FE),
    ),
    'top_rated': (
      icon: Icons.workspace_premium_rounded,
      label: 'Top Rated',
      color: Color(0xFFB45309),
      bg: Color(0xFFFEF3C7),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _badges[badge];
    if (meta == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: meta.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 15, color: meta.color),
          const SizedBox(width: 6),
          Text(meta.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: meta.color)),
        ],
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({required this.ratings});
  final List<TrustRating> ratings;

  static const _gold   = Color(0xFFF59E0B);
  static const _accent = Color(0xFFBE185D);

  @override
  Widget build(BuildContext context) {
    final ordered = ratings.reversed.toList();
    const maxH = 80.0;

    return Column(
      children: [
        SizedBox(
          height: maxH + 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ordered.asMap().entries.map((e) {
              final isNewest = e.key == ordered.length - 1;
              final barH = (e.value.rating / 5) * maxH;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${e.value.rating}',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: isNewest ? _accent : const Color(0xFF9CA3AF),
                      )),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: barH.clamp(6.0, maxH),
                    decoration: BoxDecoration(
                      color: isNewest ? _accent : _gold.withValues(alpha: 0.55 + e.key * 0.045),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Oldest', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            Text('Newest', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ),
      ],
    );
  }
}

// ── Comment card ─────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.rating});
  final TrustRating rating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(5, (i) => Icon(
                i < rating.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFF59E0B), size: 14,
              )),
            ),
            const SizedBox(height: 6),
            Text(rating.comment,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4)),
          ],
        ),
      ),
    );
  }
}
