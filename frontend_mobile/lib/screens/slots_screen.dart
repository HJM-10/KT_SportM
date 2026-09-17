import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';

class SlotsScreen extends StatefulWidget {
  final int venueId;
  const SlotsScreen({super.key, required this.venueId});
  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}
class _SlotsScreenState extends State<SlotsScreen> {
  DateTime date = DateTime.now();
  List<dynamic> slots = [];
  bool loading = true;
  bool booking = false;
  String? error;
  final promo = TextEditingController();
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { promo.dispose(); super.dispose(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final response = await ApiService().dio.get('/bookings/slots', queryParameters: {'venueId': widget.venueId, 'date': DateFormat('yyyy-MM-dd').format(date)});
      if (mounted) setState(() => slots = response.data['data']);
    } catch (_) { if (mounted) setState(() => error = 'Could not load slots. Please retry.'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> reserve(int id) async {
    setState(() => booking = true);
    try {
      final response = await ApiService().dio.post('/bookings', data: {'slotId': id, 'promoCode': promo.text.trim()});
      if (!mounted) return;
      final record = response.data['data'];
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reservation created. Complete payment to confirm.')));
      if ((record['finalPrice'] as num) > 0) await PaymentService.checkout(record['paymentId']);
      await load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not complete checkout. Check My Bookings before trying again.')));
      if (mounted) await load();
    } finally { if (mounted) setState(() => booking = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Available slots')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      OutlinedButton(onPressed: booking ? null : () async {
        final selected = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (selected != null && mounted) { setState(() => date = selected); await load(); }
      }, child: Text(DateFormat.yMMMd().format(date))),
      TextField(controller: promo, decoration: const InputDecoration(labelText: 'Promo code (optional)')),
      if (loading) const Center(child: CircularProgressIndicator())
      else if (error != null) TextButton(onPressed: load, child: Text(error!))
      else if (slots.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No slots on this date. Choose another date.')),
      if (!loading) ...slots.map((slot) => Card(child: ListTile(
        title: Text('${slot['startTime']} – ${slot['endTime']}'),
        trailing: ElevatedButton(onPressed: booking || slot['isBooked'] == true ? null : () => reserve(slot['id']), child: Text(slot['isBooked'] == true ? 'Unavailable' : 'Reserve')),
      ))),
    ]),
  );
}

