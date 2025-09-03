// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:veggieconnect/services/chat_service.dart';
import 'supplier_chat_page.dart';

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
  bool _showOnlyPending = false;

  final List<String> _statusOptions = [
    'all',
    'pending',
    'processing',
    'shipped',
    'delivered',
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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Orders Management',
          style: TextStyle(
            fontSize: screenWidth * 0.055,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All Orders'),
            Tab(text: 'Pending'),
            Tab(text: 'Processing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilterSection(screenWidth),
          
          // Statistics Cards
          _buildStatisticsSection(screenWidth),
          
          // Orders List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList('all'),
                _buildOrdersList('pending'),
                _buildOrdersList('processing'),
                _buildOrdersList('completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection(double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search orders by product, buyer, or order ID...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.03,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          
          SizedBox(height: screenWidth * 0.03),
          
          // Filter Row - responsive using Wrap to avoid overflow
          LayoutBuilder(
            builder: (context, constraints) {
              final double spacing = screenWidth * 0.02;
              final double colWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: colWidth,
                    child: _buildFilterDropdown(
                      'Status',
                      _statusFilter,
                      _statusOptions,
                      (value) => setState(() => _statusFilter = value),
                    ),
                  ),
                  SizedBox(
                    width: colWidth,
                    child: _buildFilterDropdown(
                      'Date',
                      _dateFilter,
                      _dateOptions,
                      (value) => setState(() => _dateFilter = value),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => _showOnlyPending = !_showOnlyPending),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showOnlyPending ? Colors.green : Colors.grey,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.priority_high,
                          size: 16,
                          color: _showOnlyPending ? Colors.white : Colors.grey,
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Text(
                          'Urgent',
                          style: TextStyle(
                            fontSize: 12,
                            color: _showOnlyPending ? Colors.white : Colors.grey,
                            fontWeight: _showOnlyPending ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String currentValue,
    List<String> options,
    Function(String) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(
            option.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _buildStatisticsSection(double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenWidth * 0.02),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('sellerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final orders = snapshot.data!.docs;
          final totalOrders = orders.length;
          final pendingOrders = orders.where((doc) => 
            (doc.data() as Map<String, dynamic>)['status'] == 'pending').length;
          final processingOrders = orders.where((doc) => 
            (doc.data() as Map<String, dynamic>)['status'] == 'processing').length;
          final completedOrders = orders.where((doc) => 
            (doc.data() as Map<String, dynamic>)['status'] == 'delivered').length;

          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  totalOrders.toString(),
                  Icons.shopping_cart,
                  Colors.green,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  pendingOrders.toString(),
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: _buildStatCard(
                  'Processing',
                  processingOrders.toString(),
                  Icons.pending,
                  Colors.blue,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  completedOrders.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Card(
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: (w * 0.22).clamp(18, 24)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: (w * 0.25).clamp(14, 18),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (w * 0.18).clamp(10, 12),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersList(String statusFilter) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var orders = snapshot.data!.docs;

        // Apply filters
        orders = orders.where((doc) {
          final order = doc.data() as Map<String, dynamic>;
          
          // Status filter
          if (statusFilter != 'all' && statusFilter != 'completed') {
            if (order['status'] != statusFilter) return false;
          } else if (statusFilter == 'completed') {
            if (order['status'] != 'delivered') return false;
          }

          // Search filter
          if (_searchQuery.isNotEmpty) {
            final searchLower = _searchQuery.toLowerCase();
            final productName = (order['productName'] ?? '').toString().toLowerCase();
            final buyerName = (order['buyerName'] ?? '').toString().toLowerCase();
            final orderId = doc.id.toLowerCase();
            
            if (!productName.contains(searchLower) &&
                !buyerName.contains(searchLower) &&
                !orderId.contains(searchLower)) {
              return false;
            }
          }

          // Date filter
          if (_dateFilter != 'all') {
            final createdAt = order['createdAt'] as Timestamp?;
            if (createdAt != null) {
              final orderDate = createdAt.toDate();
              final now = DateTime.now();
              
              switch (_dateFilter) {
                case 'today':
                  if (!_isSameDay(orderDate, now)) return false;
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
          }

          return true;
        }).toList();

        if (orders.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final order = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;
            
            return _buildOrderCard(order, orderId);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String orderId) {
    final status = order['status'] ?? 'pending';
    final productName = order['productName'] ?? 'Unknown Product';
    final quantity = order['quantity'] ?? 1;
    final price = order['price'] ?? 0.0;
    final totalAmount = (price * quantity).toDouble();
    final buyerName = order['buyerName'] ?? 'Unknown Buyer';
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
                        Text(
                          'Order #${orderId.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                  _buildStatusChip(status),
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
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Qty: $quantity × ₱${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Buyer: $buyerName',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
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
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Total',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
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
      ),
  );}

  Widget _buildStatusChip(String status) {
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
      case 'shipped':
        color = Colors.purple;
        text = 'SHIPPED';
        break;
      case 'delivered':
        color = Colors.green;
        text = 'DELIVERED';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'CANCELLED';
        break;
      default:
        color = Colors.grey;
        text = 'UNKNOWN';
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

    if (status == 'pending') {
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
          value: 'ship',
          child: Row(
            children: [
              Icon(Icons.local_shipping, size: 16),
              SizedBox(width: 8),
              Text('Mark as Shipped'),
            ],
          ),
        ),
      ]);
    } else if (status == 'shipped') {
      actions.addAll([
        const PopupMenuItem(
          value: 'deliver',
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 16),
              SizedBox(width: 8),
              Text('Mark as Delivered'),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here when customers place them',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodDisplayName(String method) {
    switch (method) {
      case 'cash_on_pickup':
        return 'Cash on Pickup';
      case 'gcash':
        return 'GCash';
      case 'paymaya':
        return 'PayMaya';
      default:
        return method.toUpperCase();
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
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
      case 'ship':
        _updateOrderStatus(orderId, 'shipped');
        break;
      case 'deliver':
        _updateOrderStatus(orderId, 'delivered');
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
      
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
    }
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
              _buildOrderDetailRow('Status', (order['status'] ?? 'pending').toUpperCase()),
              if (order['note'] != null)
                _buildOrderDetailRow('Note', order['note']),
              if (order['createdAt'] != null)
                _buildOrderDetailRow('Created', DateFormat('MMM dd, yyyy - HH:mm').format((order['createdAt'] as Timestamp).toDate())),
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
          actualBuyerName = buyerData['name'] ?? buyerName ?? 'Unknown Buyer';
        }
      } catch (e) {
        // Use fallback name if Firestore fetch fails
        actualBuyerName = buyerName ?? 'Unknown Buyer';
      }

      // Fetch supplier's real name from Firestore
      try {
        final supplierDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (supplierDoc.exists) {
          final supplierData = supplierDoc.data() as Map<String, dynamic>;
          actualSupplierName = supplierData['name'] ?? 'Supplier';
        }
      } catch (e) {
        // Use fallback name if Firestore fetch fails
        actualSupplierName = 'Supplier';
      }

      // Get or create conversation
      final chatService = ChatService();
      final conversationId = await chatService.getOrCreateConversation(
        buyerId: buyerId,
        supplierId: currentUser.uid,
        buyerName: actualBuyerName,
        supplierName: actualSupplierName,
      );

      // Navigate to chat page
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