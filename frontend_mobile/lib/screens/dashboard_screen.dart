import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];
  
  // Keys for targets
  final GlobalKey keyStats = GlobalKey();
  final GlobalKey keyFeatures = GlobalKey();
  final GlobalKey keyRecommended = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _apiService.socket.on('booking_updated', _onDataUpdated);
    _checkTutorial();
  }

  void _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasShownTutorial = prefs.getBool('hasShownDashboardTutorial') ?? false;
    
    if (!hasShownTutorial) {
      _initTargets();
      _showTutorial();
      prefs.setBool('hasShownDashboardTutorial', true);
    }
  }

  void _initTargets() {
    targets.add(
      TargetFocus(
        identify: "Stats",
        keyTarget: keyStats,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Quick Stats", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text("Here you can see your total bookings and upcoming events at a glance.", style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "Features",
        keyTarget: keyFeatures,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Explore Features", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text("Easily access Events, Equipment rentals, Memberships, and Complaints.", style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTutorial() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      tutorialCoachMark = TutorialCoachMark(
        targets: targets,
        colorShadow: const Color(0xFF16162A),
        textSkip: "SKIP",
        paddingFocus: 10,
        opacityShadow: 0.8,
        onFinish: () {},
        onClickTarget: (target) {},
        onClickTargetWithTapPosition: (target, tapDetails) {},
        onClickOverlay: (target) {},
        onSkip: () { return true; },
      )..show(context: context);
    });
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
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
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
                      key: keyStats,
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
                      key: keyFeatures,
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
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
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


