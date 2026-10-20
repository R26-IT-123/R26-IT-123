import 'package:flutter/material.dart';

import '../services/flts_api_service.dart';

class BusFeedbackScreen extends StatefulWidget {
  const BusFeedbackScreen({super.key, required this.vehicleNumber});

  final String vehicleNumber;

  @override
  State<BusFeedbackScreen> createState() => _BusFeedbackScreenState();
}

class _BusFeedbackScreenState extends State<BusFeedbackScreen> {
  final FltsApiService _api = FltsApiService();

  late Future<List<Map<String, dynamic>>> _feedbackFuture;

  @override
  void initState() {
    super.initState();
    _feedbackFuture = _api.fetchFeedback(vehicleNumber: widget.vehicleNumber);
  }

  Future<void> _refresh() async {
    setState(() {
      _feedbackFuture =
          _api.fetchFeedback(vehicleNumber: widget.vehicleNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF111827),
                      size: 18,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bus Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          widget.vehicleNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
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
            ),

            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _feedbackFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF24AE59),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: Color(0xFFD1D5DB),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not load feedback',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Check your connection and try again',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF24AE59),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  return RefreshIndicator(
                    color: const Color(0xFF24AE59),
                    onRefresh: _refresh,
                    child: items.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.6,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.rate_review_outlined,
                                      size: 56,
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No feedback yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Be the first to rate ${widget.vehicleNumber}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _SummaryCard(
                                vehicleNumber: widget.vehicleNumber,
                                items: items,
                              ),
                              const SizedBox(height: 16),
                              ...items.map(
                                (item) => _FeedbackCard(item: item),
                              ),
                            ],
                          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.vehicleNumber, required this.items});

  final String vehicleNumber;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (final item in items) {
      total += (item['rating'] as num?)?.toDouble() ?? 0;
    }
    final avg = items.isNotEmpty ? total / items.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avg.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 18,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${items.length} review${items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_bus_rounded,
                    color: Color(0xFF16A34A),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      vehicleNumber,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback Card
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final rating = (item['rating'] as num?)?.toInt() ?? 0;
    final type = item['type'] as String? ?? '';
    final comment = item['comment'] as String? ?? '';
    final displayName = item['display_name'] as String? ?? 'Student';
    final tsStr = item['timestamp'] as String?;
    final timeText = tsStr != null ? _timeAgo(DateTime.parse(tsStr)) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (timeText.isNotEmpty)
                      Text(
                        timeText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                type,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
