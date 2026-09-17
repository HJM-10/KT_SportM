import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sports_screen.dart';
import 'screens/tournaments_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/theme_provider.dart';

import 'screens/events_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/membership_screen.dart';
import 'screens/complaints_screen.dart';
import 'screens/notifications_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const SmartSportsHubApp(),
    ),
  );
}

class SmartSportsHubApp extends StatelessWidget {
  const SmartSportsHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Smart Sports Hub',
          themeMode: themeProvider.themeMode,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isAuthenticated) {
                return const MainLayout();
              }
              return const LoginScreen();
            },
          ),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/events': (context) => const EventsScreen(),
            '/equipment': (context) => const EquipmentScreen(),
            '/membership': (context) => const MembershipScreen(),
            '/complaints': (context) => const ComplaintsScreen(),
            '/notifications': (context) => const NotificationsScreen(),
          },
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SportsScreen(),
    const TournamentsScreen(),
    const MatchesScreen(),
    const MyBookingsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF16162A),
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'Sports'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Tournaments'),
          BottomNavigationBarItem(icon: Icon(Icons.sports), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
