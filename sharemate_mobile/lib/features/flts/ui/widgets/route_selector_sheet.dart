import 'package:flutter/material.dart';

import '../../models/bus_route.dart';
import '../../services/flts_api_service.dart';

/// Modal bottom sheet for selecting a bus route.
///
/// Usage:
/// ```dart
/// final route = await RouteSelectorSheet.show(context);
/// ```
/// Returns the selected [BusRoute] or null if dismissed.
class RouteSelectorSheet extends StatefulWidget {
  const RouteSelectorSheet({super.key});

  static Future<BusRoute?> show(BuildContext context) {
    return showModalBottomSheet<BusRoute>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RouteSelectorSheet(),
    );
  }

  @override
  State<RouteSelectorSheet> createState() => _RouteSelectorSheetState();
}

class _RouteSelectorSheetState extends State<RouteSelectorSheet> {
  late final Future<List<BusRoute>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = FltsApiService().fetchRoutes();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.90,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ─────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'FLTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Select your route',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose the bus route you are currently on',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFFF3F4F6), thickness: 1),

              // ── Route list ──────────────────────────────────────────
              Expanded(
                child: FutureBuilder<List<BusRoute>>(
                  future: _routesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF16A34A),
                        ),
                      );
                    }
                    // On error fall back to hardcoded list so the app still works,
                    // but tell the user the live/active-passenger data may be stale.
                    final hasError = snapshot.hasError || !snapshot.hasData;
                    final routes =
                        hasError ? BusRoute.sliitRoutes : snapshot.data!;
                    return Column(
                      children: [
                        if (hasError) _buildOfflineBanner(),
                        Expanded(
                          child: _buildRouteList(scrollController, routes),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Color(0xFFB45309), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Couldn't reach the server — showing saved routes. "
              'Active student counts may be out of date.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteList(
    ScrollController scrollController,
    List<BusRoute> routes,
  ) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final route = routes[index];
        return _RouteItem(
          route: route,
          onTap: () => Navigator.of(context).pop(route),
        );
      },
    );
  }
}

class _RouteItem extends StatelessWidget {
  const _RouteItem({required this.route, required this.onTap});

  final BusRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            // Bus icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: Color(0xFF16A34A),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Route name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${route.origin}  →  ${route.destination}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${route.activePassengers} students active',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
