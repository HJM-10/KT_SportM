import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/api_errors.dart';
import '../../widgets/clubhouse.dart';

class AdminVenueEditor extends StatefulWidget {
  final Map<String, dynamic>? venue;
  final List<Map<String, dynamic>> sports;
  const AdminVenueEditor({super.key, this.venue, required this.sports});
  @override
  State<AdminVenueEditor> createState() => _AdminVenueEditorState();
}

class _AdminVenueEditorState extends State<AdminVenueEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _description = TextEditingController(),
      _price = TextEditingController(),
      _capacity = TextEditingController(),
      _image = TextEditingController();
  int? _sportId;
  bool _active = true, _saving = false;
  @override
  void initState() {
    super.initState();
    final v = widget.venue;
    _name.text = v?['name'] ?? '';
    _description.text = v?['description'] ?? '';
    _price.text = '${v?['pricePerSlot'] ?? 0}';
    _capacity.text = v?['capacity']?.toString() ?? '';
    _image.text = v?['imageUrl'] ?? '';
    _sportId = v?['sportId'] ??
        v?['sport']?['id'] ??
        (widget.sports.isEmpty ? null : widget.sports.first['id']);
    _active = v?['isActive'] ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _capacity, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate() || _sportId == null) return;
    setState(() => _saving = true);
    try {
      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'sportId': _sportId,
        'pricePerSlot': num.parse(_price.text),
        'capacity':
            _capacity.text.trim().isEmpty ? null : int.parse(_capacity.text),
        'imageUrl': _image.text.trim().isEmpty ? null : _image.text.trim(),
        'isActive': _active
      };
      if (widget.venue == null) {
        await ApiService().dio.post('/venues', data: data);
      } else {
        await ApiService()
            .dio
            .put('/venues/${widget.venue!['id']}', data: data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.venue == null
              ? 'Add a court or facility'
              : 'Edit facility')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const ClubhouseHeading('A place to play.',
                subtitle:
                    'Each facility has its own published sessions and price.'),
            const SizedBox(height: 24),
            TextFormField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Facility name'),
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? 'Enter a facility name.'
                    : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
                initialValue: _sportId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sport'),
                items: widget.sports
                    .map((s) => DropdownMenuItem<int>(
                        value: s['id'],
                        child:
                            Text(s['name'], overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged:
                    _saving ? null : (id) => setState(() => _sportId = id),
                validator: (v) => v == null ? 'Choose a sport.' : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _description,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 16),
            TextFormField(
                controller: _price,
                enabled: !_saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Price per session (PKR)'),
                validator: (v) {
                  final n = num.tryParse(v ?? '');
                  return n == null || !n.isFinite || n < 0
                      ? 'Enter a valid non-negative price.'
                      : null;
                }),
            const SizedBox(height: 16),
            TextFormField(
                controller: _capacity,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Capacity (optional)'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? null
                    : (int.tryParse(v) == null || int.parse(v) < 1
                        ? 'Enter a positive whole number.'
                        : null)),
            const SizedBox(height: 16),
            TextFormField(
                controller: _image,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Venue photo URL (optional)',
                    helperText:
                        'A matching sport image is used when no photo is supplied.',
                    helperMaxLines: 3),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final uri = Uri.tryParse(v.trim());
                  return uri != null &&
                          ['https', 'http'].contains(uri.scheme) &&
                          uri.host.isNotEmpty
                      ? null
                      : 'Enter a full HTTP or HTTPS image URL.';
                }),
            const SizedBox(height: 16),
            if (widget.venue != null)
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for booking'),
                  subtitle: const Text(
                      'Turning this off hides the facility from customers. Existing bookings remain in the schedule.'),
                  value: _active,
                  onChanged:
                      _saving ? null : (v) => setState(() => _active = v)),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _saving || widget.sports.isEmpty ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save facility')),
          ])));
}
