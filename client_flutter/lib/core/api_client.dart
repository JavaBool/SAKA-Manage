import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio dio;
  final storage = const FlutterSecureStorage();
  void Function(String reason, Map<String, dynamic> details)? onUnauthorized;

  // Static token cache to avoid slow secure storage reads and race conditions
  static String? accessToken;

  // Primary API endpoint config
  static const String apiBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://javabool-sakamanage.hf.space/api/v1',
  );

  ApiClient({String? baseUrl}) : dio = Dio(BaseOptions(
    baseUrl: baseUrl ?? apiBaseUrl,
    connectTimeout: const Duration(seconds: 90),
    receiveTimeout: const Duration(seconds: 90),
  )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Read auth token from static cache or secure storage and inject in headers
        String? token = accessToken;
        if (token == null) {
          token = await storage.read(key: 'access_token');
          if (token != null) {
            accessToken = token;
          }
        }
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401) {
          final token = await storage.read(key: 'access_token');
          final userId = await storage.read(key: 'user_id');
          final url = error.requestOptions.uri.toString();
          final body = error.response?.data;
          final headers = error.response?.headers.toString();
          final timestamp = DateTime.now().toIso8601String();

          print("[AUTH_DEBUG]\n401 received\nEndpoint: $url\nBody: $body\nHeaders: $headers\nTimestamp: $timestamp\nCurrent user id: $userId");

          final Map<String, dynamic> details = {
            'request_url': url,
            'endpoint_involved': url, // compatibility
            'http_method': error.requestOptions.method,
            'response_body': body,
            'response_headers': error.response?.headers.map,
            'user_id': userId,
            'current_timestamp': DateTime.now().toUtc().toIso8601String(),
            'current_time': DateTime.now().toUtc().toIso8601String(), // compatibility
            'http_status_code': 401,
          };

          String reason = 'http_401';
          if (token != null) {
            try {
              final parts = token.split('.');
              if (parts.length == 3) {
                final payload = parts[1];
                final normalized = base64.normalize(payload);
                final decoded = utf8.decode(base64.decode(normalized));
                final map = json.decode(decoded) as Map<String, dynamic>;
                final expVal = map['exp'];
                if (expVal is int) {
                  final expTime = DateTime.fromMillisecondsSinceEpoch(expVal * 1000).toUtc();
                  final expStr = expTime.toIso8601String();
                  details['jwt_exp'] = expStr;
                  details['jwt_expiration_timestamp'] = expStr;
                  final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                  final diff = expVal - nowSeconds;
                  details['seconds_until_jwt_expiry'] = diff;
                  details['difference_in_seconds'] = diff;
                  if (nowSeconds >= expVal) {
                    reason = 'jwt_expiration';
                  } else {
                    reason = 'user_deactivated';
                  }
                }
              }
            } catch (e) {
              print("[AUTH_DEBUG] Error decoding JWT in 401 handler: $e");
            }
          }

          // Ignore 401 errors for non-critical endpoints like device token registration
          final isDeviceTokenRequest = url.contains('/device_tokens');
          if (onUnauthorized != null && !isDeviceTokenRequest) {
            onUnauthorized!(reason, details);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.delete(path, data: data, queryParameters: queryParameters);
  }
}
