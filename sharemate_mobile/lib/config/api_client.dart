import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    this.baseUrl =
        'https://27b3-112-135-203-189.ngrok-free.app', // API Gateway — Android emulator → host machine. Use ngrok URL for real device.
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    debugPrint('ApiClient.getJson: GET $uri');

    final response = await _httpClient.get(
      uri,
      headers: {
        ...?headers,
      },
    );

    debugPrint(
      'ApiClient.getJson: status=${response.statusCode} body=${response.body}',
    );

    final decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: decodedBody['detail']?.toString() ??
            'Request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    return decodedBody;
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    var uri = _buildUri(path);
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(
        queryParameters: {...uri.queryParameters, ...queryParams},
      );
    }
    debugPrint('ApiClient.getList: GET $uri');

    final response = await _httpClient.get(
      uri,
      headers: {...?headers},
    );

    debugPrint(
      'ApiClient.getList: status=${response.statusCode} body=${response.body}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        message: decoded['detail']?.toString() ??
            'Request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) return [];
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    debugPrint('ApiClient.patchJson: PATCH $uri');

    final response = await _httpClient.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );

    debugPrint(
      'ApiClient.patchJson: status=${response.statusCode} body=${response.body}',
    );

    final decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: decodedBody['detail']?.toString() ??
            'Request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    return decodedBody;
  }

  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    debugPrint('ApiClient.uploadFile: POST $uri');

    final request = http.MultipartRequest('POST', uri);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint(
      'ApiClient.uploadFile: status=${response.statusCode} body=${response.body}',
    );

    final decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: decodedBody['detail']?.toString() ??
            'Upload failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    return decodedBody;
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    debugPrint('ApiClient.putJson: PUT $uri');

    final response = await _httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body),
    );

    debugPrint('ApiClient.putJson: status=${response.statusCode}');

    final decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: decodedBody['detail']?.toString() ??
            'Request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    return decodedBody;
  }

  Future<void> deleteJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    debugPrint('ApiClient.deleteJson: DELETE $uri');

    final response = await _httpClient.delete(
      uri,
      headers: {...?headers},
    );

    debugPrint('ApiClient.deleteJson: status=${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        message: decoded['detail']?.toString() ??
            'Request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    debugPrint('ApiClient.postJson: POST $uri');

    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );

    debugPrint(
      'ApiClient.postJson: status=${response.statusCode} body=${response.body}',
    );

    final decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: decodedBody['detail']?.toString() ??
            'Request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    return decodedBody;
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
  });

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
