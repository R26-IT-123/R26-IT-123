import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/bus_route.dart';

/// Calculates ETA for each bus stop based on current centroid and speed.
class EtaService {
  /// Haversine great-circle distance between two points, in kilometres.
  static double distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final h = sinDLat * sinDLat +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            sinDLng *
            sinDLng;
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  /// Returns ETAs (as minutes, rounded) for each stop.
  ///
  /// [speedKmh] — current bus speed; if null or zero, returns null ETAs
  /// (distance still returned via [distanceKm] separately if needed).
  static Map<String, int?> calculateEtaMinutes({
    required LatLng busPosition,
    required double? speedKmh,
    required List<BusStop> stops,
  }) {
    final result = <String, int?>{};
    for (final stop in stops) {
      final stopLatLng = LatLng(stop.lat, stop.lng);
      final dist = distanceKm(busPosition, stopLatLng);
      if (speedKmh == null || speedKmh < 2) {
        result[stop.id] = null;
      } else {
        final hours = dist / speedKmh;
        result[stop.id] = (hours * 60).round();
      }
    }
    return result;
  }

  /// Derives current speed in km/h from two centroid positions and elapsed time.
  ///
  /// Returns null if [previousPosition] or [elapsedSeconds] is null/zero.
  static double? deriveSpeedKmh({
    required LatLng current,
    required LatLng? previous,
    required double? elapsedSeconds,
  }) {
    if (previous == null || elapsedSeconds == null || elapsedSeconds < 1) {
      return null;
    }
    final dist = distanceKm(current, previous);
    final hours = elapsedSeconds / 3600;
    return dist / hours;
  }
}
