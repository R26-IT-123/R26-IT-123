import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/api_client.dart';
import '../models/timetable_entry.dart';

class TimetableApiService {
  TimetableApiService({ApiClient? apiClient, FirebaseAuth? auth})
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

  Future<List<TimetableEntry>> fetchTimetables({
    String? origin,
    String? destination,
    String? routeNumber,
  }) async {
    final token = await _idToken();
    final list = await _apiClient.getList(
      '/api/flts/timetable',
      queryParams: {
        if (origin != null && origin.isNotEmpty) 'origin': origin,
        if (destination != null && destination.isNotEmpty) 'destination': destination,
        if (routeNumber != null && routeNumber.isNotEmpty) 'route_number': routeNumber,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return list
        .map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
