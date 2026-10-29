import 'package:dio/dio.dart';

import 'api_exception.dart';

typedef AccessTokenProvider = String? Function();

/// The only place that talks HTTP. Adds the Supabase access token and turns
/// failures into [ApiException]s.
class ApiClient {
  ApiClient({required String baseUrl, required AccessTokenProvider accessToken, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '$baseUrl/api/v1',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              contentType: Headers.jsonContentType,
            )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final token = accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, Object body) =>
      _send(() => _dio.put(path, data: body));

  Future<dynamic> patch(String path, Object body) =>
      _send(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
