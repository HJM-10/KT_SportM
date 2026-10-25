import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/api_errors.dart';
import '../widgets/arena_desk.dart';
import '../widgets/clubhouse.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _token = TextEditingController();
  bool _busy = false, _success = false;
  String? _result;
  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    if (_busy) return;
    var value = _token.text.trim();
    if (value.isEmpty) {
      setState(() {
        _success = false;
        _result = 'Enter an entry token or decoded QR contents.';
      });
      return;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map && decoded['token'] is String) {
        value = decoded['token'];
      }
    } catch (_) {}
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final response = await ApiService()
          .dio
          .post('/bookings/scan', data: {'qrToken': value});
      if (mounted) {
        setState(() {
          _success = true;
          _result =
              'Checked in booking #${response.data['data']['id']} for ${response.data['data']['user']['name']}.';
          _token.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _success = false;
          _result = apiErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
        appBar: AppBar(title: const Text('Verify an entry pass')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ArenaIcon(ArenaSymbol.scan, size: 48, color: colors.secondary),
          const SizedBox(height: 24),
          const ClubhouseHeading('A warm welcome.',
              subtitle: 'Verify a confirmed booking’s single-use entry pass.'),
          const SizedBox(height: 20),
          Text(
              'Paste a token or decoded QR contents from your scanner. You can also check in a listed booking from Arena Desk after confirming the customer has arrived.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 24),
          TextField(
              controller: _token,
              enabled: !_busy,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Entry token or decoded QR contents')),
          const SizedBox(height: 20),
          ElevatedButton.icon(
              onPressed: _busy ? null : _checkIn,
              icon: const ArenaIcon(ArenaSymbol.scan,
                  size: 20, color: Colors.white),
              label: Text(_busy ? 'Verifying…' : 'Verify and check in')),
          if (_result != null) ...[
            const SizedBox(height: 20),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(_result!,
                        style: TextStyle(
                            color: _success ? colors.primary : colors.error,
                            height: 1.4))))
          ],
        ]));
  }
}
