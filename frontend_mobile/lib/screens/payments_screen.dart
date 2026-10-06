import '../services/live_refresh.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, this.admin = false});
  final bool admin;
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}
class _PaymentsScreenState extends State<PaymentsScreen> with LiveRefresh<PaymentsScreen> {
  @override
  List<String> get liveResources => ['payments', 'bookings'];
  @override
  Future<void> refreshForLiveUpdates() => load();
  List<dynamic> payments = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try { final r = await ApiService().dio.get(widget.admin ? '/payments' : '/payments/my'); if (mounted) setState(() { payments = r.data['data']; error = null; }); }
    catch (_) { if (mounted) setState(() => error = 'Could not load payments. Pull to retry.'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> invoice(int id) async {
    try {
      final r = await ApiService().dio.get('/payments/$id/invoice');
      if (!mounted) return;
      final i = r.data['data'];
      await showDialog(context: context, builder: (c) => AlertDialog(title: Text('Invoice ${i['invoiceNumber']}'), content: SingleChildScrollView(child: Text('${i['customer']['name']}\n${i['purpose']}\n${i['currency']} ${i['amount']}\nStatus: ${i['status']}\n\n${i['note']}')), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))]));
    } catch (_) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load invoice'))); }
  }
  Future<void> cash(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Record money received'), content: const Text('Confirm only after collecting the full amount in person.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Money received'))]));
    if (confirm != true) return;
    try { await ApiService().dio.post('/payments/confirm', data: {'paymentId': id, 'receivedInPerson': true}); await load(); }
    catch (_) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not record payment'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Payments and invoices')), body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(16), children: [
    if (error != null) Text(error!),
    if (payments.isEmpty && error == null) const Text('No payments found.'),
    ...payments.map((p) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('#${p['id']} · ${p['currency']} ${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)), Text('${p['purpose']} · ${p['status']}'), Wrap(children: [TextButton(onPressed: () => invoice(p['id']), child: const Text('Invoice')), if (p['status'] == 'PENDING') TextButton(onPressed: () async { if (widget.admin) { await cash(p['id']); } else { try { await PaymentService.checkout(p['id']); } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Online payment unavailable. Contact arena staff.'))); } } }, child: Text(widget.admin ? 'Record cash' : 'Pay online'))])])))),
  ])));
}
