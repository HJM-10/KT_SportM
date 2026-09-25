import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.dio.get('/events');
      if (mounted) setState(() { _events = res.data['data']; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Events')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final ev = _events[index];
          return ListTile(
            title: Text(ev['name']),
            subtitle: Text('Venue: ${ev['venue']?['name'] ?? 'N/A'}'),
          );
        },
      ),
    );
  }
}
