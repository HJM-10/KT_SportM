import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final res = await _apiService.dio.get('/events');
      if (!mounted) return;
      setState(() {
        _events = res.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerEvent(int eventId, num fee) async {
    try {
      final res = await _apiService.dio.post('/events/$eventId/register');
      if (res.data['success']) {
        if (res.data['data']['paymentId'] != null) await PaymentService.checkout(res.data['data']['paymentId']);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully! Complete payment to confirm.')),
        );
        _fetchEvents();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events & Camps')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              final ev = _events[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ev['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(ev['type'], style: const TextStyle(color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(ev['description'], style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      Text('Venue: ${ev['venue']}'),
                      Text('Fee: Rs. ${ev['fee']}'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: ev['status'] == 'UPCOMING' ? () => _registerEvent(ev['id'], ev['fee']) : null,
                          child: Text(ev['status'] == 'UPCOMING' ? 'Register Now' : 'Closed'),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          )
    );
  }
}


