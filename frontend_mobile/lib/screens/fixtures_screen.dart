import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key});
  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}
class _FixturesScreenState extends State<FixturesScreen> {
  List<dynamic> tournaments = [], matches = [];
  int? selected;
  DateTime? start;
  bool busy = false;
  final interval = TextEditingController(text: '120');
  final venue = TextEditingController();
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { interval.dispose(); venue.dispose(); super.dispose(); }
  Future<void> load() async { try { final r = await ApiService().dio.get('/tournaments'); if (mounted) setState(() => tournaments = r.data['data']); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load tournaments'))); } }
  Future<void> generate() async {
    if (selected == null || start == null) return;
    setState(() => busy = true);
    try { final r = await ApiService().dio.post('/tournaments/$selected/fixtures', data: {'scheduledAt': start!.toUtc().toIso8601String(), 'intervalMinutes': int.tryParse(interval.text), 'venue': venue.text}); if (mounted) setState(() => matches = r.data['data']); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate fixtures: $e'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Generate fixtures')), body: ListView(padding: const EdgeInsets.all(16), children: [
    const Text('League generates all pairs. Knockout generates each round after the current results are complete. Only paid or free teams are eligible.'),
    DropdownButtonFormField<int>(initialValue: selected, isExpanded: true, items: tournaments.map((t) => DropdownMenuItem<int>(value: t['id'], child: Text(t['name']))).toList(), onChanged: (v) => setState(() => selected = v), decoration: const InputDecoration(labelText: 'Tournament')),
    TextButton(onPressed: () async { final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (date == null || !context.mounted) return; final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0)); if (time != null && mounted) setState(() => start = DateTime(date.year, date.month, date.day, time.hour, time.minute)); }, child: Text(start == null ? 'Choose first match time' : start.toString())),
    TextField(controller: interval, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes between matches')),
    TextField(controller: venue, decoration: const InputDecoration(labelText: 'Venue')),
    ElevatedButton(onPressed: busy ? null : generate, child: Text(busy ? 'Generating…' : 'Generate and save')),
    ...matches.map((m) => ListTile(title: Text('${m['team1']} vs ${m['team2']}'), subtitle: Text('${m['round']} · ${m['scheduledAt']}'))),
  ]));
}
