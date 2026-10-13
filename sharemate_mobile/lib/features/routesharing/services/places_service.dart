import 'dart:convert';
import 'package:http/http.dart' as http;

const _kApiKey = 'AIzaSyBJATP_Pc0SDsrzs57g3bQkRLkk-mMEFDU';

class PlacePrediction {
  const PlacePrediction({required this.placeId, required this.description});
  final String placeId;
  final String description;
}

class PlaceDetail {
  const PlaceDetail({
    required this.lat,
    required this.lng,
    required this.address,
  });
  final double lat;
  final double lng;
  final String address;
}

class PlacesService {
  static Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().length < 2) return [];
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': input,
          'key': _kApiKey,
          'components': 'country:lk',
          'language': 'en',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final predictions = data['predictions'] as List? ?? [];
      return predictions
          .map((p) => PlacePrediction(
                placeId: p['place_id'] as String? ?? '',
                description: p['description'] as String? ?? '',
              ))
          .where((p) => p.placeId.isNotEmpty && p.description.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<PlaceDetail?> getDetail(String placeId) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'geometry,formatted_address',
          'key': _kApiKey,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) return null;
      final location =
          ((result['geometry'] as Map)['location']) as Map<String, dynamic>;
      return PlaceDetail(
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
        address: result['formatted_address'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
