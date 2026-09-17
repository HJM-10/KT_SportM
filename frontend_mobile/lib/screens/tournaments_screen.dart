import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import '../utils/icon_helper.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _tournaments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    try {
      final res = await _apiService.dio.get('/tournaments');
      if (mounted) {
        setState(() {
          _tournaments = res.data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load tournaments')),
        );
      }
    }
  }

  final Set<int> _registeredIds = {};

  Future<void> _register(int tournamentId) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    
    try {
      final response = await _apiService.dio.post('/tournaments/$tournamentId/register', data: {
        'teamName': '${user['name']}\'s Team',
      });
      if (response.data['data']['paymentId'] != null) await PaymentService.checkout(response.data['data']['paymentId']);
      if (!mounted) return;
      setState(() {
        _registeredIds.add(tournamentId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully!')),
        );
      }
      _fetchTournaments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((e as dynamic).response?.data['message'] ?? 'Failed to register')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tournaments.isEmpty
              ? const Center(child: Text('No tournaments available', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tournaments.length,
                  itemBuilder: (context, index) {
                    final t = _tournaments[index];
                    final dateStr = DateFormat.yMMMd().format(DateTime.parse(t['startDate']));
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(IconHelper.getIcon(t['sport']?['icon']), size: 14, color: const Color(0xFF818CF8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    t['sport']?['name'] ?? '',
                                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t['name'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(width: 16),
                                const Icon(Icons.people, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${t['_count']?['registrations'] ?? 0}/${t['maxTeams']} Teams', 
                                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white12),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t['status'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: t['status'] == 'UPCOMING' ? const Color(0xFF6366F1) : 
                                          (t['status'] == 'ONGOING' ? Colors.orange : Colors.green),
                                  ),
                                ),
                                if (t['status'] == 'UPCOMING')
                                  ElevatedButton(
                                    onPressed: _registeredIds.contains(t['id']) ? null : () => _register(t['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _registeredIds.contains(t['id']) ? Colors.green : const Color(0xFF6366F1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(_registeredIds.contains(t['id']) ? 'Registered' : 'Register'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

