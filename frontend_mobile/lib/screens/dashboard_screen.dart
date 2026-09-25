import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'slots_screen.dart';

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
        title: const Text('Smart Sports Hub', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
      extendBodyBehindAppBar: true,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE0E7FF)],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
            onRefresh: _fetchStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome,\n${user?['name'] ?? 'User'}!',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1),
                    ),
                    const SizedBox(height: 32),
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
                    const SizedBox(height: 32),
                    const Text('Features', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    GridView.count(
                      key: keyFeatures,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      childAspectRatio: 0.75,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildFeatureIcon('Events', Icons.event_note, () => Navigator.pushNamed(context, '/events')),
                        _buildFeatureIcon('Equip', Icons.fitness_center, () => Navigator.pushNamed(context, '/equipment')),
                        _buildFeatureIcon('Members', Icons.card_membership, () => Navigator.pushNamed(context, '/membership')),
                        _buildFeatureIcon('Help', Icons.support_agent, () => Navigator.pushNamed(context, '/complaints')),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text('Recommended for you', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    _buildRecommendations(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF6366F1).withOpacity(0.08),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 28),
            SizedBox(width: 16),
            Expanded(
              child: Text('Book slots to get intelligent recommendations based on your preferences!', style: TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final rec = _recommendations[index];
          final venue = rec['venue'];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            width: 240,
            margin: const EdgeInsets.only(right: 16, bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.sports, color: Color(0xFF6366F1), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(venue['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(venue['sport']['name'], style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${rec['startTime']} - ${rec['endTime']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SlotsScreen(venueId: venue['id']),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF1F5F9)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: const Color(0xFF6366F1)),
            ),
            const SizedBox(height: 20),
            Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}


