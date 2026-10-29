import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_errors.dart';
import '../services/api_service.dart';
import '../services/live_refresh.dart';
import '../services/payment_service.dart';
import '../widgets/clubhouse.dart';

DateTime _today() =>
    DateUtils.dateOnly(DateTime.now().toUtc().add(const Duration(hours: 5)));
String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String _range(DateTimeRange value) => value.start == value.end
    ? DateFormat('d MMM yyyy').format(value.start)
    : '${DateFormat('d MMM').format(value.start)} – ${DateFormat('d MMM yyyy').format(value.end)}';
int _days(DateTimeRange range) =>
    DateTime.utc(range.end.year, range.end.month, range.end.day)
        .difference(
            DateTime.utc(range.start.year, range.start.month, range.start.day))
        .inDays +
    1;
String _venue(Map<String, dynamic> item) =>
    item['venue']?['name']?.toString() ?? 'Shared inventory';
int _available(Map<String, dynamic> item) =>
    (item['availableQuantity'] as num?)?.toInt() ?? 0;
bool _rentable(Map<String, dynamic> item) =>
    item['isActive'] == true &&
    item['sport']?['isActive'] != false &&
    item['venue']?['isActive'] != false &&
    _available(item) > 0;

Future<DateTimeRange?> _pickRange(
    BuildContext context, DateTimeRange range) async {
  final today = _today();
  final start = range.start.isBefore(today) ? today : range.start;
  return showDateRangePicker(
    context: context,
    firstDate: today,
    lastDate: today.add(const Duration(days: 365)),
    initialDateRange: DateTimeRange(
        start: start, end: range.end.isBefore(start) ? start : range.end),
    helpText: 'Rental dates · up to 90 days',
    selectableDayPredicate: (day, selectedStart, selectedEnd) =>
        selectedStart == null ||
        selectedEnd != null ||
        day.isBefore(selectedStart) ||
        day.difference(selectedStart).inDays < 90,
  );
}

class RentalShopScreen extends StatefulWidget {
  final int? venueId;
  const RentalShopScreen({super.key, this.venueId});
  @override
  State<RentalShopScreen> createState() => _RentalShopScreenState();
}

