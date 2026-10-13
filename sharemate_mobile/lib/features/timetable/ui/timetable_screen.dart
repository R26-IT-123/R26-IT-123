import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/timetable_entry.dart';
import '../services/timetable_api_service.dart';

const _accent = Color(0xFF7C3AED);

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _api = TimetableApiService();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  late Future<List<TimetableEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchTimetables();
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _future = _api.fetchTimetables(
        origin: _originCtrl.text.trim(),
        destination: _destCtrl.text.trim(),
      );
    });
  }

  void _clear() {
    _originCtrl.clear();
    _destCtrl.clear();
    setState(() => _future = _api.fetchTimetables());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
                  const Expanded(
                    child: Text(
                      'Bus Timetable',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ISLANDWIDE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: _originCtrl,
                          hint: 'From (e.g. Colombo)',
                          icon: Icons.trip_origin_rounded,
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SearchField(
                          controller: _destCtrl,
                          hint: 'To (e.g. Kandy)',
                          icon: Icons.location_on_rounded,
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _search,
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text('Search'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _clear,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Source attribution ──────────────────────────────────
            Container(
              width: double.infinity,
              color: const Color(0xFFF3F4F6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'Sri Lanka bus schedules · sourced from bustimetable.lk, refreshed daily.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ),

            // ── Results ────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<TimetableEntry>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }
                  if (snapshot.hasError) {
                    final message = snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : 'Could not load the timetable.';
                    return _MessageView(
                      icon: Icons.error_outline_rounded,
                      iconColor: const Color(0xFFEF4444),
                      message: message,
                    );
                  }
                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return const _MessageView(
                      icon: Icons.schedule_rounded,
                      iconColor: Color(0xFFD1D5DB),
                      message: 'No matching routes found.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _TimetableCard(entry: entries[index]),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _TimetableCard extends StatelessWidget {
  const _TimetableCard({required this.entry});

  final TimetableEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: entry.routeNumber.isEmpty
                ? const Icon(Icons.directions_bus_rounded,
                    size: 20, color: _accent)
                : Text(
                    entry.routeNumber,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.origin}  →  ${entry.destination}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(label: entry.operator, color: const Color(0xFF2563EB)),
                    _Tag(label: entry.busType, color: const Color(0xFF16A34A)),
                  ],
                ),
                if ((entry.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.notes!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.departureTime,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.isFrequent ? entry.intervalNote! : 'First departure',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.iconColor,
    required this.message,
  });

  final IconData icon;
  final Color iconColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
