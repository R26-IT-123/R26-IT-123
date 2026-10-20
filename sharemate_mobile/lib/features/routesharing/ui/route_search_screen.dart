import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/route_post.dart';
import '../services/routesharing_api_service.dart';
import 'my_bookings_screen.dart';
import 'route_detail_screen.dart';
import 'widgets/route_card.dart';

class RouteSearchScreen extends StatefulWidget {
  const RouteSearchScreen({super.key});

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final _api = RouteSharingApiService();
  final _searchCtrl = TextEditingController();

  List<RoutePost> _routes = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _api.searchRoutes(
        destination: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
      );
      setState(() {
        _routes = results;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load routes.';
        _loading = false;
      });
    }
  }

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
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF374151)),
                  ),
                  const Text(
                    'Find a Ride',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyBookingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.bookmark_rounded,
                        size: 16, color: Color(0xFFD97706)),
                    label: const Text(
                      'My Bookings',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search bar ────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search destination or start place…',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF9CA3AF)),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _search,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),

            // ── Results ───────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD97706),
                      ),
                    )
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _search)
                      : _routes.isEmpty
                          ? _EmptyView(onRetry: _search)
                          : RefreshIndicator(
                              color: const Color(0xFFD97706),
                              onRefresh: _search,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 16, 16, 24),
                                itemCount: _routes.length,
                                itemBuilder: (_, i) => RouteCard(
                                  route: _routes[i],
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => RouteDetailScreen(
                                          route: _routes[i]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car_outlined,
                  size: 56, color: Color(0xFFD1D5DB)),
              const SizedBox(height: 14),
              const Text(
                'No rides available right now',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Check back later or try a different destination or start place.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFD97706)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
}
