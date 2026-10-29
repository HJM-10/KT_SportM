import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_errors.dart';
import '../services/api_service.dart';
import '../services/live_refresh.dart';
import '../widgets/clubhouse.dart';

typedef _Record = Map<String, dynamic>;
List<_Record> _records(dynamic data) =>
    (data as List).map((e) => _Record.from(e)).toList();
String _venue(_Record item) =>
    '${item['venue']?['name'] ?? 'Shared inventory'}';
String _status(dynamic status) =>
    const {
      'PENDING_PAYMENT': 'Awaiting payment',
      'CONFIRMED': 'Confirmed',
      'RETURNED': 'Returned',
      'CANCELLED': 'Cancelled',
      'PENDING': 'Pending',
      'PAID': 'Paid',
      'FAILED': 'Failed',
      'REFUNDED': 'Refunded',
    }[status] ??
    'Unavailable';
DateTime _today() =>
    DateUtils.dateOnly(DateTime.now().toUtc().add(const Duration(hours: 5)));
String _date(dynamic date) =>
    DateFormat('d MMM yyyy').format(DateTime.parse('$date'));

class AdminEquipmentScreen extends StatefulWidget {
  final int? venueId;
  const AdminEquipmentScreen({super.key, this.venueId});
  @override
  State<AdminEquipmentScreen> createState() => _AdminEquipmentScreenState();
}

