import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SlotsScreen extends StatefulWidget {
  final int venueId;
  final int? rescheduleBookingId;
  const SlotsScreen({super.key, required this.venueId, this.rescheduleBookingId});
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
  void initState() { super.initState(); load(); ApiService().socket.on('booking_updated', onUpdate); }
  void onUpdate(dynamic _) { if (mounted) load(); }
  @override
  void dispose() { ApiService().socket.off('booking_updated', onUpdate); promo.dispose(); super.dispose(); }
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
      if (widget.rescheduleBookingId != null) {
        await ApiService().dio.put('/bookings/${widget.rescheduleBookingId}/reschedule', data: {'slotId': id});
        if (mounted) Navigator.pop(context);
        return;
      }
      final response = await ApiService().dio.post('/bookings', data: {'slotId': id, 'promoCode': promo.text.trim()});
      if (!mounted) return;
      final record = response.data['data'];
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reservation created. Complete payment to confirm.')));
      if ((record['finalPrice'] as num) > 0) await PaymentService.checkout(record['paymentId']);
      await load();
    } catch (e) {
      final String msg = e is DioException && e.response?.data?['message'] != null 
          ? e.response!.data!['message'] 
          : 'Could not complete checkout. Check My Bookings before trying again.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (mounted) await load();
    } finally { if (mounted) setState(() => booking = false); }
  }
  Future<void> publishSlot() async {
    final start = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (start == null || !mounted) return;
    final end = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (end == null || !mounted) return;
    String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    try { await ApiService().dio.post('/bookings/slots', data: {'venueId': widget.venueId, 'date': DateFormat('yyyy-MM-dd').format(date), 'startTime': hhmm(start), 'endTime': hhmm(end)}); if (mounted) await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is DioException ? e.response?.data['message'] ?? 'Could not publish slot' : 'Could not publish slot'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Available slots')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (context.watch<AuthProvider>().user?['role'] == 'ADMIN') OutlinedButton(onPressed: publishSlot, child: const Text('Publish a slot for selected date')),
      OutlinedButton(onPressed: booking ? null : () async {
        final selected = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (selected != null && mounted) { setState(() => date = selected); await load(); }
      }, child: Text(DateFormat.yMMMd().format(date))),
      TextField(controller: promo, decoration: const InputDecoration(labelText: 'Promo code (optional)')),
      if (loading) const Center(child: CircularProgressIndicator())
      else if (error != null) TextButton(onPressed: load, child: Text(error!))
      else if (slots.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No slots on this date. Choose another date.')),
      if (!loading) ...slots.map((slot) {
        final slotDateStr = (slot['date'] as String).split('T')[0];
        final slotTimeStr = slot['startTime'] as String;
        final slotDateTime = DateTime.parse('${slotDateStr}T$slotTimeStr:00');
        final isPast = slotDateTime.isBefore(DateTime.now());
        final isUnavailable = slot['isBooked'] == true || isPast;
        return Card(child: ListTile(
          title: Text('${slot['startTime']} – ${slot['endTime']}'),
          trailing: ElevatedButton(
            onPressed: booking || isUnavailable ? null : () => reserve(slot['id']),
            child: Text(slot['isBooked'] == true ? 'Booked' : isPast ? 'Passed' : 'Reserve'),
          ),
        ));
      }),
    ]),
  );
}

