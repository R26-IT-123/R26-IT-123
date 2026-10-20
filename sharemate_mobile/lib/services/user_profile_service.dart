import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../models/user_profile.dart';

class UserProfileService {
  UserProfileService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<UserProfile> fetchProfile({required String idToken}) async {
    final tokenPreview = idToken.length > 16
        ? '${idToken.substring(0, 8)}...${idToken.substring(idToken.length - 8)}'
        : idToken;
    debugPrint(
      'UserProfileService.fetchProfile: GET /api/profile/me token=$tokenPreview',
    );

    final response = await _apiClient.getJson(
      '/api/profile/me',
      headers: {'Authorization': 'Bearer $idToken'},
    );

    debugPrint(
      'UserProfileService.fetchProfile: response '
      'uid=${response['uid']} email=${response['university_email']}',
    );

    return UserProfile.fromJson(response);
  }

  Future<void> updateProfile({
    required String idToken,
    required String? preferredRouteId,
  }) async {
    await _apiClient.patchJson(
      '/api/profile/me',
      body: {'preferred_route_id': preferredRouteId},
      headers: {'Authorization': 'Bearer $idToken'},
    );
  }

  Future<String> uploadPhoto({
    required String idToken,
    required String filePath,
  }) async {
    final response = await _apiClient.uploadFile(
      '/api/profile/me/photo',
      filePath: filePath,
      fieldName: 'file',
      headers: {'Authorization': 'Bearer $idToken'},
    );
    return response['photo_url'] as String;
  }
}
