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

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) return network;
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
