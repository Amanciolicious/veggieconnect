// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/role_page_header.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:veggieconnect/services/notification_service.dart';
import 'customer_rating_dialog.dart';
import 'package:veggieconnect/services/supplier_report_service.dart';
import 'package:veggieconnect/services/ban_service.dart';
import 'package:veggieconnect/services/rating_service.dart';
import '../widgets/lottie_loading_widget.dart';
import '../services/auth_state_service.dart';

class BuyerOrderHistoryPage extends StatefulWidget {
  const BuyerOrderHistoryPage({super.key});

  @override
  State<BuyerOrderHistoryPage> createState() => _BuyerOrderHistoryPageState();
}

class _BuyerOrderHistoryPageState extends State<BuyerOrderHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Pending', 'Processing', 'Ready to Pick Up', 'Picked Up', 'Cancelled'];
  final AuthStateService _authService = AuthStateService();
  // Local immediate UI state after actions, before Firestore stream reflects updates
  final Set<String> _locallyRatedOrderIds = <String>{};
  final Set<String> _locallyReportedOrderIds = <String>{};

  AuthUser? get user => _authService.currentUser;

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
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in.')),
      );
    }
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: const RolePageHeader(title: 'Order History'),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: Color(0xFF6CA04A),
            labelColor: Color(0xFF6CA04A),
            unselectedLabelColor: Colors.black54,
            isScrollable: true,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
          Expanded(
            child: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('buyerId', isEqualTo: user?.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: GroceryLoadingWidget(
                      size: 120,
                      showText: true,
                      loadingText: 'Loading orders...',
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No orders yet.',
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }
                final orders = snapshot.data!.docs.where((doc) {
                  if (tab == 'All') return true;
                  final status = (doc['status'] ?? '').toString().toLowerCase();
                  final normalized = status == 'delivered' ? 'picked up' : status;
                  if (tab == 'Ready to Pick Up') {
                    return normalized == 'ready_to_pickup';
                  }
                  if (tab == 'Cancelled') {
                    return normalized == 'cancelled';
                  }
                  return normalized == tab.toLowerCase();
                }).toList();
                if (orders.isEmpty) {
                  return Center(
                    child: Text(
                      'No orders in this category.',
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
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
                      case 'ready_to_pickup':
                        statusColor = Colors.purple;
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
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status == 'ready_to_pickup' ? 'READY TO PICK UP' : status.toUpperCase(),
                                  style: GoogleFonts.quicksand(
                                    color: statusColor,
                                    fontSize: screenWidth * 0.03,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text(
                            'Total: ₱${order['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.045,
                              color: Color(0xFF6CA04A),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.01),
                          Text(
                            'Date: ${_formatDate(order['createdAt'])}',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.035,
                              color: Color(0xFF757575),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (order['items'] != null && order['items'].isNotEmpty) ...[
                            SizedBox(height: screenWidth * 0.02),
                            Text(
                              'Items:',
                              style: GoogleFonts.quicksand(
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            ...((order['items'] as List).take(3).map((item) => Padding(
                              padding: EdgeInsets.only(left: screenWidth * 0.02, top: 2),
                              child: Text(
                                '• ${item['name']} (${item['quantity']} ${item['unit']})',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.032,
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ))),
                            if ((order['items'] as List).length > 3)
                              Padding(
                                padding: EdgeInsets.only(left: screenWidth * 0.02, top: 2),
                                child: Text(
                                  '... and ${(order['items'] as List).length - 3} more items',
                                  style: GoogleFonts.quicksand(
                                    fontSize: screenWidth * 0.032,
                                    color: Color(0xFF757575),
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                          ],
                          if (status == 'picked_up') ...[
                            SizedBox(height: screenWidth * 0.03),
                            Row(
                              children: [
                                // Rate Button/Status
                                Expanded(
                                  child: FutureBuilder<bool>(
                                    future: RatingService.hasUserRatedOrder(order['orderId'] ?? orders[index].id),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Container(
                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                strokeWidth: 2,        // thinner spinner
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white), 
              ),
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      final sharedOrderId = (order['orderId'] ?? orders[index].id).toString();
                                      final hasRatedFlag = order['hasRating'] == true; // persisted on order doc
                                      final hasRatedRemote = snapshot.data ?? false; // lookup in order_ratings
                                      final hasRatedLocal = _locallyRatedOrderIds.contains(sharedOrderId);
                                      final hasRated = hasRatedFlag || hasRatedRemote || hasRatedLocal;
                                      return hasRated
                                          ? Container(
                                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.green.shade300),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: Colors.green.shade700,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Rated',
                                                    style: GoogleFonts.quicksand(
                                                      color: Colors.green.shade700,
                                                      fontSize: screenWidth * 0.035,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color(0xFF6CA04A),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                              ),
                                              onPressed: () => _showRatingDialog(context, orders[index].id, order),
                                              child: Text(
                                                'Rate Order',
                                                style: GoogleFonts.quicksand(
                                                  color: Colors.white,
                                                  fontSize: screenWidth * 0.035,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            );
                                    },
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                // Report Button/Status
                                Expanded(
                                  child: ((order['hasReport'] == true) || _locallyReportedOrderIds.contains((order['orderId'] ?? orders[index].id).toString()))
                                      ? Container(
                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.shade300),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.flag,
                                                color: Colors.red.shade700,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Reported',
                                                style: GoogleFonts.quicksand(
                                                  color: Colors.red.shade700,
                                                  fontSize: screenWidth * 0.035,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                          ),
                                          onPressed: () => _showReportDialog(context, orders[index].id, order),
                                          child: Text(
                                            'Report Supplier',
                                            style: GoogleFonts.quicksand(
                                              color: Colors.white,
                                              fontSize: screenWidth * 0.035,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                          // Cancel Order Button for pending/processing orders
                          if (status == 'pending' || status == 'processing') ...[
                            SizedBox(height: screenWidth * 0.03),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                onPressed: () => _showCancelOrderDialog(context, orders[index].id, order),
                                child: Text(
                                  'Cancel Order',
                                  style: GoogleFonts.quicksand(
                                    color: Colors.white,
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          // Buy Again Button for cancelled orders
                          if (status == 'cancelled') ...[
                            SizedBox(height: screenWidth * 0.03),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF6CA04A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                onPressed: () => _buyAgain(context, order),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Buy Again',
                                      style: GoogleFonts.quicksand(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.04,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
          ),
        ],
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

  Future<void> _showRatingDialog(BuildContext context, String documentId, Map<String, dynamic> order) async {
    // Use the actual orderId field from the order document, not the document ID
    final actualOrderId = order['orderId'] ?? documentId;
    
    final products = order['items'] ?? [
      {
        'productId': order['productId'] ?? '',
        'name': order['productName'] ?? '',
        'price': order['price'] ?? 0,
        'quantity': order['quantity'] ?? 1,
      }
    ];
    final rated = await showDialog<bool>(
      context: context,
      builder: (context) => RatingDialog(
        orderId: actualOrderId,
        supplierId: order['sellerId'] ?? '',
        supplierName: order['supplierName'] ?? 'Unknown Supplier',
        products: List<Map<String, dynamic>>.from(products),
      ),
    );
    if (rated == true && mounted) {
      setState(() {
        // Mark locally as rated for instant UI feedback
        _locallyRatedOrderIds.add(actualOrderId.toString());
      });
    }
  }

  void _showReportDialog(BuildContext context, String orderId, Map<String, dynamic> order) async {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Report Supplier', 
            style: GoogleFonts.quicksand(
              fontSize: 18, 
              fontWeight: FontWeight.w400
            )
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please provide a reason for reporting this supplier:', 
                style: GoogleFonts.quicksand(
                  fontSize: 14, 
                  color: Color(0xFF757575), 
                  fontWeight: FontWeight.w400
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
                style: GoogleFonts.quicksand(
                  fontSize: 12, 
                  fontWeight: FontWeight.w400, 
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
                    reporterId: user!.uid,
                    productId: order['productId'] ?? '',
                    reason: reasonController.text.trim(),
                    productName: order['productName'] ?? '',
                    supplierName: order['supplierName'] ?? 'Unknown Supplier',
                    orderId: orderId,
                  );
                  
                  // Update ALL item docs for this order to mark as reported
                  final sharedOrderId = (order['orderId'] ?? orderId).toString();
                  final query = await FirebaseFirestore.instance
                      .collection('orders')
                      .where('orderId', isEqualTo: sharedOrderId)
                      .where('buyerId', isEqualTo: user?.uid)
                      .get();
                  if (query.docs.isNotEmpty) {
                    final batch = FirebaseFirestore.instance.batch();
                    for (final d in query.docs) {
                      batch.update(d.reference, {
                        'hasReport': true,
                        'reportTimestamp': FieldValue.serverTimestamp(),
                      });
                    }
                    await batch.commit();
                  } else {
                    // Fallback: update the clicked doc to avoid failures if query misses
                    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                      'hasReport': true,
                      'reportTimestamp': FieldValue.serverTimestamp(),
                    });
                  }
                  
                  // Check if supplier should be banned (3+ reports)
                  await _checkAndApplyAutoBan(order['sellerId'] ?? '');
                  
                  if (!mounted) return;
                  final sharedOrderId2 = (order['orderId'] ?? orderId).toString();
                  setState(() {
                    // Mark locally as reported for instant UI disable
                    _locallyReportedOrderIds.add(sharedOrderId2);
                  });
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
                style: GoogleFonts.quicksand(
                  fontSize: 12, 
                  color: Colors.white, 
                  fontWeight: FontWeight.w400
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

  void _showCancelOrderDialog(BuildContext context, String orderId, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cancel Order',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel this order?',
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${orderId.substring(0, 8)}',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Product: ${order['productName'] ?? 'N/A'}',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'Total: ₱${order['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Keep Order',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _cancelOrder(orderId, order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel Order',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelOrder(String orderId, Map<String, dynamic> order) async {
    try {
      // Update order status to cancelled
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': user?.uid,
      });

      // Send notification to supplier
      await _sendCancellationNotification(order, orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Color(0xFF6CA04A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendCancellationNotification(Map<String, dynamic> order, String orderId) async {
    try {
      final notificationService = NotificationService();
      final supplierId = order['sellerId'] as String?;
      final customerName = order['buyerName'] as String? ?? 'Customer';
      
      if (supplierId != null) {
        await notificationService.sendFCMNotification(
          recipientId: supplierId,
          title: 'Order Cancelled',
          body: 'Order #${orderId.substring(0, 8)} has been cancelled by $customerName',
          type: 'order_cancelled',
          data: {
            'orderId': orderId,
            'status': 'cancelled',
            'screen': 'order_details',
            'customerName': customerName,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending cancellation notification: $e');
    }
  }

  void _buyAgain(BuildContext context, Map<String, dynamic> order) async {
    try {
      // Check if product still exists and is available
      final productId = order['productId'] as String?;
      if (productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product information not available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This product is no longer available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final currentStock = productData['stock'] as int? ?? 0;
      final requestedQuantity = order['quantity'] as int? ?? 1;

      if (currentStock < requestedQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock. Available: $currentStock, Requested: $requestedQuantity'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Add to cart
      await FirebaseFirestore.instance.collection('cart').add({
        'userId': user?.uid,
        'productId': productId,
        'quantity': requestedQuantity,
        'addedAt': FieldValue.serverTimestamp(),
        'productName': order['productName'],
        'price': order['price'],
        'sellerId': order['sellerId'],
        'sellerName': order['sellerName'],
        'imageUrl': order['imageUrl'],
        'unit': productData['unit'] ?? 'kg',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${order['productName']} added to cart successfully!'),
            backgroundColor: Color(0xFF6CA04A),
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to cart page
                Navigator.pushNamed(context, '/cart');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}