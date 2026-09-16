import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  int _totalBookings = 0;
  int _upcomingBookings = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _apiService.dio.get('/bookings/my');
      final bookings = res.data['data'] as List;
      
      setState(() {
        _totalBookings = bookings.length;
        _upcomingBookings = bookings.where((b) {
          return b['status'] == 'CONFIRMED' && DateTime.parse(b['slot']['date']).isAfter(DateTime.now());
        }).length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Sports Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user?['name'] ?? 'User'}!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Total Bookings', _totalBookings.toString(), Icons.book),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard('Upcoming', _upcomingBookings.toString(), Icons.event),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Featured Sports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                // Could add a list of featured sports here
              ],
            ),
          ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      color: const Color(0xFF16162A),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF6366F1)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
