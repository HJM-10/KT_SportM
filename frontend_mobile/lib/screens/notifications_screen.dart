import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await _apiService.dio.get('/notifications');
      setState(() {
        _notifications = res.data['data'];
        _isLoading = false;
      });
      // Mark as read when opened
      await _apiService.dio.patch('/notifications/read');
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final n = _notifications[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.notifications)),
                title: Text(n['title'], style: TextStyle(fontWeight: n['isRead'] ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(n['body']),
              );
            },
          )
    );
  }
}

