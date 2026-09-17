import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _complaints = [];
  bool _isLoading = true;
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    try {
      final res = await _apiService.dio.get('/complaints/my');
      setState(() {
        _complaints = res.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComplaint() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) return;
    
    try {
      final res = await _apiService.dio.post('/complaints', data: {
        'title': _titleController.text,
        'description': _descController.text
      });
      if (res.data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complaint submitted')));
        _titleController.clear();
        _descController.clear();
        _fetchComplaints();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('File a Complaint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitComplaint,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Submit Complaint', style: TextStyle(color: Colors.white)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('My Complaints', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._complaints.map((c) => Card(
                child: ListTile(
                  title: Text(c['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['description']),
                      if (c['adminNote'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Admin: ${c['adminNote']}', style: const TextStyle(color: Colors.green)),
                      ]
                    ],
                  ),
                  trailing: Chip(label: Text(c['status'])),
                ),
              )).toList()
            ],
          )
    );
  }
}