class _RentalShopScreenState extends State<RentalShopScreen>
    with WidgetsBindingObserver, LiveRefresh<RentalShopScreen> {
  final _api = ApiService();
  late DateTimeRange _dates;
  List<Map<String, dynamic>> _items = [], _rentals = [];
  String? _gearError, _rentalError, _sport, _venueFilter;
  bool _loadingGear = true, _loadingRentals = true, _history = false;
  bool _busy = false;
  int _tab = 0, _gearRequest = 0, _rentalRequest = 0;

  @override
  List<String> get liveResources => ['equipment', 'payments', 'venues'];
  @override
  Future<void> refreshForLiveUpdates() => _refresh();
  @override
  void initState() {
    super.initState();
    _dates = DateTimeRange(start: _today(), end: _today());
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadGear(), _loadRentals()]);
  }

  Future<void> _loadGear() async {
    final request = ++_gearRequest;
    setState(() {
      _loadingGear = true;
      _gearError = null;
    });
    try {
      final response = await _api.dio.get('/equipment', queryParameters: {
        'rentalDate': _date(_dates.start),
        'returnDate': _date(_dates.end),
        if (widget.venueId != null) 'venueId': widget.venueId,
      });
      if (!mounted || request != _gearRequest) return;
      setState(() => _items = List<Map<String, dynamic>>.from(
          (response.data['data'] as List)
              .map((e) => Map<String, dynamic>.from(e))));
    } catch (e) {
      if (mounted && request == _gearRequest) {
        setState(() => _gearError = apiErrorMessage(e));
      }
    } finally {
      if (mounted && request == _gearRequest) {
        setState(() => _loadingGear = false);
      }
    }
  }

  Future<void> _loadRentals() async {
    final request = ++_rentalRequest;
    setState(() {
      _loadingRentals = true;
      _rentalError = null;
    });
    try {
      final response = await _api.dio.get('/equipment/my-rentals');
      if (!mounted || request != _rentalRequest) return;
      setState(() => _rentals = List<Map<String, dynamic>>.from(
          (response.data['data'] as List)
              .map((e) => Map<String, dynamic>.from(e))));
    } catch (e) {
      if (mounted && request == _rentalRequest) {
        setState(() => _rentalError = apiErrorMessage(e));
      }
    } finally {
      if (mounted && request == _rentalRequest) {
        setState(() => _loadingRentals = false);
      }
    }
  }

  Future<void> _changeDates() async {
    final dates = await _pickRange(context, _dates);
    if (dates == null || !mounted) return;
    if (_days(dates) > 90) {
      _message('Choose a rental of 90 days or less.');
      return;
    }
    setState(() => _dates = dates);
    await _loadGear();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _details(Map<String, dynamic> item) async {
    final reserved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RentalDetailsScreen(item: item, dates: _dates),
    ));
    if (!mounted) return;
    if (reserved == true) {
      setState(() {
        _tab = 1;
        _history = false;
      });
    }
    await _refresh();
  }

  Future<void> _pay(Map<String, dynamic> rental) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await PaymentService.checkout(rental['payment']['id']);
    } catch (e) {
      _message(apiErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  Future<void> _cancel(Map<String, dynamic> rental) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Cancel rental?'),
              content: const Text(
                  'Paid amounts enter the refund queue. Your equipment will be released for other players.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep rental')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Cancel rental'))
              ],
            ));
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _api.dio.post('/equipment/rentals/${rental['id']}/cancel');
      _message('Rental cancelled. Any paid amount is queued for refund.');
    } catch (e) {
      _message(apiErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sports = _items
        .map((e) => e['sport']?['name']?.toString())
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final venues = _items.map(_venue).toSet().toList()..sort();
    final filtered = _items
        .where((e) =>
            (_sport == null || e['sport']?['name'] == _sport) &&
            (_venueFilter == null || _venue(e) == _venueFilter))
        .toList();
    final rentals = _rentals
        .where((r) =>
            _history != ['PENDING_PAYMENT', 'CONFIRMED'].contains(r['status']))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Equipment')),
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(_tab == 0 ? 'Gear up. Play more.' : 'Your gear, sorted.',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  _tab == 0
                      ? 'Rent from your venue.'
                      : 'Keep track of payments, collection and returns.',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Browse gear')),
                    ButtonSegment(value: 1, label: Text('My rentals'))
                  ],
                  showSelectedIcon: false,
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? theme.colorScheme.primary
                              : null),
                      foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? theme.colorScheme.onPrimary
                              : null)),
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first)),
              const SizedBox(height: 20),
              if (_tab == 0) ...[
                _DateCard(dates: _dates, onTap: _changeDates),
                const SizedBox(height: 16),
                if (widget.venueId == null && venues.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                          key: ValueKey(_venueFilter),
                          initialValue: venues.contains(_venueFilter)
                              ? _venueFilter
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Collection inventory',
                              prefixIcon: Icon(Icons.place_outlined)),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null, child: Text('All venues')),
                            ...venues.map((v) => DropdownMenuItem(
                                value: v,
                                child:
                                    Text(v, overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: (v) => setState(() => _venueFilter = v))),
                if (sports.isNotEmpty)
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: const Text('All sports'),
                                selected: _sport == null,
                                onSelected: (_) =>
                                    setState(() => _sport = null))),
                        ...sports.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(s),
                                selected: _sport == s,
                                onSelected: (_) => setState(() => _sport = s))))
                      ])),
                const SizedBox(height: 12),
                if (_loadingGear)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                else if (_gearError != null)
                  _Retry(message: _gearError!, onRetry: _loadGear)
                else if (filtered.isEmpty)
                  _Empty(
                      title: 'No gear found',
                      message:
                          'Try other filters or dates, or ask staff about equipment.',
                      action: TextButton(
                          onPressed: () => setState(() {
                                _sport = null;
                                _venueFilter = null;
                              }),
                          child: const Text('Clear filters')))
                else
                  ...filtered.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child:
                          _GearCard(item: item, onTap: () => _details(item)))),
              ] else ...[
                SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Active')),
                      ButtonSegment(value: true, label: Text('History'))
                    ],
                    selected: {
                      _history
                    },
                    onSelectionChanged: (s) =>
                        setState(() => _history = s.first)),
                const SizedBox(height: 16),
                if (_loadingRentals)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                else if (_rentalError != null)
                  _Retry(message: _rentalError!, onRetry: _loadRentals)
                else if (rentals.isEmpty)
                  _Empty(
                      title: _history
                          ? 'No past rentals yet'
                          : 'Ready for your next game?',
                      message: _history
                          ? 'Completed and cancelled rentals will appear here.'
                          : 'Your active gear rentals will appear here.',
                      action: TextButton(
                          onPressed: () => setState(() => _tab = 0),
                          child: const Text('Browse gear')))
                else
                  ...rentals.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RentalCard(
                          rental: r,
                          busy: _busy,
                          onPay: () => _pay(r),
                          onCancel: () => _cancel(r)))),
              ],
            ],
          )),
    );
  }
}

class RentalDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final DateTimeRange dates;
  const RentalDetailsScreen(
      {super.key, required this.item, required this.dates});
  @override
  State<RentalDetailsScreen> createState() => _RentalDetailsScreenState();
}

class _RentalDetailsScreenState extends State<RentalDetailsScreen>
    with LiveRefresh<RentalDetailsScreen> {
  late Map<String, dynamic> _item;
  late DateTimeRange _dates;
  final _quantity = TextEditingController(text: '1');
  final _form = GlobalKey<FormState>();
  bool _loading = true, _busy = false, _created = false;
  String? _error;
  int _request = 0;
  @override
  List<String> get liveResources => ['equipment', 'venues'];
  @override
  Future<void> refreshForLiveUpdates() => _reload();
  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _dates = widget.dates;
    _reload();
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ApiService().dio.get('/equipment', queryParameters: {
        'rentalDate': _date(_dates.start),
        'returnDate': _date(_dates.end),
        if (_item['venueId'] != null) 'venueId': _item['venueId'],
      });
      if (!mounted || request != _request) return;
      final matches =
          (response.data['data'] as List).where((e) => e['id'] == _item['id']);
      setState(() {
        if (matches.isEmpty) {
          _error = 'This equipment is no longer available.';
        } else {
          _item = Map<String, dynamic>.from(matches.first);
        }
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = apiErrorMessage(e));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _changeDates() async {
    final dates = await _pickRange(context, _dates);
    if (dates == null || !mounted) return;
    if (_days(dates) > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a rental of 90 days or less.')));
      return;
    }
    setState(() => _dates = dates);
    await _reload();
  }

  Future<void> _reserve() async {
    if (_busy ||
        _created ||
        _loading ||
        _error != null ||
        !_rentable(_item) ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final response =
          await ApiService().dio.post('/equipment/${_item['id']}/rent', data: {
        'quantity': int.parse(_quantity.text),
        'rentalDate': _date(_dates.start),
        'returnDate': _date(_dates.end),
      });
      _created = true;
      final rental = response.data['data'];
      String message = 'Rental confirmed. Arrange collection with staff.';
      if ((rental['totalPrice'] as num) > 0) {
        message = 'Your equipment is held. Complete payment to confirm.';
        try {
          await PaymentService.checkout(rental['paymentId']);
        } catch (_) {
          message =
              'Your equipment is held, but checkout could not open. Use Continue payment in My rentals.';
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
        await _reload();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = int.tryParse(_quantity.text) ?? 0;
    final rate = (_item['pricePerSlot'] as num?) ?? 0;
    final specs = <String, dynamic>{
      'Brand': _item['brand'],
      'Model / size': _item['model'],
      'Material / surface': _item['material'],
      'Ball type': _item['ballType']
    };
    specs.removeWhere(
        (_, value) => value == null || value.toString().trim().isEmpty);
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Rental details')),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            '${clubPrice(rate * (count < 0 ? 0 : count) * _days(_dates))} estimated total',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        FilledButton(
                            onPressed: _busy ||
                                    _loading ||
                                    _created ||
                                    _error != null ||
                                    !_rentable(_item)
                                ? null
                                : _reserve,
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                    _busy
                                        ? 'Reserving…'
                                        : rate == 0
                                            ? 'Reserve equipment'
                                            : 'Reserve & continue to payment',
                                    textAlign: TextAlign.center)))
                      ]))),
          body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _GearImage(item: _item, height: 156)),
                const SizedBox(height: 20),
                Text(_item['name'] ?? 'Equipment',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                    '${_venue(_item)} · ${_item['sport']?['name'] ?? 'Equipment'}',
                    style: theme.textTheme.bodyLarge),
                if ((_item['condition'] ?? '').toString().trim().isNotEmpty)
                  Align(
                      alignment: Alignment.centerLeft,
                      child:
                          Chip(label: Text('${_item['condition']} condition'))),
                if ((_item['description'] ?? '').toString().trim().isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_item['description'])),
                if (specs.isNotEmpty)
                  Card(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      child: ExpansionTile(
                          title: const Text('Equipment specifications'),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: specs.entries
                              .map((e) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('${e.key}: ${e.value}'))))
                              .toList())),
                const SizedBox(height: 12),
                _DateCard(dates: _dates, onTap: _busy ? null : _changeDates),
                const SizedBox(height: 16),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  _Retry(message: _error!, onRetry: _busy ? null : _reload),
                if (!_loading && _error == null)
                  Text(
                      _rentable(_item)
                          ? '${_available(_item)} available for these dates'
                          : 'Unavailable for these dates',
                      style: theme.textTheme.labelLarge),
                const SizedBox(height: 16),
                Form(
                    key: _form,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                              tooltip: 'Decrease quantity',
                              onPressed: _busy || count <= 1
                                  ? null
                                  : () => setState(
                                      () => _quantity.text = '${count - 1}'),
                              icon: const Icon(Icons.remove_circle_outline)),
                          Expanded(
                              child: TextFormField(
                                  key: const ValueKey('rental-quantity'),
                                  controller: _quantity,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                      labelText: 'Quantity'),
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) {
                                    final n = int.tryParse(value ?? '');
                                    return n == null ||
                                            n < 1 ||
                                            n > _available(_item)
                                        ? 'Enter an available quantity'
                                        : null;
                                  })),
                          IconButton(
                              tooltip: 'Increase quantity',
                              onPressed: _busy ||
                                      _loading ||
                                      count >= _available(_item)
                                  ? null
                                  : () => setState(
                                      () => _quantity.text = '${count + 1}'),
                              icon: const Icon(Icons.add_circle_outline)),
                        ])),
                const SizedBox(height: 20),
                Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Price breakdown',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 12),
                              Text(
                                  '${clubPrice(rate)} × $count ${count == 1 ? 'unit' : 'units'} × ${_days(_dates)} ${_days(_dates) == 1 ? 'day' : 'days'}'),
                              const Divider(height: 28),
                              Text(
                                  'Total: ${clubPrice(rate * (count < 0 ? 0 : count) * _days(_dates))}',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              const Text(
                                  'Final price and stock are checked when you reserve.'),
                            ]))),
                const SizedBox(height: 16),
                const _Notice(
                    text:
                        'Payment confirms your rental. Unpaid holds expire after 30 minutes. For shared inventory, ask staff where to collect and return your gear.'),
              ]),
        ));
  }
}