class _AdminEquipmentScreenState extends State<AdminEquipmentScreen>
    with LiveRefresh<AdminEquipmentScreen>, WidgetsBindingObserver {
  final _search = TextEditingController();
  List<_Record> _items = [], _rentals = [];
  String? _inventoryError, _rentalError;
  bool _inventoryLoading = true, _rentalsLoading = true;
  int _tab = 0, _inventoryRequest = 0, _rentalRequest = 0;
  String _stockFilter = 'All', _rentalFilter = 'All';
  @override
  List<String> get liveResources =>
      ['equipment', 'payments', 'venues', 'sports'];
  @override
  Future<void> refreshForLiveUpdates() => _load();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadInventory(), _loadRentals()]);
  }

  Future<void> _loadInventory() async {
    final request = ++_inventoryRequest;
    setState(() {
      _inventoryLoading = true;
      _inventoryError = null;
    });
    try {
      final response =
          await ApiService().dio.get('/equipment', queryParameters: {
        if (widget.venueId != null) 'venueId': widget.venueId,
      });
      if (mounted && request == _inventoryRequest) {
        setState(() => _items = _records(response.data['data']));
      }
    } catch (e) {
      if (mounted && request == _inventoryRequest) {
        setState(() => _inventoryError = apiErrorMessage(e));
      }
    } finally {
      if (mounted && request == _inventoryRequest) {
        setState(() => _inventoryLoading = false);
      }
    }
  }

  Future<void> _loadRentals() async {
    final request = ++_rentalRequest;
    setState(() {
      _rentalsLoading = true;
      _rentalError = null;
    });
    try {
      final response = await ApiService().dio.get('/equipment/rentals/all');
      if (mounted && request == _rentalRequest) {
        setState(() => _rentals = _records(response.data['data'])
            .where((r) =>
                widget.venueId == null ||
                r['equipment']?['venueId'] == widget.venueId ||
                r['equipment']?['venue']?['id'] == widget.venueId)
            .toList());
      }
    } catch (e) {
      if (mounted && request == _rentalRequest) {
        setState(() => _rentalError = apiErrorMessage(e));
      }
    } finally {
      if (mounted && request == _rentalRequest) {
        setState(() => _rentalsLoading = false);
      }
    }
  }

  Future<void> _edit([_Record? item]) async {
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                EquipmentEditorScreen(item: item, venueId: widget.venueId)));
    if (changed == true && mounted) await _loadInventory();
  }

  Future<void> _rental(_Record rental) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => AdminRentalScreen(rental: rental)));
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim().toLowerCase();
    final items = _items
        .where((i) =>
            (_stockFilter == 'All' ||
                (_stockFilter == 'Active'
                    ? i['isActive'] == true
                    : i['isActive'] != true)) &&
            [i['name'], i['brand'], i['sport']?['name'], _venue(i)]
                .join(' ')
                .toLowerCase()
                .contains(query))
        .toList();
    final rentals = _rentals
        .where((r) =>
            (_tab == 1
                ? ['PENDING_PAYMENT', 'CONFIRMED'].contains(r['status'])
                : !['PENDING_PAYMENT', 'CONFIRMED'].contains(r['status'])) &&
            (_rentalFilter == 'All' || _status(r['status']) == _rentalFilter) &&
            [
              r['id'],
              r['equipment']?['name'],
              r['user']?['name'],
              _venue(_Record.from(r['equipment']))
            ].join(' ').toLowerCase().contains(query))
        .toList();
    final loading = _tab == 0 ? _inventoryLoading : _rentalsLoading;
    final error = _tab == 0 ? _inventoryError : _rentalError;
    final count = _tab == 0 ? items.length : rentals.length;
    final filters = _tab == 0
        ? ['All', 'Active', 'Inactive']
        : _tab == 1
            ? ['All', 'Awaiting payment', 'Confirmed']
            : ['All', 'Returned', 'Cancelled'];
    return Scaffold(
      appBar: AppBar(title: const Text('Equipment management')),
      body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    sliver: SliverToBoxAdapter(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Gear, under control.',
                              style: theme.textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          const Text(
                              'Manage stock, prices and equipment returns.'),
                          const SizedBox(height: 20),
                          SegmentedButton<int>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                    value: 0, label: Text('Inventory')),
                                ButtonSegment(value: 1, label: Text('Rentals')),
                                ButtonSegment(value: 2, label: Text('History'))
                              ],
                              selected: {_tab},
                              onSelectionChanged: (v) => setState(() {
                                    _tab = v.first;
                                    _rentalFilter = 'All';
                                    _search.clear();
                                  })),
                          const SizedBox(height: 16),
                          TextField(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  labelText: _tab == 0
                                      ? 'Search equipment or venue'
                                      : 'Search gear, customer or rental ID',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () =>
                                              setState(_search.clear),
                                          icon: const Icon(Icons.close)))),
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: filters
                                  .map((f) => ChoiceChip(
                                      label: Text(f),
                                      selected: (_tab == 0
                                              ? _stockFilter
                                              : _rentalFilter) ==
                                          f,
                                      onSelected: (_) => setState(() {
                                            if (_tab == 0) {
                                              _stockFilter = f;
                                            } else {
                                              _rentalFilter = f;
                                            }
                                          })))
                                  .toList()),
                          const SizedBox(height: 12),
                          if (_tab == 0) ...[
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                    onPressed: () => _edit(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add equipment'))),
                            const SizedBox(height: 16),
                          ],
                          Text(
                              _tab == 0
                                  ? '$count equipment items · Total stock shown'
                                  : '$count ${_tab == 1 ? 'active' : 'past'} rentals',
                              style: theme.textTheme.labelLarge),
                        ]))),
                if (loading)
                  const SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator())))
                else if (error != null)
                  SliverToBoxAdapter(
                      child: _AdminError(
                          message: error,
                          retry: _tab == 0 ? _loadInventory : _loadRentals))
                else if (count == 0)
                  const SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                              'No matching records. Try another search or filter.',
                              textAlign: TextAlign.center)))
                else
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverList.separated(
                        itemCount: count,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) => _tab == 0
                            ? _InventoryRow(
                                item: items[index],
                                edit: () => _edit(items[index]))
                            : ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                onTap: () => _rental(rentals[index]),
                                title: Text(
                                    '${rentals[index]['equipment']['name']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                        '${rentals[index]['user']?['name'] ?? 'Customer'} · #${rentals[index]['id']}\n${_status(rentals[index]['status'])} · ${rentals[index]['quantity']} units\n${_date(rentals[index]['rentalDate'])} – ${_date(rentals[index]['returnDate'] ?? rentals[index]['rentalDate'])}')),
                                trailing: const Icon(Icons.chevron_right)),
                      )),
              ])),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  final _Record item;
  final VoidCallback edit;
  const _InventoryRow({required this.item, required this.edit});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: edit,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(sportIcon('${item['sport']?['name']}'))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${item['name']}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_venue(item))
                  ])),
              IconButton(
                  tooltip: 'Edit ${item['name']}',
                  onPressed: edit,
                  icon: const Icon(Icons.edit_outlined)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 8, children: [
              Text('${item['quantity']} in stock',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${clubPrice(item['pricePerSlot'])} / unit / day'),
              Text(item['isActive'] == true ? 'Active' : 'Inactive')
            ]),
          ])));
}

class EquipmentEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? item;
  final int? venueId;
  const EquipmentEditorScreen({super.key, this.item, this.venueId});
  @override
  State<EquipmentEditorScreen> createState() => _EquipmentEditorScreenState();
}

class _EquipmentEditorScreenState extends State<EquipmentEditorScreen> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  List<_Record> _sports = [], _venues = [];
  int? _sportId, _venueId;
  bool _active = true, _loading = true, _saving = false;
  String? _error, _saveError;
  static const _labels = {
    'name': 'Equipment name',
    'pricePerSlot': 'Daily price (PKR per unit)',
    'quantity': 'Total stock',
    'description': 'Description',
    'brand': 'Brand',
    'model': 'Model / size',
    'material': 'Material / surface',
    'ballType': 'Ball type',
    'condition': 'Condition',
    'imageUrl': 'Image URL'
  };
  @override
  void initState() {
    super.initState();
    for (final key in _labels.keys) {
      _fields[key] = TextEditingController(
          text: '${widget.item?[key] ?? ([
                'pricePerSlot',
                'quantity'
              ].contains(key) ? '0' : '')}');
    }
    _sportId =
        (widget.item?['sportId'] ?? widget.item?['sport']?['id']) as int?;
    _venueId = (widget.item?['venueId'] ??
        widget.item?['venue']?['id'] ??
        widget.venueId) as int?;
    _active = widget.item?['isActive'] != false;
    _loadChoices();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait(
          [ApiService().dio.get('/sports'), ApiService().dio.get('/venues')]);
      if (!mounted) return;
      setState(() {
        _sports = _records(result[0].data['data']);
        _venues = _records(result[1].data['data']);
        if (_sportId == null && _venueId != null) {
          final venue = _venues.where((v) => v['id'] == _venueId);
          if (venue.isNotEmpty) {
            _sportId = venue.first['sportId'] ?? venue.first['sport']?['id'];
          }
        }
        if (_sportId != null && !_sports.any((s) => s['id'] == _sportId)) {
          _error =
              'The assigned sport is unavailable. Ask staff to restore it before editing.';
        }
        if (_venueId != null && !_venues.any((v) => v['id'] == _venueId)) {
          _error =
              'The assigned venue is unavailable. Ask staff to restore it before editing.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || _error != null) return;
    final valid = _form.currentState!.validate();
    final errors = _fields.entries
        .map((e) => _validate(e.key, e.value.text))
        .whereType<String>()
        .toList();
    if (_sportId == null) errors.add('Choose a sport');
    if (!valid || errors.isNotEmpty) {
      setState(() => _saveError =
          errors.isEmpty ? 'Review the highlighted fields.' : errors.first);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final data = <String, dynamic>{
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      'sportId': _sportId,
      'venueId': _venueId,
      'isActive': _active
    };
    data['pricePerSlot'] = num.parse(_fields['pricePerSlot']!.text.trim());
    data['quantity'] = int.parse(_fields['quantity']!.text.trim());
    try {
      if (widget.item == null) {
        await ApiService().dio.post('/equipment', data: data);
      } else {
        await ApiService()
            .dio
            .put('/equipment/${widget.item!['id']}', data: data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Equipment saved.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        key: ValueKey('equipment-$key'),
        controller: _fields[key],
        enabled: !_saving,
        maxLength: ['quantity', 'pricePerSlot'].contains(key) ? null : 191,
        maxLines: key == 'description' ? 3 : 1,
        keyboardType: ['quantity', 'pricePerSlot'].contains(key)
            ? const TextInputType.numberWithOptions(decimal: true)
            : key == 'imageUrl'
                ? TextInputType.url
                : TextInputType.text,
        decoration: InputDecoration(labelText: _labels[key], counterText: ''),
        validator: (value) => _validate(key, value),
      ));
  String? _validate(String key, String? value) {
    final text = (value ?? '').trim();
    if (!['pricePerSlot', 'quantity'].contains(key) && text.length > 191) {
      return 'Keep ${_labels[key]} within 191 characters';
    }
    if (key == 'name' && text.isEmpty) return 'Enter an equipment name';
    if (key == 'pricePerSlot') {
      final n = num.tryParse(text);
      if (n == null || !n.isFinite || n < 0) {
        return 'Enter a price of zero or more';
      }
    }
    if (key == 'quantity') {
      final n = int.tryParse(text);
      if (n == null || n < 0 || n > 9007199254740991) {
        return 'Enter a whole stock quantity of zero or more';
      }
    }
    if (key == 'imageUrl' && text.isNotEmpty) {
      final uri = Uri.tryParse(text);
      if (uri == null ||
          !(text.startsWith('/') && !text.startsWith('//') ||
              ['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty)) {
        return 'Use an HTTP(S) image URL or /path';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final venues = _venues
        .where((v) => (v['sportId'] ?? v['sport']?['id']) == _sportId)
        .toList();
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(
              title: Text(
                  widget.item == null ? 'Add equipment' : 'Edit equipment')),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_saveError != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FormError(message: _saveError!)),
                        FilledButton(
                            onPressed: _saving || _loading || _error != null
                                ? null
                                : _save,
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                    _saving ? 'Saving…' : 'Save equipment')))
                      ]))),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _AdminError(message: _error!, retry: _loadChoices)
                  : Form(
                      key: _form,
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Text('Equipment details',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            const Text(
                                'Set the daily rate and total rentable stock. Active rentals can prevent stock reductions or reassignment.'),
                            const SizedBox(height: 24),
                            _field('name'),
                            DropdownButtonFormField<int>(
                                initialValue: _sportId,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'Sport'),
                                items: _sports
                                    .map((s) => DropdownMenuItem<int>(
                                        value: s['id'],
                                        child: Text('${s['name']}',
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                validator: (v) =>
                                    v == null ? 'Choose a sport' : null,
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() {
                                          _sportId = v;
                                          _venueId = null;
                                        })),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<int>(
                                key: ValueKey('venue-$_sportId-$_venueId'),
                                initialValue:
                                    venues.any((v) => v['id'] == _venueId)
                                        ? _venueId
                                        : null,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Collection venue'),
                                items: [
                                  const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('Shared inventory')),
                                  ...venues.map((v) => DropdownMenuItem<int>(
                                      value: v['id'],
                                      child: Text('${v['name']}',
                                          overflow: TextOverflow.ellipsis)))
                                ],
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _venueId = v)),
                            const SizedBox(height: 18),
                            _field('pricePerSlot'),
                            _field('quantity'),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Available for rental'),
                                subtitle: const Text(
                                    'Turn off to stop new rentals. Existing rental records remain.'),
                                value: _active,
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _active = v)),
                            const Divider(height: 36),
                            Text('Specifications & image',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            const Text(
                                'Optional details customers can review before renting.'),
                            const SizedBox(height: 24),
                            for (final key in [
                              'brand',
                              'model',
                              'material',
                              'ballType',
                              'condition',
                              'description',
                              'imageUrl'
                            ])
                              _field(key),
                          ])),
        ));
  }
}

