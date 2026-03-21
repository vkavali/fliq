import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor(ref, dio));
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (obj) => print('[API] $obj'), // ignore: avoid_print
  ));

  return dio;
});

class AuthInterceptor extends Interceptor {
  final Ref _ref;
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._ref, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final storage = _ref.read(secureStorageProvider);
        final refreshToken = await storage.getRefreshToken();

        if (refreshToken != null) {
          // Try to refresh the access token
          final response = await Dio(BaseOptions(
            baseUrl: ApiConstants.baseUrl,
          )).post('/auth/refresh', data: {'refreshToken': refreshToken});

          final newAccessToken = response.data['accessToken'] as String;
          await storage.saveAccessToken(newAccessToken);

          // Retry the original request with new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _dio.fetch(err.requestOptions);
          _isRefreshing = false;
          return handler.resolve(retryResponse);
        }
      } catch (_) {
        // Refresh failed — clear auth and force re-login
      }

      _isRefreshing = false;
      final storage = _ref.read(secureStorageProvider);
      await storage.clearAll();
    }
    handler.next(err);
  }
}
