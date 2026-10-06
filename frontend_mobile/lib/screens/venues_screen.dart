import '../services/live_refresh.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'slots_screen.dart';

class VenuesScreen extends StatefulWidget {
  final int sportId;
  final String sportName;

  const VenuesScreen({super.key, required this.sportId, required this.sportName});

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> with LiveRefresh<VenuesScreen> {
  @override
  List<String> get liveResources => ['venues'];
  @override
  Future<void> refreshForLiveUpdates() => _fetchVenues();
  final ApiService _apiService = ApiService();
  List<dynamic> _venues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVenues();
  }

  Future<void> _fetchVenues() async {
    try {
      final res = await _apiService.dio.get('/venues?sportId=${widget.sportId}');
      if (mounted) {
        setState(() {
          _venues = res.data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load venues')),
        );
      }
    }
  }

  void _bookSlot(int venueId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SlotsScreen(venueId: venueId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.sportName} Venues')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _venues.isEmpty
              ? const Center(child: Text('No venues available for this sport', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _venues.length,
                  itemBuilder: (context, index) {
                    final venue = _venues[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              venue['name'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(venue['description'] ?? 'No description', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rs. ${venue['pricePerSlot']}/slot',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                                ElevatedButton(
                                  onPressed: () => _bookSlot(venue['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Book'),
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

