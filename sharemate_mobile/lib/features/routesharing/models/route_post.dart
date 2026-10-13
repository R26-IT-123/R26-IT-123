class Waypoint {
  const Waypoint({
    required this.address,
    required this.order,
    this.lat,
    this.lng,
  });

  final String address;
  final int order;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toJson() => {
        'address': address,
        'order': order,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
        address: json['address'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );
}

class RoutePost {
  const RoutePost({
    required this.id,
    required this.driverId,
    required this.startLocation,
    required this.destination,
    required this.departureTime,
    required this.totalSeats,
    required this.seatsAvailable,
    required this.pricePerTrip,
    required this.status,
    this.travelDays = const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
    this.destinationLat,
    this.destinationLng,
    this.stopLocation,
    this.routePolyline,
    this.totalDistanceKm,
    this.pricePerKm,
    this.startDate,
    this.endDate,
    this.waypoints = const [],
    this.driverName,
    this.driverYear,
    this.avgRating,
    this.aiSummary,
    this.createdAt,
  });

  final String id;
  final String driverId;
  final Map<String, dynamic> startLocation;
  final String destination;
  final List<String> travelDays;
  final double? destinationLat;
  final double? destinationLng;
  final Map<String, dynamic>? stopLocation;
  final String? routePolyline;
  final double? totalDistanceKm;
  final String departureTime;
  final int totalSeats;
  final int seatsAvailable;
  final double pricePerTrip;
  final double? pricePerKm;
  final String? startDate;
  final String? endDate;
  final String status;
  final List<Waypoint> waypoints;
  final String? driverName;
  final int? driverYear;
  final double? avgRating;
  final String? aiSummary;
  final DateTime? createdAt;

  double? get startLat => (startLocation['lat'] as num?)?.toDouble();
  double? get startLng => (startLocation['lng'] as num?)?.toDouble();
  String? get startAddress => startLocation['address'] as String?;

  String? get fairnessLabel {
    final km = totalDistanceKm;
    if (km == null || km <= 0) return null;
    double rateMin, rateMax;
    if (km <= 10) {
      rateMin = 10; rateMax = 20;
    } else if (km <= 25) {
      rateMin = 8; rateMax = 18;
    } else {
      rateMin = 7; rateMax = 15;
    }
    final minFare = rateMin * km;
    final maxFare = rateMax * km;
    if (pricePerTrip < minFare) return 'Below Average';
    if (pricePerTrip <= maxFare) return 'Fair Price';
    if (pricePerTrip <= maxFare * 1.25) return 'Above Average';
    return 'High Price';
  }

  factory RoutePost.fromJson(Map<String, dynamic> json) {
    final start = json['start_location'];
    final stop = json['stop_location'];
    return RoutePost(
      id: json['id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      startLocation: (start is Map<String, dynamic>) ? start : {},
      destination: json['destination'] as String? ?? '',
      travelDays: json['travel_days'] != null
          ? List<String>.from(json['travel_days'] as List)
          : const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      stopLocation: (stop is Map<String, dynamic>) ? stop : null,
      routePolyline: json['route_polyline'] as String?,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble(),
      departureTime: json['departure_time'] as String? ?? '',
      totalSeats: (json['total_seats'] as num?)?.toInt() ?? 0,
      seatsAvailable: (json['seats_available'] as num?)?.toInt() ?? 0,
      pricePerTrip: (json['price_per_trip'] as num?)?.toDouble() ?? 0,
      pricePerKm: (json['price_per_km'] as num?)?.toDouble(),
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      status: json['status'] as String? ?? 'active',
      waypoints: (json['waypoints'] as List<dynamic>? ?? [])
          .map((e) => Waypoint.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
      driverName: json['driver_name'] as String?,
      driverYear: (json['driver_year'] as num?)?.toInt(),
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      aiSummary: json['ai_summary'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class PricingSuggestion {
  const PricingSuggestion({
    required this.distanceKm,
    required this.suggestedMinFare,
    required this.suggestedMaxFare,
    required this.ratePerKmMin,
    required this.ratePerKmMax,
    required this.pickmeEquivalent,
    this.platformSetFare,
    this.pricePerKm,
  });

  final double distanceKm;
  final double suggestedMinFare;
  final double suggestedMaxFare;
  final double ratePerKmMin;
  final double ratePerKmMax;
  final double pickmeEquivalent;
  final double? platformSetFare;
  final double? pricePerKm;

  factory PricingSuggestion.fromJson(Map<String, dynamic> json) {
    return PricingSuggestion(
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      suggestedMinFare: (json['suggested_min_fare'] as num?)?.toDouble() ?? 0,
      suggestedMaxFare: (json['suggested_max_fare'] as num?)?.toDouble() ?? 0,
      ratePerKmMin: (json['rate_per_km_min'] as num?)?.toDouble() ?? 0,
      ratePerKmMax: (json['rate_per_km_max'] as num?)?.toDouble() ?? 0,
      pickmeEquivalent: (json['pickme_equivalent'] as num?)?.toDouble() ?? 0,
      platformSetFare: (json['platform_set_fare'] as num?)?.toDouble(),
      pricePerKm: (json['price_per_km'] as num?)?.toDouble(),
    );
  }
}
