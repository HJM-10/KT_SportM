import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _equipment = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEquipment();
  }

  Future<void> _fetchEquipment() async {
    try {
      final res = await _apiService.dio.get('/equipment');
      if (!mounted) return;
      setState(() {
        _equipment = res.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rentEquipment(int eqId, num price) async {
    try {
      final rentalDate = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
      final res = await _apiService.dio.post('/equipment/$eqId/rent', data: {
        'quantity': 1,
        'rentalDate': rentalDate
      });
      if (res.data['success']) {
        if (res.data['data']['paymentId'] != null) await PaymentService.checkout(res.data['data']['paymentId']);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rental requested! Complete payment to confirm.')),
        );
        _fetchEquipment();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rent equipment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipment Rental')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16
            ),
            itemCount: _equipment.length,
            itemBuilder: (context, index) {
              final eq = _equipment[index];
              final isAvailable = eq['isActive'] && eq['quantity'] > 0;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: Icon(Icons.sports_soccer, size: 48, color: Colors.blue)),
                      const Spacer(),
                      Text(eq['name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Rs. ${eq['pricePerSlot']} / slot', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${eq['quantity']} available', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isAvailable ? () => _rentEquipment(eq['id'], eq['pricePerSlot']) : null,
                          child: const Text('Rent'),
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