class AdminRentalScreen extends StatefulWidget {
  final Map<String, dynamic> rental;
  const AdminRentalScreen({super.key, required this.rental});
  @override
  State<AdminRentalScreen> createState() => _AdminRentalScreenState();
}

class _AdminRentalScreenState extends State<AdminRentalScreen> {
  final _form = GlobalKey<FormState>();
  final _damaged = TextEditingController(text: '0'),
      _notes = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _damaged.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _act(bool returning) async {
    if (_busy || returning && !_form.currentState!.validate()) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(
                    returning ? 'Record this return?' : 'Cancel this rental?'),
                content: Text(returning
                    ? 'Confirm staff has received and inspected all rented units. Damaged units leave rentable stock. No automatic damage charge.'
                    : 'This releases the reservation. Paid amounts enter the refund queue.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(returning
                          ? 'Confirm return'
                          : 'Confirm cancellation'))
                ]));
    if (ok != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService().dio.post(
          '/equipment/rentals/${widget.rental['id']}/${returning ? 'return' : 'cancel'}',
          data: returning
              ? {
                  'damagedQuantity': int.parse(_damaged.text.trim()),
                  'damageNotes': _notes.text.trim()
                }
              : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(returning
                ? 'Return recorded. Inventory updated.'
                : 'Rental cancelled. Any paid amount is queued for refund.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rental;
    final item = _Record.from(r['equipment']);
    final confirmed = r['status'] == 'CONFIRMED';
    final canReturn = confirmed &&
        !DateTime.parse('${r['rentalDate']}'.substring(0, 10))
            .isAfter(_today());
    final canCancel = ['PENDING_PAYMENT', 'CONFIRMED'].contains(r['status']);
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: Text('Rental #${r['id']}')),
          body: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Text('${item['name']}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(label: Text(_status(r['status'])))),
                const SizedBox(height: 20),
                _Detail(
                    label: 'Customer',
                    value: '${r['user']?['name'] ?? 'Customer'}'),
                _Detail(label: 'Collection inventory', value: _venue(item)),
                _Detail(
                    label: 'Rental dates',
                    value:
                        '${_date(r['rentalDate'])} – ${_date(r['returnDate'] ?? r['rentalDate'])}'),
                _Detail(label: 'Quantity', value: '${r['quantity']} units'),
                _Detail(label: 'Total', value: clubPrice(r['totalPrice'])),
                _Detail(
                    label: 'Payment', value: _status(r['payment']?['status'])),
                if (r['returnedAt'] != null)
                  _Detail(label: 'Returned', value: _date(r['returnedAt'])),
                if (r['damagedQuantity'] != null)
                  _Detail(
                      label: 'Damaged units recorded',
                      value: '${r['damagedQuantity']}'),
                if (r['damageNotes'] != null)
                  _Detail(
                      label: 'Inspection notes', value: '${r['damageNotes']}'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _FormError(message: _error!)),
                if (canReturn) ...[
                  const Divider(height: 40),
                  Text('Inspect & record return',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                      'Receive all units, inspect them, then record the return.'),
                  const SizedBox(height: 24),
                  TextFormField(
                      key: const ValueKey('return-damaged'),
                      controller: _damaged,
                      enabled: !_busy,
                      decoration:
                          const InputDecoration(labelText: 'Damaged units'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final n = int.tryParse((value ?? '').trim());
                        return n == null || n < 0 || n > (r['quantity'] as num)
                            ? 'Enter a quantity from 0 to ${r['quantity']}'
                            : null;
                      }),
                  const SizedBox(height: 20),
                  TextFormField(
                      key: const ValueKey('return-notes'),
                      controller: _notes,
                      enabled: !_busy,
                      maxLength: 4000,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Inspection notes'),
                      validator: (value) =>
                          (int.tryParse(_damaged.text.trim()) ?? 0) > 0 &&
                                  (value ?? '').trim().isEmpty
                              ? 'Describe the damage'
                              : null),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: _busy ? null : () => _act(true),
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: Text(_busy ? 'Saving…' : 'Record return')),
                ] else if (confirmed)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                          'Returns can be recorded on or after the collection date.')),
                if (canCancel)
                  Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: OutlinedButton(
                          onPressed: _busy ? null : () => _act(false),
                          child: const Text('Cancel rental'))),
              ])),
        ));
  }
}

class _Detail extends StatelessWidget {
  final String label, value;
  const _Detail({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyLarge)
      ]));
}

class _FormError extends StatelessWidget {
  final String message;
  const _FormError({required this.message});
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Text(message,
          style: TextStyle(color: Theme.of(context).colorScheme.error)));
}

class _AdminError extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const _AdminError({required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'))
      ]));
}
