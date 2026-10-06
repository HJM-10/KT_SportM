import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'admin_sports_screen.dart';
import 'admin_users_screen.dart';
import 'admin_venues_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_tournaments_screen.dart';
import 'admin_events_screen.dart';
import 'payments_screen.dart';
import 'fixtures_screen.dart';
import 'check_in_screen.dart';
import 'admin_reports_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Admin\n${user?['name'] ?? ''}!',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1),
                ),
                const SizedBox(height: 32),
                const Text('Management Features', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildFeatureCard(context, 'Sports', Icons.sports_soccer, Colors.orange, screen: const AdminSportsScreen()),
                    _buildFeatureCard(context, 'Venues', Icons.stadium, Colors.blue, screen: const AdminVenuesScreen()),
                    _buildFeatureCard(context, 'Users', Icons.people, Colors.green, screen: const AdminUsersScreen()),
                    _buildFeatureCard(context, 'Bookings', Icons.book_online, Colors.purple, screen: const AdminBookingsScreen()),
                    _buildFeatureCard(context, 'Tournaments', Icons.emoji_events, Colors.amber, screen: const AdminTournamentsScreen()),
                    _buildFeatureCard(context, 'Events', Icons.event, Colors.cyan, screen: const AdminEventsScreen()),
                    _buildFeatureCard(context, 'Payments', Icons.payment, Colors.teal, screen: const PaymentsScreen(admin: true)),
                    _buildFeatureCard(context, 'Fixtures', Icons.sports, Colors.indigo, screen: const FixturesScreen()),
                    _buildFeatureCard(context, 'Check-in', Icons.qr_code_scanner, Colors.blueGrey, screen: const CheckInScreen()),
                    _buildFeatureCard(context, 'Reports', Icons.bar_chart, Colors.redAccent, screen: const AdminReportsScreen()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, IconData icon, Color color, {String? route, Widget? screen}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        if (screen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        } else if (route != null) {
          Navigator.pushNamed(context, route);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title management coming soon!')),
          );
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
