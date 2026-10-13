import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
final sessionProvider = StateProvider<Map<String, dynamic>?>((ref) {
  final raw = ref.watch(preferencesProvider).getString('session_user');
  if (raw == null) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(preferencesProvider)),
);

class ApiClient {
  ApiClient(this.preferences)
    : dio = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000/api/v1',
          ),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = preferences.getString('access_token');
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
  }

  final SharedPreferences preferences;
  final Dio dio;

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return response.data ?? {};
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await dio.get<List<dynamic>>(path, queryParameters: query);
    return response.data ?? [];
  }

  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    final response = await dio.post<Map<String, dynamic>>(path, data: data);
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> patch(String path, {Object? data}) async {
    final response = await dio.patch<Map<String, dynamic>>(path, data: data);
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> uploadFile(
    String path,
    Uint8List bytes,
    String filename,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      path,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return response.data ?? {};
  }

  Future<void> saveSession(Map<String, dynamic> payload) async {
    final user = Map<String, dynamic>.from(payload['user'] as Map);
    await preferences.setString(
      'access_token',
      payload['accessToken'] as String,
    );
    await preferences.setString('session_user', jsonEncode(user));
  }

  Future<void> clearSession() async {
    await preferences.remove('access_token');
    await preferences.remove('session_user');
  }

  static String errorMessage(Object error) {
    if (error is DioException) {
      final message = error.response?.data is Map
          ? (error.response?.data as Map)['message']
          : null;
      if (message is List) return message.join('\n');
      if (message is String) return message;
      if (error.type == DioExceptionType.connectionError)
        return 'Cannot reach the Wasalny API. Check your connection and server.';
    }
    return 'Something went wrong. Please try again.';
  }
}
