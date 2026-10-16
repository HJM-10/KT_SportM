import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}
class _CheckInScreenState extends State<CheckInScreen> {
  final token = TextEditingController();
  bool busy = false;
  String? result;
  @override
  void dispose() { token.dispose(); super.dispose(); }
  Future<void> checkIn() async {
    setState(() { busy = true; result = null; });
    try {
      var value = token.text.trim();
      try { value = (jsonDecode(value) as Map)['token'] ?? value; } catch (_) {}
      final r = await ApiService().dio.post('/bookings/scan', data: {'qrToken': value});
      if (mounted) setState(() => result = 'Checked in booking #${r.data['data']['id']} for ${r.data['data']['user']['name']}');
    } catch (e) { if (mounted) setState(() => result = e is DioException ? e.response?.data['message'] ?? 'Could not verify booking' : 'Could not verify booking'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Booking check-in')), body: ListView(padding: const EdgeInsets.all(16), children: [const Text('Enter the booking token displayed with the customer QR card, or paste its decoded QR contents. Only confirmed, unused bookings are accepted.'), TextField(controller: token, decoration: const InputDecoration(labelText: 'QR token or decoded QR contents')), const SizedBox(height: 16), ElevatedButton(onPressed: busy ? null : checkIn, child: Text(busy ? 'Verifying…' : 'Verify and check in')), if (result != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(result!))]));
}
