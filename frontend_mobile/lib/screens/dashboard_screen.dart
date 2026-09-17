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

  List<dynamic> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _apiService.socket.on('booking_updated', _onDataUpdated);
  }

  @override
  void dispose() {
    _apiService.socket.off('booking_updated', _onDataUpdated);
    super.dispose();
  }

  void _onDataUpdated(dynamic data) {
    if (mounted) _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _apiService.dio.get('/bookings/my');
      final bookings = res.data['data'] as List;
      
      final recRes = await _apiService.dio.get('/recommendations/slots');

      setState(() {
        _totalBookings = bookings.length;
        _upcomingBookings = bookings.where((b) {
          return b['status'] == 'CONFIRMED' && DateTime.parse(b['slot']['date']).isAfter(DateTime.now());
        }).length;
        if (recRes.data['success']) {
           _recommendations = recRes.data['data'];
        }
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
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
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
                    const Text('Features', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildFeatureIcon('Events', Icons.event_note, () => Navigator.pushNamed(context, '/events')),
                        _buildFeatureIcon('Equipment', Icons.fitness_center, () => Navigator.pushNamed(context, '/equipment')),
                        _buildFeatureIcon('Memberships', Icons.card_membership, () => Navigator.pushNamed(context, '/membership')),
                        _buildFeatureIcon('Complaints', Icons.support_agent, () => Navigator.pushNamed(context, '/complaints')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Recommended for you', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildRecommendations(),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildFeatureIcon(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
            child: Icon(icon, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_recommendations.isEmpty) {
      return const Text('Book slots to get intelligent recommendations!', style: TextStyle(color: Colors.grey));
    }
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final rec = _recommendations[index];
          final venue = rec['venue'];
          return Card(
            margin: const EdgeInsets.only(right: 16),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(venue['sport']['name'], style: const TextStyle(color: Colors.grey)),
                  const Spacer(),
                  Text('${rec['startTime']} - ${rec['endTime']}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to bookings page
                      context.read<AuthProvider>().checkAuth(); // Just a dummy trigger
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
                    child: const Text('Book'),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
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
