// ignore_for_file: deprecated_member_use, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:veggieconnect/services/chat_service.dart';
import 'package:veggieconnect/services/supplier_location_service.dart';
import 'package:veggieconnect/services/navigation_manager.dart';
import 'package:veggieconnect/services/notification_service.dart';
import 'package:veggieconnect/widgets/star_rating_widget.dart';
import 'supplier_chat_page.dart';
import '../widgets/lottie_loading_widget.dart';

class SupplierOrdersPage extends StatefulWidget {
  const SupplierOrdersPage({super.key});

  @override
  State<SupplierOrdersPage> createState() => _SupplierOrdersPageState();
}

class _SupplierOrdersPageState extends State<SupplierOrdersPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _dateFilter = 'all';
  final bool _showOnlyPending = false;

  final List<String> _statusOptions = [
    'all',
    'pending',
    'processing',
    'ready_to_pickup',
    'picked_up',
    'cancelled',
  ];

  final List<String> _dateOptions = [
    'all',
    'today',
    'this_week',
    'this_month',
    'last_month',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6CA04A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Orders Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'All Order'),
            Tab(text: 'Pending'),
            Tab(text: 'Processing'),
            Tab(text: 'Ready to Pick Up'),
            Tab(text: 'Picked Up'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search orders by product, buyer, ...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6CA04A)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Filter Row (responsive)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;
                    if (isNarrow) {
                      return Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            items: _statusOptions.map((String status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status.toUpperCase(), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _statusFilter = newValue!;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _dateFilter,
                            decoration: InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                            ),
                            items: _dateOptions.map((String date) {
                              return DropdownMenuItem<String>(
                                value: date,
                                child: Text(date.replaceAll('_', ' ').toUpperCase(), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _dateFilter = newValue!;
                              });
                            },
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        // Status Filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            items: _statusOptions.map((String status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status.toUpperCase(), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _statusFilter = newValue!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Date Filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _dateFilter,
                            decoration: InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _dateOptions.map((String date) {
                              return DropdownMenuItem<String>(
                                value: date,
                                child: Text(date.replaceAll('_', ' ').toUpperCase(), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _dateFilter = newValue!;
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                
                // Urgent Button
                if (_showOnlyPending)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Urgent',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Orders List
          Expanded(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6, // Limit TabView height
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList('all'),
                  _buildOrdersList('pending'),
                  _buildOrdersList('processing'),
                  _buildOrdersList('ready_to_pickup'),
                  _buildOrdersList('picked_up'),
                  _buildOrdersList('cancelled'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(status),
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

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No orders found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Orders will appear here when customers place them',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs;
        final filteredOrders = _filterOrders(orders, status);

        // Order Summary Cards
        return Column(
          children: [
            // Summary Cards
            Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSummaryCard(
                      'Total',
                      orders.length.toString(),
                      Icons.shopping_cart,
                      const Color(0xFF6CA04A),
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      'Pending',
                      orders.where((doc) => 
                        (doc.data() as Map<String, dynamic>)['status'] == 'pending' ||
                        (doc.data() as Map<String, dynamic>)['status'] == null ||
                        (doc.data() as Map<String, dynamic>)['status'] == 'completed'
                      ).length.toString(),
                      Icons.schedule,
                      Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      'Processing',
                      orders.where((doc) => 
                        (doc.data() as Map<String, dynamic>)['status'] == 'processing'
                      ).length.toString(),
                      Icons.sync,
                      Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      'Ready to Pick Up',
                      orders.where((doc) => 
                        (doc.data() as Map<String, dynamic>)['status'] == 'ready_to_pickup'
                      ).length.toString(),
                      Icons.local_shipping,
                      Colors.purple,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      'Picked Up',
                      orders.where((doc) => 
                        (doc.data() as Map<String, dynamic>)['status'] == 'picked_up'
                      ).length.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      'Cancelled',
                      orders.where((doc) => 
                        (doc.data() as Map<String, dynamic>)['status'] == 'cancelled'
                      ).length.toString(),
                      Icons.cancel,
                      Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            
            // Orders List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final doc = filteredOrders[index];
                  final order = doc.data() as Map<String, dynamic>;
                  return _buildOrderCard(order, doc.id);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String count, IconData icon, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getOrdersStream(String status) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    if (status != 'all' && status != 'pending') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _filterOrders(List<QueryDocumentSnapshot> orders, String status) {
    return orders.where((doc) {
      final order = doc.data() as Map<String, dynamic>;
      
      // Status filter for pending (handle 'pending', null, and 'completed' values)
      if (status == 'pending') {
        final orderStatus = order['status'];
        if (orderStatus != 'pending' && orderStatus != null && orderStatus != 'completed') {
          return false;
        }
      } else if (status != 'all') {
        // For other specific statuses, match exactly
        final orderStatus = order['status'];
        if (orderStatus != status) {
          return false;
        }
      }
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final productName = (order['productName'] ?? '').toString().toLowerCase();
        final buyerName = (order['buyerName'] ?? '').toString().toLowerCase();
        final searchQuery = _searchQuery.toLowerCase();
        
        if (!productName.contains(searchQuery) && !buyerName.contains(searchQuery)) {
          return false;
        }
      }
      
      // Date filter
      if (_dateFilter != 'all') {
        final createdAt = order['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        
        final orderDate = createdAt.toDate();
        switch (_dateFilter) {
          case 'today':
            if (!_isToday(orderDate)) return false;
            break;
          case 'this_week':
            if (!_isThisWeek(orderDate)) return false;
            break;
          case 'this_month':
            if (!_isThisMonth(orderDate)) return false;
            break;
          case 'last_month':
            if (!_isLastMonth(orderDate)) return false;
            break;
        }
      }
      
      return true;
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
           date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  bool _isLastMonth(DateTime date) {
    final now = DateTime.now();
    final lastMonth = now.month == 1 ? 12 : now.month - 1;
    final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
    return date.year == lastMonthYear && date.month == lastMonth;
  }

  void _handleOrderAction(String orderId, String action, Map<String, dynamic> order) {
    switch (action) {
      case 'view':
        _showOrderDetails(order, orderId);
        break;
      case 'process':
        _updateOrderStatus(orderId, 'processing');
        break;
      case 'ready':
        _updateOrderStatus(orderId, 'ready_to_pickup');
        break;
      case 'pickup':
        _updateOrderStatus(orderId, 'picked_up');
        break;
      case 'cancel':
        _showCancelOrderDialog(orderId);
        break;
      case 'message':
        _openChatWithBuyer(order['buyerId'], order['buyerName']);
        break;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Get order data before updating
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }
      
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final buyerId = orderData['buyerId'] as String?;
      final buyerName = orderData['buyerName'] as String?;
      final supplierId = orderData['sellerId'] as String?;
      final supplierName = orderData['sellerName'] as String? ?? 'Store';
      final productId = orderData['productId'] as String?;
      final quantity = orderData['quantity'] as int? ?? 1;
      
      // If marking ready_to_pickup, attach pickup coordinates from supplier location
      Map<String, dynamic> statusUpdate = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'ready_to_pickup' && supplierId != null) {
        try {
          final supplierLoc = await SupplierLocationService().getSupplierLocationBySupplierId(supplierId);
          if (supplierLoc != null) {
            statusUpdate.addAll({
              'pickupLat': supplierLoc.latitude,
              'pickupLng': supplierLoc.longitude,
              'pickupAddress': supplierLoc.address,
            });
          }
        } catch (e) {
          // proceed without blocking if location not found
          print('Failed to fetch supplier pickup location: $e');
        }
      }

      // Update order status (and pickup fields if present)
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(statusUpdate);

      // Increment soldCount when order is marked as picked_up
      if (newStatus == 'picked_up' && productId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .update({
            'soldCount': FieldValue.increment(quantity),
            'lastSoldAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Failed to update product soldCount: $e');
          // Continue with the rest of the process even if soldCount update fails
        }
      }

      // Handle route locking/unlocking based on status
      if (newStatus == 'ready_to_pickup') {
        // Lock route for this order
        await NavigationManager().lockRouteForOrder(orderId, supplierId ?? '');
      } else if (newStatus == 'picked_up') {
        // Unlock route when order is completed
        await NavigationManager().unlockRoute();
      }

      // Send notification to customer
      if (buyerId != null) {
        final notificationService = NotificationService();
        String title = '';
        String body = '';
        
        switch (newStatus) {
          case 'processing':
            title = 'Order Processing Started';
            body = 'Your order #${orderId.substring(0, 8)} is now being processed by the supplier.';
            break;
          case 'ready_to_pickup':
            title = 'Order Ready for Pickup';
            body = 'Your order #${orderId.substring(0, 8)} at $supplierName is ready! Tap to navigate.';
            break;
          case 'picked_up':
            title = 'Order Picked Up';
            body = 'Your order #${orderId.substring(0, 8)} has been picked up successfully!';
            break;
          case 'cancelled':
            title = 'Order Cancelled';
            body = 'Your order #${orderId.substring(0, 8)} has been cancelled.';
            break;
        }
        
        // For ready_to_pickup, send deep-linking data to Navigation
        if (newStatus == 'ready_to_pickup') {
          await notificationService.sendFCMNotification(
            recipientId: buyerId,
            title: title,
            body: body,
            type: 'pickup_ready',
            data: {
              'orderId': orderId,
              'status': newStatus,
              'screen': 'navigation',
              'supplierName': supplierName,
              'supplierUserId': supplierId,
              'customerUserId': buyerId, // Customer is the recipient
            },
          );
        } else {
        await notificationService.sendFCMNotification(
          recipientId: buyerId,
          title: title,
          body: body,
          type: 'order_update',
          data: {
            'orderId': orderId,
            'status': newStatus,
            'screen': 'order_details',
          },
        );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}'),
            backgroundColor: const Color(0xFF6CA04A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _getBuyerName(String? buyerId) async {
    if (buyerId == null) return 'Unknown Buyer';
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(buyerId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['name'] ?? 'Unknown Buyer';
      }
    } catch (e) {
      print('Error fetching buyer name: $e');
    }
    
    return 'Unknown Buyer';
  }

  void _showOrderDetails(Map<String, dynamic> order, String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details - #${orderId.substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOrderDetailRow('Product', order['productName'] ?? 'N/A'),
              _buildOrderDetailRow('Quantity', '${order['quantity'] ?? 1}'),
              _buildOrderDetailRow('Price', '₱${order['price'] ?? 0}'),
              _buildOrderDetailRow('Total', '₱${((order['price'] ?? 0) * (order['quantity'] ?? 1)).toStringAsFixed(2)}'),
              _buildOrderDetailRow('Buyer', order['buyerName'] ?? 'N/A'),
              _buildOrderDetailRow('Payment Method', _getPaymentMethodDisplayName(order['paymentMethod'] ?? 'N/A')),
              _buildOrderDetailRow('Status', ((order['status'] == null || order['status'] == 'placed' || order['status'] == 'completed') ? 'pending' : order['status']).toUpperCase()),
              if (order['note'] != null)
                _buildOrderDetailRow('Note', order['note']),
              if (order['createdAt'] != null)
                _buildOrderDetailRow('Created', DateFormat('MMM dd, yyyy - HH:mm').format((order['createdAt'] as Timestamp).toDate())),
              
              // Rating and Feedback Section
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Customer Rating & Feedback',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6CA04A),
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('product_ratings')
                    .where('productId', isEqualTo: order['productId'])
                    .snapshots(),
                builder: (context, ratingSnapshot) {
                  if (ratingSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: GroceryLoadingWidget(
                        size: 100,
                        showText: true,
                        loadingText: 'Loading ratings...',
                      ),
                    );
                  }
                  
                  if (!ratingSnapshot.hasData || ratingSnapshot.data!.docs.isEmpty) {
                    return const Text('No rating available');
                  }
                  
                  // Find rating from the specific buyer for this order
                  final ratings = ratingSnapshot.data!.docs;
                  final buyerId = order['buyerId'];
                  final buyerRating = ratings.where((doc) => 
                    doc['buyerId'] == buyerId
                  ).toList();
                  
                  if (buyerRating.isEmpty) {
                    return const Text('No rating available');
                  }
                  
                  final ratingDoc = buyerRating.first;
                  final ratingData = ratingDoc.data() as Map<String, dynamic>;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Star Rating Display
                      Row(
                        children: [
                          Text(
                            'Rating: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          StarRatingDisplay(
                            rating: (ratingData['rating'] ?? 0).toDouble(),
                            size: 20.0,
                            activeColor: Color(0xFFFFD700),
                            inactiveColor: Colors.grey[300]!,
                            showRatingText: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Feedback
                      if (ratingData['feedback'] != null && ratingData['feedback'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showFeedbackModal(context, ratingData),
                          icon: Icon(Icons.message, size: 16),
                          label: Text('View Customer Feedback'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6CA04A),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Text(
                                'No written feedback provided',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String orderId) {
    // Show completed orders as pending for suppliers so they can process them
    final status = (order['status'] == null || order['status'] == 'placed' || order['status'] == 'completed') ? 'pending' : order['status'];
    final productName = order['productName'] ?? 'Unknown Product';
    final quantity = order['quantity'] ?? 1;
    final price = (order['price'] ?? 0) as num;
    final totalAmount = (order['totalAmount'] ?? (price * quantity)).toDouble();
    final buyerName = order['buyerName'] ?? (order['buyerId'] != null ? 'Loading…' : 'Unknown Buyer');
    final createdAt = order['createdAt'] as Timestamp?;
    final imageUrl = order['imageUrl'];

    return GestureDetector(
      onTap: () => _showOrderDetails(order, orderId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Card(
          elevation: 2,
          child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status and actions
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Order #${orderId.substring(0, 8)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (order['hasRating'] == true) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6CA04A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Color(0xFF6CA04A), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Color(0xFF6CA04A),
                                      size: 12,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Rated',
                                      style: TextStyle(
                                        color: Color(0xFF6CA04A),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (createdAt != null)
                          Text(
                            DateFormat('MMM dd, yyyy - HH:mm').format(createdAt.toDate()),
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  _buildStatusChip(status),
                  SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) => _handleOrderAction(orderId, value, order),
                    itemBuilder: (context) => _buildOrderActions(status),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Product details
              Row(
                children: [
                  // Product image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: imageUrl != null && imageUrl.toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image, color: Colors.grey);
                              },
                            ),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: $quantity x ₱${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Buyer: $buyerName',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Total amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF6CA04A),
                        ),
                      ),
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Payment method
              if (order['paymentMethod'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Payment: ${_getPaymentMethodDisplayName(order['paymentMethod'])}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),);
  }

  Widget _buildStatusChip(String status) {
    // Normalize for display - show completed orders as pending for suppliers
    if (status == 'placed' || status.isEmpty || status == 'completed') {
      status = 'pending';
    }
    Color color;
    String text;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'PENDING';
        break;
      case 'processing':
        color = Colors.blue;
        text = 'PROCESSING';
        break;
      case 'ready_to_pickup':
        color = Colors.purple;
        text = 'READY TO PICK UP';
        break;
      case 'picked_up':
        color = Colors.green;
        text = 'PICKED UP';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'CANCELLED';
        break;
      default:
        color = Colors.orange;
        text = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildOrderActions(String status) {
    final actions = <PopupMenuEntry<String>>[];
    
    actions.add(const PopupMenuItem(
      value: 'view',
      child: Row(
        children: [
          Icon(Icons.visibility, size: 16),
          SizedBox(width: 8),
          Text('View Details'),
        ],
      ),
    ));

    // Allow processing for both 'pending' and 'completed' status (for online payments)
    if (status == 'pending' || status == 'completed') {
      actions.addAll([
        const PopupMenuItem(
          value: 'process',
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: 16),
              SizedBox(width: 8),
              Text('Start Processing'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'cancel',
          child: Row(
            children: [
              Icon(Icons.cancel, size: 16),
              SizedBox(width: 8),
              Text('Cancel Order'),
            ],
          ),
        ),
      ]);
    } else if (status == 'processing') {
      actions.addAll([
        const PopupMenuItem(
          value: 'ready',
          child: Row(
            children: [
              Icon(Icons.local_shipping, size: 16),
              SizedBox(width: 8),
              Text('Mark as Ready to Pick Up'),
            ],
          ),
        ),
      ]);
    } else if (status == 'ready_to_pickup') {
      actions.addAll([
        const PopupMenuItem(
          value: 'pickup',
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 16),
              SizedBox(width: 8),
              Text('Mark as Picked Up'),
            ],
          ),
        ),
      ]);
    }

    actions.add(const PopupMenuItem(
      value: 'message',
      child: Row(
        children: [
          Icon(Icons.message, size: 16),
          SizedBox(width: 8),
          Text('Message Buyer'),
        ],
      ),
    ));

    return actions;
  }

  String _getPaymentMethodDisplayName(String method) {
    switch (method) {
      case 'cash_on_pickup':
        return 'Cash on Pickup';
      case 'gcash':
        return 'GCash';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return method.toUpperCase();
    }
  }

  Widget _buildOrderDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showFeedbackModal(BuildContext context, Map<String, dynamic> ratingData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Color(0xFFFFD700), size: 20),
            SizedBox(width: 8),
            Text('Customer Feedback'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating
            Row(
              children: [
                Text(
                  'Rating: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StarRatingDisplay(
                  rating: (ratingData['rating'] ?? 0).toDouble(),
                  size: 20.0,
                  activeColor: Color(0xFFFFD700),
                  inactiveColor: Colors.grey[300]!,
                  showRatingText: true,
                ),
              ],
            ),
            SizedBox(height: 16),
            // Feedback
            Text(
              'Feedback:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                ratingData['feedback'] ?? 'No feedback provided',
                style: TextStyle(fontSize: 14),
              ),
            ),
            if (ratingData['timestamp'] != null) ...[
              SizedBox(height: 12),
              Text(
                'Submitted: ${DateFormat('MMM dd, yyyy - HH:mm').format((ratingData['timestamp'] as Timestamp).toDate())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(orderId, 'cancelled');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _openChatWithBuyer(String? buyerId, String? buyerName) async {
    if (buyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buyer information not available')),
      );
      return;
    }
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to chat')),
        );
        return;
      }

      // Get real names from Firestore
      String actualBuyerName = buyerName ?? 'Unknown Buyer';
      String actualSupplierName = 'Supplier';

      // Fetch buyer's real name from Firestore
      try {
        final buyerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(buyerId)
            .get();
        if (buyerDoc.exists) {
          final buyerData = buyerDoc.data() as Map<String, dynamic>;
          actualBuyerName = buyerData['name'] ?? actualBuyerName;
        }
      } catch (e) {
        print('Error fetching buyer name: $e');
      }

      // Fetch supplier's real name from Firestore
      try {
        final supplierDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (supplierDoc.exists) {
          final supplierData = supplierDoc.data() as Map<String, dynamic>;
          actualSupplierName = supplierData['name'] ?? actualSupplierName;
        }
      } catch (e) {
        print('Error fetching supplier name: $e');
      }

      // Create or get chat room
      final chatService = ChatService();
      final conversationId = await chatService.getOrCreateConversation(
        buyerId: buyerId,
        supplierId: currentUser.uid,
        buyerName: actualBuyerName,
        supplierName: actualSupplierName,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupplierChatPage(
              conversationId: conversationId,
              buyerId: buyerId,
              buyerName: actualBuyerName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening chat: $e')),
        );
      }
    }
  }
}