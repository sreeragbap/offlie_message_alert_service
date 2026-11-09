import 'package:dio/dio.dart';

/// An error the UI can show. [message] is always safe for users.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  static const network = ApiException(
    'NETWORK',
    "Can't reach the server. Check your internet connection and try again.",
  );

  static const serverUnavailable = ApiException(
    'SERVER_UNAVAILABLE',
    "Can't reach the server right now. Please try again in a minute.",
  );

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) return network;
    // The reply came from the tunnel or a proxy in front of the backend, not the backend itself:
    // the backend is stopped or restarting (ngrok answers an offline endpoint with a 404 page).
    if (response.headers.value('ngrok-error-code') != null ||
        const {502, 503, 504}.contains(response.statusCode)) {
      return ApiException(serverUnavailable.code, serverUnavailable.message,
          statusCode: response.statusCode);
    }
    final data = response.data;
    if (data is Map && data['detail'] is String) {
      return ApiException(
        (data['code'] as String?) ?? 'HTTP_${response.statusCode}',
        data['detail'] as String,
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 401) {
      return ApiException('UNAUTHENTICATED', 'Please sign in again.',
          statusCode: response.statusCode);
    }
    return ApiException(
      'HTTP_${response.statusCode}',
      'Something went wrong. Please try again.',
      statusCode: response.statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code, $statusCode)';
}
