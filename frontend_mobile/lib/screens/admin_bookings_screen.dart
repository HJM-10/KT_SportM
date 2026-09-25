import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.dio.get('/bookings');
      if (mounted) setState(() { _bookings = res.data['data']; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmBooking(int id) async {
    try {
      await _apiService.dio.put('/bookings/$id/confirm');
      _fetchBookings();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to confirm')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Bookings')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final b = _bookings[index];
          return ListTile(
            title: Text('${b['slot']?['venue']?['name'] ?? 'Venue'} - ${b['status']}'),
            subtitle: Text('User: ${b['user']?['name'] ?? 'Walk-in'}'),
            trailing: b['status'] == 'PENDING' ? IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _confirmBooking(b['id'])) : null,
          );
        },
      ),
    );
  }
}
