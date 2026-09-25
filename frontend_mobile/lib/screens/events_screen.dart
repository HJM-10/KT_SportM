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
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _apiService.dio.get('/events');
      if (!mounted) return;
      setState(() {
        _events = res.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Failed to load events. Tap to retry.'; });
    }
  }

  Future<void> _registerEvent(int eventId) async {
    try {
      final res = await _apiService.dio.post('/events/$eventId/register');
      if (res.data['success']) {
        if (res.data['data']?['paymentId'] != null) {
          await PaymentService.checkout(res.data['data']['paymentId']);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered! Complete payment to confirm your spot.')),
        );
        _fetchEvents();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((e as dynamic).response?.data?['message'] ?? 'Registration failed')),
      );
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'UPCOMING': return const Color(0xFF6366F1);
      case 'ONGOING': return Colors.orange;
      case 'COMPLETED': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'TRAINING': return '🎯 Training';
      case 'COACHING': return '🏫 Coaching';
      case 'CAMP': return '⛺ Camp';
      case 'LEAGUE': return '🏆 League';
      case 'FRIENDLY': return '🤝 Friendly';
      default: return type ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events & Camps')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchEvents, child: const Text('Retry')),
                    ],
                  ),
                )
              : _events.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No events scheduled', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchEvents,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final ev = _events[index];
                          final bool isUpcoming = ev['status'] == 'UPCOMING';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: name + status badge
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ev['name'] ?? 'Event',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statusColor(ev['status'] as String?).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          ev['status'] ?? '',
                                          style: TextStyle(
                                            color: _statusColor(ev['status'] as String?),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Type label
                                  Text(
                                    _typeLabel(ev['type'] as String?),
                                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),

                                  // Description — null safe
                                  if ((ev['description'] as String?) != null && (ev['description'] as String).isNotEmpty)
                                    Text(
                                      ev['description'] as String,
                                      style: const TextStyle(color: Colors.grey),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                  const SizedBox(height: 12),

                                  // Venue — null safe
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        (ev['venue'] as String?) ?? 'Venue TBA',
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Fee
                                  Row(
                                    children: [
                                      const Icon(Icons.payments_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        (ev['fee'] != null && (ev['fee'] as num) > 0)
                                            ? 'Rs. ${ev['fee']}'
                                            : 'Free',
                                        style: TextStyle(
                                          color: (ev['fee'] != null && (ev['fee'] as num) > 0)
                                              ? Colors.green
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Register button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: isUpcoming ? () => _registerEvent(ev['id'] as int) : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isUpcoming ? const Color(0xFF6366F1) : Colors.grey.shade600,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                        isUpcoming ? 'Register Now' : ev['status'] ?? 'Closed',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
