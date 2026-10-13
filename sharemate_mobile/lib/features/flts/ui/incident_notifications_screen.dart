import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/bus_route.dart';
import '../models/route_incident.dart';
import '../services/incident_notifications_service.dart';
import 'flts_map_screen.dart';

/// Notification inbox for incidents reported on the student's route —
/// opened from the bell icon on the home page.
class IncidentNotificationsScreen extends StatefulWidget {
  const IncidentNotificationsScreen({super.key, required this.routeId});

  final String routeId;

  @override
  State<IncidentNotificationsScreen> createState() =>
      _IncidentNotificationsScreenState();
}

class _IncidentNotificationsScreenState
    extends State<IncidentNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark everything seen the moment the inbox is opened — mirrors how a
    // real notification tray clears its badge on open.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      IncidentNotificationsService.markSeenNow(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = BusRoute.sliitRoutes.firstWhere(
      (r) => r.id == widget.routeId,
      orElse: () => BusRoute(
        id: widget.routeId,
        destination: widget.routeId.replaceAll('route_', ''),
        stops: const [],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF111827),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              '${route.origin} → ${route.destination}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<RouteIncident>>(
        stream: IncidentNotificationsService.streamForRoute(widget.routeId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Color(0xFFD1D5DB),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load notifications.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final incidents = snapshot.data!;
          if (incidents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      size: 48,
                      color: Color(0xFFD1D5DB),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No incidents reported on your route yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: incidents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _IncidentTile(incident: incidents[index], routeId: widget.routeId),
          );
        },
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.incident, required this.routeId});

  final RouteIncident incident;
  final String routeId;

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FltsMapScreen(preferredRouteId: routeId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: incident.active
                ? const Color(0xFFFECACA)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: incident.active
                    ? const Color(0xFFFFE4E4)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                incident.typeIcon,
                color: incident.active
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          incident.typeLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(incident.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  if (incident.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      incident.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: incident.active
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      incident.active ? 'Active' : 'Resolved',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: incident.active
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
