import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/icon_helper.dart';

class AdminSportsScreen extends StatefulWidget {
  const AdminSportsScreen({super.key});

  @override
  State<AdminSportsScreen> createState() => _AdminSportsScreenState();
}

class _AdminSportsScreenState extends State<AdminSportsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _sports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSports();
  }

  Future<void> _fetchSports() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.dio.get('/sports');
      if (mounted) {
        setState(() {
          _sports = res.data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSport(int id) async {
    try {
      await _apiService.dio.delete('/sports/$id');
      _fetchSports();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sport deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete sport')));
    }
  }

  void _showAddSportDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Sport'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (e.g., Football)')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Icon Name (e.g., sports_tennis)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.dio.post('/sports', data: {
                  'name': nameCtrl.text,
                  'description': descCtrl.text,
                  'icon': iconCtrl.text.isEmpty ? 'sports' : iconCtrl.text,
                  'isActive': true,
                });
                Navigator.pop(context);
                _fetchSports();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error adding sport')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sports')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _sports.length,
              itemBuilder: (context, index) {
                final sport = _sports[index];
                return ListTile(
                  leading: Icon(IconHelper.getIcon(sport['icon'])),
                  title: Text(sport['name']),
                  subtitle: Text('${sport['_count']?['venues'] ?? 0} Venues'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSport(sport['id']),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSportDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
