import 'package:flutter/material.dart';

import '../services/routesharing_api_service.dart';

class DriverFeedbackScreen extends StatefulWidget {
  const DriverFeedbackScreen({
    super.key,
    required this.profile,
    required this.driverId,
  });

  final Map<String, dynamic> profile;
  final String driverId;

  @override
  State<DriverFeedbackScreen> createState() => _DriverFeedbackScreenState();
}

class _DriverFeedbackScreenState extends State<DriverFeedbackScreen> {
  final _api = RouteSharingApiService();

  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _aiSummary;

  @override
  void initState() {
    super.initState();
    _aiSummary = widget.profile['ai_summary'] as String?;
    _loadEntriesAndRefreshSummary();
  }

  Future<void> _loadEntriesAndRefreshSummary() async {
    try {
      final entries = await _api.getDriverFeedbackEntries(widget.driverId);
      if (mounted) setState(() => _entries = entries);

      // Auto-regenerate summary from all comments whenever screen opens
      if (entries.isNotEmpty) {
        setState(() => _refreshing = true);
        await _api.refreshDriverSummary(widget.driverId);
        final updated = await _api.getDriverRatingProfile(widget.driverId);
        if (mounted) {
          setState(() => _aiSummary = updated['ai_summary'] as String?);
        }
      }
    } catch (_) {
      // silent — show whatever summary we already have
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _refreshSummary() async {
    setState(() => _refreshing = true);
    try {
      await _api.refreshDriverSummary(widget.driverId);
      final updated = await _api.getDriverRatingProfile(widget.driverId);
      if (mounted) {
        setState(() => _aiSummary = updated['ai_summary'] as String?);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh summary.')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avgRating =
        (widget.profile['overall_avg_rating'] as num?)?.toDouble() ?? 0;
    final totalRides =
        (widget.profile['total_rides'] as num?)?.toInt() ?? 0;
    final latestSummary = _aiSummary;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF374151)),
                  ),
                  const Text(
                    'Passenger Feedback',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD97706)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Average rating hero ─────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 28, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  totalRides > 0
                                      ? avgRating.toStringAsFixed(1)
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFD97706),
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < avgRating.round()
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 28,
                                      color: const Color(0xFFD97706),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  totalRides > 0
                                      ? '$totalRides ride${totalRides == 1 ? '' : 's'} · ${_entries.length} rating${_entries.length == 1 ? '' : 's'}'
                                      : 'No feedback yet',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),

                          // ── AI summary ──────────────────────────
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: const Color(0xFFE0E7FF)),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 15,
                                        color: Color(0xFF6366F1)),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'AI-generated summary',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: _refreshing
                                          ? null
                                          : _refreshSummary,
                                      child: _refreshing
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    Color(0xFF6366F1),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.refresh_rounded,
                                              size: 16,
                                              color: Color(0xFF6366F1)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  latestSummary ??
                                      'Tap refresh to generate an AI summary from all passenger comments.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: latestSummary != null
                                        ? const Color(0xFF374151)
                                        : const Color(0xFF9CA3AF),
                                    fontStyle: FontStyle.italic,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Individual entries ──────────────────
                          if (_entries.isEmpty) ...[
                            const SizedBox(height: 32),
                            const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded,
                                      size: 48,
                                      color: Color(0xFFD1D5DB)),
                                  SizedBox(height: 12),
                                  Text(
                                    'No feedback received yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Passenger feedback will appear here\nafter completed rides.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF9CA3AF)),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 20),
                            Text(
                              'All feedback (${_entries.length})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._entries.map((e) => _EntryCard(entry: e)),
                          ],

                          const SizedBox(height: 24),
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final rating = (entry['overall_rating'] as num?)?.toDouble() ?? 0;
    final comment = entry['comment'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Star rating row
          Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < rating.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 18,
                  color: const Color(0xFFD97706),
                );
              }),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Passenger comment
          Text(
            comment,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
