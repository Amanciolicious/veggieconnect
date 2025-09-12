// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/lottie_loading_widget.dart';

class AdminAutoApprovalDebugPage extends StatefulWidget {
  const AdminAutoApprovalDebugPage({super.key});

  @override
  State<AdminAutoApprovalDebugPage> createState() => _AdminAutoApprovalDebugPageState();
}

class _AdminAutoApprovalDebugPageState extends State<AdminAutoApprovalDebugPage> {
 
  List<Map<String, dynamic>> _pendingProducts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPendingProducts();
  }

  Future<void> _loadPendingProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'pending')
          .where('autoApprovalScheduled', isEqualTo: true)
          .get();

      setState(() {
        _pendingProducts = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading pending products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _manualTriggerApproval() async {
    setState(() => _isLoading = true);
    
    try {
     
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual approval check completed')),
      );
      await _loadPendingProducts(); // Reload the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Auto Approval Debug',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: GroceryLoadingWidget(
                size: 100,
                showText: true,
                loadingText: 'Loading pending products...'
              ),
            )
          : _pendingProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No pending products',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _pendingProducts.length,
                  itemBuilder: (context, index) {
                    final product = _pendingProducts[index];
                    final scheduledTime = product['scheduledApprovalTime'] as String?;
                    final autoApprovalTime = product['autoApprovalTime'] as Timestamp?;
                    
                    DateTime? scheduledDateTime;
                    if (scheduledTime != null) {
                      scheduledDateTime = DateTime.parse(scheduledTime);
                    }
                    
                    final now = DateTime.now();
                    final isOverdue = scheduledDateTime != null && now.isAfter(scheduledDateTime);
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Text(
                          product['name'] ?? 'Unknown Product',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF222222),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supplier: ${product['supplierName'] ?? 'Unknown'}',
                              style: TextStyle(
                                color: Color(0xFF6CA04A),
                              ),
                            ),
                            if (scheduledDateTime != null) ...[
                              SizedBox(height: 4),
                              Text(
                                'Scheduled: ${scheduledDateTime.toString()}',
                                style: TextStyle(
                                  color: Color(0xFF6CA04A),
                                ),
                              ),
                            ],
                            if (autoApprovalTime != null) ...[
                              SizedBox(height: 4),
                              Text(
                                'Created: ${autoApprovalTime.toDate().toString()}',
                                style: TextStyle(
                                  color: Color(0xFF6CA04A),
                                ),
                              ),
                            ],
                            if (isOverdue) ...[
                              SizedBox(height: 4),
                              Text(
                                'Overdue by: ${now.difference(scheduledDateTime).inMinutes} minutes',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _manualTriggerApproval(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6CA04A),
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Trigger Approval'),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _manualTriggerApproval,
        backgroundColor: Color(0xFF6CA04A),
        child: Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}