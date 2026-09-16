import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Use 10.0.2.2 for Android emulator to access localhost, or your computer's IP for physical device
  final String baseUrl = 'http://10.0.2.2:5000/api';

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.headers['Content-Type'] = 'application/json';

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'ssh_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          await _storage.delete(key: 'ssh_token');
          // Handle navigation to login globally if needed
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
  FlutterSecureStorage get storage => _storage;
}
