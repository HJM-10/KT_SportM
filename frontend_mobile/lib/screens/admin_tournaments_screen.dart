import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminTournamentsScreen extends StatefulWidget {
  const AdminTournamentsScreen({super.key});

  @override
  State<AdminTournamentsScreen> createState() => _AdminTournamentsScreenState();
}

class _AdminTournamentsScreenState extends State<AdminTournamentsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _tournaments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.dio.get('/tournaments');
      if (mounted) setState(() { _tournaments = res.data['data']; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tournaments')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _tournaments.length,
        itemBuilder: (context, index) {
          final t = _tournaments[index];
          return ListTile(
            title: Text(t['name']),
            subtitle: Text('Status: ${t['status']}'),
          );
        },
      ),
    );
  }
}