class _DateCard extends StatelessWidget {
  final DateTimeRange dates;
  final VoidCallback? onTap;
  const _DateCard({required this.dates, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero,
      child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: const Icon(Icons.date_range),
          title: Text(_range(dates),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${_days(dates)} ${_days(dates) == 1 ? 'day' : 'days'} · Both dates included'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: onTap));
}

class _GearImage extends StatelessWidget {
  final Map<String, dynamic> item;
  final double height;
  const _GearImage({required this.item, this.height = 124});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = '${item['name']}'.toLowerCase();
    final asset = name.contains('padel') && name.contains('ball')
        ? 'padel-balls'
        : name.contains('padel') &&
                (name.contains('racket') || name.contains('racquet'))
            ? 'padel-racket'
            : name.contains('cricket') && name.contains('bat')
                ? 'cricket-bat'
                : name.contains('football')
                    ? 'football'
                    : name.contains('hockey') && name.contains('stick')
                        ? 'hockey-stick'
                        : name.contains('table tennis')
                            ? 'table-tennis'
                            : null;
    Widget fallback() => ColoredBox(
        color: scheme.primaryContainer,
        child: Stack(fit: StackFit.expand, children: [
          if (asset != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset('assets/gear/$asset.png',
                    fit: BoxFit.contain,
                    cacheWidth: 650,
                    excludeFromSemantics: true))
          else
            Center(
                child: Icon(sportIcon('${item['sport']?['name']}'),
                    size: 48, color: scheme.onPrimaryContainer)),
          Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('Illustrative image',
                      style: TextStyle(fontSize: 10)))),
        ]));
    final url = '${item['imageUrl'] ?? ''}';
    final uri = Uri.tryParse(
        url.startsWith('/') ? '${ApiService().socketUrl}$url' : url);
    final illustrative =
        '${item['description']}'.toLowerCase().contains('illustrative');
    final remote = uri != null && ['http', 'https'].contains(uri.scheme);
    return Semantics(
        label: '${item['name']} equipment image',
        image: true,
        child: SizedBox(
            height: height,
            width: double.infinity,
            child: remote && !illustrative
                ? Image.network(uri.toString(),
                    fit: BoxFit.cover,
                    semanticLabel: '${item['name']}',
                    errorBuilder: (_, __, ___) => fallback(),
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : fallback())
                : fallback()));
  }
}

