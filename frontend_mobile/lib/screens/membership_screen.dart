import '../services/live_refresh.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen>
    with LiveRefresh<MembershipScreen> {
  @override
  List<String> get liveResources => ['membership', 'payments'];
  @override
  Future<void> refreshForLiveUpdates() => _fetchMembership();
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _membership;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembership();
  }

  Future<void> _fetchMembership() async {
    try {
      final res = await _apiService.dio.get('/membership/my');
      if (!mounted) return;
      setState(() {
        _membership = res.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseTier(String tier) async {
    try {
      final res = await _apiService.dio
          .post('/membership/purchase', data: {'tier': tier});
      if (res.data['success']) {
        if (res.data['data']['paymentId'] != null) {
          await PaymentService.checkout(res.data['data']['paymentId']);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Membership request submitted! Complete payment to activate.')));
        _fetchMembership();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to purchase')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Memberships')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_membership != null) ...[
                    Card(
                  color: const Color(0xFFE8D6A9),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text('Current Tier: ${_membership!['tier']}',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            const SizedBox(height: 8),
                            Text('Card: ${_membership!['cardNumber']}',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black87)),
                            const SizedBox(height: 8),
                            Text(
                                _membership!['isActive']
                                    ? 'ACTIVE'
                                    : 'PENDING PAYMENT',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text('Available Tiers',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildTierCard(
                      'SILVER', '10% Discount on all bookings', 1000),
                  _buildTierCard('GOLD', '20% Discount on all bookings', 2500),
                ],
              ));
  }

  Widget _buildTierCard(String tier, String desc, int price) {
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
                Text(tier,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Rs. $price / yr',
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(desc),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _purchaseTier(tier),
                child: const Text('Upgrade'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
