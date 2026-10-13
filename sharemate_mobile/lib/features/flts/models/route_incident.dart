import 'package:flutter/material.dart';

/// A student-reported incident (traffic jam, accident, etc.) along a bus route.
class RouteIncident {
  const RouteIncident({
    required this.incidentId,
    required this.routeId,
    required this.reportedByUid,
    required this.incidentType,
    required this.description,
    required this.lat,
    required this.lng,
    required this.active,
    required this.createdAt,
    this.resolvedAt,
  });

  final String incidentId;
  final String routeId;
  final String reportedByUid;
  final String incidentType;
  final String description;
  final double lat;
  final double lng;
  final bool active;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  factory RouteIncident.fromJson(Map<String, dynamic> json) {
    return RouteIncident(
      incidentId: json['incident_id'] as String,
      routeId: json['route_id'] as String,
      reportedByUid: json['reported_by_uid'] as String,
      incidentType: json['incident_type'] as String,
      description: json['description'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      active: json['active'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
    );
  }

  /// Must match INCIDENT_TYPES in flts_service/services/incident_service.py.
  static const Map<String, String> typeLabels = {
    'traffic_jam': 'Traffic Jam',
    'accident': 'Accident',
    'road_closure': 'Road Closure',
    'bus_breakdown': 'Bus Breakdown',
    'heavy_rain': 'Heavy Rain',
    'other': 'Other',
  };

  String get typeLabel => typeLabels[incidentType] ?? 'Other';

  static const Map<String, IconData> typeIcons = {
    'traffic_jam': Icons.traffic_rounded,
    'accident': Icons.car_crash_rounded,
    'road_closure': Icons.block_rounded,
    'bus_breakdown': Icons.build_rounded,
    'heavy_rain': Icons.water_drop_rounded,
    'other': Icons.warning_amber_rounded,
  };

  IconData get typeIcon => typeIcons[incidentType] ?? Icons.warning_amber_rounded;
}
