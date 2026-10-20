/// A named stop along a bus route.
class BusStop {
  const BusStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
}

/// Represents a single bus route available in the FLTS engine.
/// By default routes originate from SLIIT Malabe campus, but a route's
/// direction can be flipped via [returnTrip] (e.g. Kaduwela → SLIIT Campus).
class BusRoute {
  const BusRoute({
    required this.id,
    required this.destination,
    required this.stops,
    this.activePassengers = 0,
    this.origin = campusName,
    this.originLat = campusLat,
    this.originLng = campusLng,
  });

  final String id;
  final String origin;
  final String destination;
  final List<BusStop> stops;
  final int activePassengers;

  /// Coordinates of the trip's starting point (campus for outbound trips,
  /// the town's last stop for the reversed/inbound trip).
  final double originLat;
  final double originLng;

  static const String campusName = 'SLIIT Campus';

  String get displayName => '$origin  →  $destination';

  /// Destination coordinates — taken from the last stop in the route.
  /// Used by the Directions API to fetch the road-following polyline.
  double? get destLat => stops.isNotEmpty ? stops.last.lat : null;
  double? get destLng => stops.isNotEmpty ? stops.last.lng : null;

  /// The reverse-direction trip, e.g. Kaduwela → SLIIT Campus.
  /// Reverses the stop order (the stop that becomes the new origin is
  /// dropped from the list) and appends campus as the final stop, mirroring
  /// how the outbound trip lists its destination town as the last stop.
  BusRoute get returnTrip {
    if (stops.isEmpty) {
      return BusRoute(
        id: '${id}_return',
        origin: destination,
        destination: origin,
        originLat: originLat,
        originLng: originLng,
        stops: const [],
        activePassengers: activePassengers,
      );
    }
    final newOrigin = stops.last;
    final campusStop = BusStop(
      id: '${id}_campus_arrival',
      name: origin,
      lat: originLat,
      lng: originLng,
    );
    return BusRoute(
      id: '${id}_return',
      origin: destination,
      destination: origin,
      originLat: newOrigin.lat,
      originLng: newOrigin.lng,
      stops: [...stops.reversed.skip(1), campusStop],
      activePassengers: activePassengers,
    );
  }

  // ── SLIIT Malabe campus coordinates ──────────────────────────────────────
  static const double campusLat = 6.915309380393159;
  static const double campusLng = 79.97271740542908;

  // ── 5 official SLIIT commuter routes ─────────────────────────────────────
  static const List<BusRoute> sliitRoutes = [
    BusRoute(
      id: 'route_kaduwela',
      destination: 'Kaduwela',
      stops: [
        BusStop(
          id: 'kaduwela_seewali_mawatha',
          name: 'Seewali Mawatha',
          lat: 6.920128537296916,
          lng: 79.9743596707538,
        ),
        BusStop(
          id: 'kaduwela_kothalawela',
          name: 'Kothalawela',
          lat: 6.925010842053611,
          lng: 79.97875068013595,
        ),
        BusStop(
          id: 'kaduwela_town',
          name: 'Kaduwela',
          lat: 6.936428686582979,
          lng: 79.98328968423978,
        ),
      ],
    ),
    BusRoute(
      id: 'route_gampaha',
      destination: 'Gampaha',
      stops: [
        BusStop(
          id: 'gampaha_kolonnawa',
          name: 'Kolonnawa',
          lat: 6.9255,
          lng: 79.9411,
        ),
        BusStop(
          id: 'gampaha_kelaniya',
          name: 'Kelaniya',
          lat: 6.9625,
          lng: 79.9206,
        ),
        BusStop(
          id: 'gampaha_town',
          name: 'Gampaha',
          lat: 7.0875,
          lng: 79.9994,
        ),
      ],
    ),
    BusRoute(
      id: 'route_kollupitiya',
      destination: 'Kollupitiya',
      stops: [
        BusStop(
          id: 'kollu_rajagiriya',
          name: 'Rajagiriya',
          lat: 6.9057,
          lng: 79.9090,
        ),
        BusStop(
          id: 'kollu_borella',
          name: 'Borella',
          lat: 6.9150,
          lng: 79.8800,
        ),
        BusStop(
          id: 'kollu_town',
          name: 'Kollupitiya',
          lat: 6.9028,
          lng: 79.8553,
        ),
      ],
    ),
    BusRoute(
      id: 'route_panadura',
      destination: 'Panadura',
      stops: [
        BusStop(
          id: 'panadura_rajagiriya',
          name: 'Rajagiriya',
          lat: 6.9057,
          lng: 79.9090,
        ),
        BusStop(
          id: 'panadura_dehiwala',
          name: 'Dehiwala',
          lat: 6.8510,
          lng: 79.8720,
        ),
        BusStop(
          id: 'panadura_town',
          name: 'Panadura',
          lat: 6.7120,
          lng: 79.9022,
        ),
      ],
    ),
    BusRoute(
      id: 'route_jaela',
      destination: 'Jaela',
      stops: [
        BusStop(
          id: 'jaela_kelaniya',
          name: 'Kelaniya',
          lat: 6.9625,
          lng: 79.9206,
        ),
        BusStop(
          id: 'jaela_wattala',
          name: 'Wattala',
          lat: 6.9931,
          lng: 79.8917,
        ),
        BusStop(
          id: 'jaela_town',
          name: 'Jaela',
          lat: 7.0779,
          lng: 79.8911,
        ),
      ],
    ),
  ];
}
