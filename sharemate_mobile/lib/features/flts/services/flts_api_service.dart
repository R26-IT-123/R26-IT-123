import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/api_client.dart';
import '../models/bus_route.dart';
import '../models/route_incident.dart';

class FltsApiService {
  FltsApiService({ApiClient? apiClient, FirebaseAuth? auth})
      : _apiClient = apiClient ?? ApiClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _auth;

  Future<String> _idToken() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('No authenticated Firebase user.');
    }
    return token;
  }

  Future<List<BusRoute>> fetchRoutes() async {
    final token = await _idToken();
    final list = await _apiClient.getList(
      '/api/flts/routes',
      headers: {'Authorization': 'Bearer $token'},
    );
    return list
        .map((e) => _routeFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> startSharing({
    required String routeId,
    required double lat,
    required double lng,
    String vehicleNumber = '',
  }) async {
    final token = await _idToken();
    await _apiClient.postJson(
      '/api/flts/sharing/start',
      body: {
        'route_id': routeId,
        'lat': lat,
        'lng': lng,
        'vehicle_number': vehicleNumber,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<Map<String, dynamic>>> fetchFeedback({
    required String vehicleNumber,
  }) async {
    final token = await _idToken();
    final list = await _apiClient.getList(
      '/api/flts/feedback',
      queryParams: {'vehicle_number': vehicleNumber},
      headers: {'Authorization': 'Bearer $token'},
    );
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> submitFeedback({
    required String vehicleNumber,
    required String routeId,
    required int rating,
    String type = '',
    String comment = '',
  }) async {
    final token = await _idToken();
    await _apiClient.postJson(
      '/api/flts/feedback',
      body: {
        'vehicle_number': vehicleNumber,
        'route_id': routeId,
        'rating': rating,
        'type': type,
        'comment': comment,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> updateGpsTick({
    required String routeId,
    required double lat,
    required double lng,
    String vehicleNumber = '',
  }) async {
    final token = await _idToken();
    await _apiClient.postJson(
      '/api/flts/sharing/tick',
      body: {
        'route_id': routeId,
        'lat': lat,
        'lng': lng,
        'vehicle_number': vehicleNumber,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> fetchPassengers({required String routeId}) async {
    final token = await _idToken();
    return _apiClient.getJson(
      '/api/flts/routes/$routeId/passengers',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> stopSharing({required String routeId}) async {
    final token = await _idToken();
    await _apiClient.postJson(
      '/api/flts/sharing/stop',
      body: {'route_id': routeId},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<RouteIncident> reportIncident({
    required String routeId,
    required String incidentType,
    required double lat,
    required double lng,
    String description = '',
  }) async {
    final token = await _idToken();
    final json = await _apiClient.postJson(
      '/api/flts/incidents',
      body: {
        'route_id': routeId,
        'incident_type': incidentType,
        'description': description,
        'lat': lat,
        'lng': lng,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return RouteIncident.fromJson(json);
  }

  Future<List<RouteIncident>> fetchRouteIncidents({
    required String routeId,
  }) async {
    final token = await _idToken();
    final list = await _apiClient.getList(
      '/api/flts/incidents/route/$routeId',
      headers: {'Authorization': 'Bearer $token'},
    );
    return list
        .map((e) => RouteIncident.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveIncident({required String incidentId}) async {
    final token = await _idToken();
    await _apiClient.patchJson(
      '/api/flts/incidents/$incidentId/resolve',
      body: const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  static BusRoute _routeFromJson(Map<String, dynamic> json) {
    final stops = (json['stops'] as List<dynamic>? ?? [])
        .map((s) {
          final stop = s as Map<String, dynamic>;
          return BusStop(
            id: stop['id'] as String,
            name: stop['name'] as String,
            lat: (stop['lat'] as num).toDouble(),
            lng: (stop['lng'] as num).toDouble(),
          );
        })
        .toList();
    return BusRoute(
      id: json['id'] as String,
      destination: json['destination'] as String,
      stops: stops,
      activePassengers: (json['active_passengers'] as num?)?.toInt() ?? 0,
    );
  }
}
