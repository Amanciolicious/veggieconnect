// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'rating_dialog.dart';
import 'package:veggieconnect/services/supplier_report_service.dart';
import 'package:veggieconnect/services/ban_service.dart';

class BuyerOrderHistoryPage extends StatefulWidget {
  const BuyerOrderHistoryPage({super.key});

  @override
  State<BuyerOrderHistoryPage> createState() => _BuyerOrderHistoryPageState();
}

class _BuyerOrderHistoryPageState extends State<BuyerOrderHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Pending', 'Processing', 'Picked Up'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in.')),
      );
    }
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Order History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('buyerId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No orders yet.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF757575),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                }
                final orders = snapshot.data!.docs.where((doc) {
                  if (tab == 'All') return true;
                  final status = (doc['status'] ?? '').toString().toLowerCase();
                  final normalized = status == 'delivered' ? 'picked up' : status;
                  return normalized == tab.toLowerCase();
                }).toList();
                if (orders.isEmpty) {
                  return Center(
                    child: Text(
                      'No orders in this category.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF757575),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (context, index) => SizedBox(height: screenWidth * 0.02),
                  itemBuilder: (context, index) {
                    final order = orders[index].data() as Map<String, dynamic>;
                    final status = order['status'] ?? 'pending';
                    Color statusColor;
                    switch (status) {
                      case 'picked_up':
                        statusColor = Color(0xFF6CA04A);
                        break;
                      case 'processing':
                        statusColor = Colors.orange;
                        break;
                      case 'cancelled':
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF8D9773).withOpacity(0.08),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${orders[index].id.substring(0, 8)}',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: screenWidth * 0.03,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text(
                            'Total: ₱${order['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6CA04A),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.01),
                          Text(
                            'Date: ${_formatDate(order['createdAt'])}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Color(0xFF757575),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (order['items'] != null && order['items'].isNotEmpty) ...[
                            SizedBox(height: screenWidth * 0.02),
                            Text(
                              'Items:',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            ...((order['items'] as List).take(3).map((item) => Padding(
                              padding: EdgeInsets.only(left: screenWidth * 0.02, top: 2),
                              child: Text(
                                '• ${item['name']} (${item['quantity']} ${item['unit']})',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: Color(0xFF757575),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ))),
                            if ((order['items'] as List).length > 3)
                              Padding(
                                padding: EdgeInsets.only(left: screenWidth * 0.02, top: 2),
                                child: Text(
                                  '... and ${(order['items'] as List).length - 3} more items',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.032,
                                    color: Color(0xFF757575),
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                          ],
                          if (status == 'picked_up') ...[
                            SizedBox(height: screenWidth * 0.03),
                            Row(
                              children: [
                                // Rate Button
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: order['hasRating'] == true 
                                          ? Colors.grey 
                                          : Color(0xFF6CA04A),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    ),
                                    onPressed: order['hasRating'] == true 
                                        ? null 
                                        : () => _showRatingDialog(context, orders[index].id, order),
                                    child: Text(
                                      order['hasRating'] == true ? 'Already Rated' : 'Rate Order',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.035,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                // Report Button
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: order['hasReport'] == true 
                                          ? Colors.grey 
                                          : Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    ),
                                    onPressed: order['hasReport'] == true 
                                        ? null 
                                        : () => _showReportDialog(context, orders[index].id, order),
                                    child: Text(
                                      order['hasReport'] == true ? 'Already Reported' : 'Report Supplier',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.035,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showRatingDialog(BuildContext context, String orderId, Map<String, dynamic> order) {
    final products = order['items'] ?? [
      {
        'productId': order['productId'] ?? '',
        'name': order['productName'] ?? '',
        'price': order['price'] ?? 0,
        'quantity': order['quantity'] ?? 1,
      }
    ];
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        orderId: orderId,
        supplierId: order['sellerId'] ?? '',
        supplierName: order['supplierName'] ?? 'Unknown Supplier',
        products: List<Map<String, dynamic>>.from(products),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String orderId, Map<String, dynamic> order) async {
    final TextEditingController reasonController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Report Supplier', 
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              fontFamily: 'Poppins'
            )
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please provide a reason for reporting this supplier:', 
                style: TextStyle(
                  fontSize: 14, 
                  color: Color(0xFF757575), 
                  fontFamily: 'Poppins'
                )
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for report...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel', 
                style: TextStyle(
                  fontSize: 12, 
                  fontFamily: 'Poppins', 
                  color: Colors.grey
                )
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason for the report')),
                  );
                  return;
                }
                
                try {
                  // Submit the report
                  await SupplierReportService.submitReport(
                    supplierId: order['sellerId'] ?? '',
                    reporterId: user.uid,
                    productId: order['productId'] ?? '',
                    reason: reasonController.text.trim(),
                    productName: order['productName'] ?? '',
                    supplierName: order['supplierName'] ?? 'Unknown Supplier',
                    orderId: orderId,
                  );
                  
                  // Update order to mark as reported
                  await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                    'hasReport': true,
                    'reportTimestamp': FieldValue.serverTimestamp(),
                  });
                  
                  // Check if supplier should be banned (3+ reports)
                  await _checkAndApplyAutoBan(order['sellerId'] ?? '');
                  
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted successfully')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to submit report: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                'Submit Report', 
                style: TextStyle(
                  fontSize: 12, 
                  color: Colors.white, 
                  fontFamily: 'Poppins'
                )
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkAndApplyAutoBan(String supplierId) async {
    try {
      final reportCount = await SupplierReportService.getSupplierReportCount(supplierId);
      
      if (reportCount >= 3) {
        // Check if supplier is already banned
        final existingBan = await BanService.checkUserBanStatus(supplierId);
        if (existingBan == null) {
          // Apply temporary ban for 7 days
          await BanService.applyTemporaryBan(
            userId: supplierId,
            bannedBy: 'system',
            reason: 'Automatic ban due to 3 or more reports',
            durationDays: 7,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking auto-ban: $e');
    }
  }
}