class _GearCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _GearCard({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item['name'] ?? 'Equipment',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                        '${_venue(item)} · ${item['sport']?['name'] ?? 'Equipment'}'),
                  ])),
              const SizedBox(width: 12),
              SizedBox(
                  width: 104,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _GearImage(item: item, height: 112)))
            ]),
            const SizedBox(height: 12),
            Text(_rentable(item)
                ? '${_available(item)} available for these dates'
                : 'Unavailable for these dates'),
            const SizedBox(height: 8),
            Text('${clubPrice(item['pricePerSlot'])} / unit / day',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: onTap,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View gear')),
          ])));
}

class _RentalCard extends StatelessWidget {
  final Map<String, dynamic> rental;
  final bool busy;
  final VoidCallback onPay, onCancel;
  const _RentalCard(
      {required this.rental,
      required this.busy,
      required this.onPay,
      required this.onCancel});
  @override
  Widget build(BuildContext context) {
    final item = Map<String, dynamic>.from(rental['equipment']);
    final status = rental['status'];
    final start = DateTime.parse(rental['rentalDate']);
    final end = DateTime.parse(rental['returnDate'] ?? rental['rentalDate']);
    final pending = status == 'PENDING_PAYMENT';
    final expires = DateTime.tryParse('${rental['payment']?['expiresAt']}');
    final expired =
        pending && expires != null && !expires.isAfter(DateTime.now());
    final canCancel = pending ||
        status == 'CONFIRMED' && _date(start).compareTo(_date(_today())) > 0;
    final label = expired
        ? 'Hold expired'
        : const {
              'PENDING_PAYMENT': 'Awaiting payment',
              'CONFIRMED': 'Confirmed',
              'RETURNED': 'Returned',
              'CANCELLED': 'Cancelled'
            }[status] ??
            'Status unavailable';
    final refunds = rental['payment']?['refunds'] as List? ?? [];
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Chip(
                  avatar: Icon(
                      pending
                          ? Icons.schedule
                          : status == 'CONFIRMED'
                              ? Icons.check_circle_outline
                              : Icons.receipt_long_outlined,
                      size: 18),
                  label: Text(label)),
              const SizedBox(height: 8),
              Text(
                  '${item['name']} · ${rental['quantity']} ${rental['quantity'] == 1 ? 'unit' : 'units'}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_venue(item)),
              const SizedBox(height: 8),
              Text(_range(DateTimeRange(start: start, end: end))),
              const SizedBox(height: 12),
              Text(clubPrice(rental['totalPrice']),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (pending) ...[
                _Notice(
                    text: expired
                        ? 'This hold has expired. Refresh or browse gear to reserve again.'
                        : expires == null
                            ? 'Complete payment before your hold expires.'
                            : 'Pay by ${DateFormat('d MMM, HH:mm').format(expires.toUtc().add(const Duration(hours: 5)))} PKT to confirm.'),
                const SizedBox(height: 12),
                if (!expired && rental['payment']?['id'] != null)
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: busy ? null : onPay,
                          child: const Text('Continue payment'))),
              ],
              if (status == 'CONFIRMED')
                _Notice(
                    text: item['venue'] == null
                        ? 'Ask staff where to collect and return your gear.'
                        : 'Collect and return your gear with staff at ${_venue(item)}.'),
              if (status == 'CONFIRMED' && !canCancel)
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                        'Contact staff for changes to a rental that has started.')),
              if (canCancel && !expired)
                TextButton(
                    onPressed: busy ? null : onCancel,
                    child: const Text('Cancel rental')),
              if (status == 'CANCELLED' && refunds.isNotEmpty)
                const _Notice(
                    text:
                        'A refund record is available. Check Payments for its latest status.'),
              if (rental['damageNotes'] != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Inspection: ${rental['damageNotes']}')),
            ])));
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text))
      ]));
}

class _Retry extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _Retry({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message),
            IconButton(
                tooltip: 'Retry',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh))
          ])));
}

class _Empty extends StatelessWidget {
  final String title, message;
  final Widget action;
  const _Empty(
      {required this.title, required this.message, required this.action});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        const Icon(Icons.sports_tennis, size: 40),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        action
      ]));
}
