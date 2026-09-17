import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;

  Future<void> checkAuth() async {
    final token = await _apiService.storage.read(key: 'ssh_token');
    if (token != null) {
      try {
        final res = await _apiService.dio.get('/auth/me');
        _user = res.data['data'];
        _isAuthenticated = true;
      await PushService.register();
      } catch (e) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final res = await _apiService.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = res.data['data'];
      await _apiService.storage.write(key: 'ssh_token', value: data['token']);
      _user = data['user'];
      _isAuthenticated = true;
      await PushService.register();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password, String phone) async {
    try {
      final res = await _apiService.dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      });
      final data = res.data['data'];
      await _apiService.storage.write(key: 'ssh_token', value: data['token']);
      _user = data['user'];
      _isAuthenticated = true;
      await PushService.register();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await PushService.unregister();
    await _apiService.storage.delete(key: 'ssh_token');
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}


