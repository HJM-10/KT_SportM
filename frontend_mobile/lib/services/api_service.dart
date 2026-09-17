import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late IO.Socket _socket;
  
  // Use 10.0.2.2 for Android emulator to access localhost, or your computer's IP for physical device
  final String baseUrl = 'http://10.0.2.2:5000/api';
  final String socketUrl = 'http://10.0.2.2:5000';

  ApiService._internal() {
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
        }
        return handler.next(e);
      },
    ));

    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket']) // for Flutter or Web
      .disableAutoConnect()  // disable auto-connection
      .build()
    );
    _socket.connect();
    
    _socket.onConnect((_) {
      print('Socket connected');
    });
  }

  Dio get dio => _dio;
  FlutterSecureStorage get storage => _storage;
  IO.Socket get socket => _socket;
}
