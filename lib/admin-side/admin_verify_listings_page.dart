// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/content_filter_service.dart';
import '../services/auth_state_service.dart';
import '../services/notification_service.dart';
import '../widgets/lottie_loading_widget.dart';
import '../widgets/role_page_header.dart';
import 'admin_dashboard.dart';

class AdminVerifyListingsPage extends StatefulWidget {
  const AdminVerifyListingsPage({super.key});

  @override
  State<AdminVerifyListingsPage> createState() => _AdminVerifyListingsPageState();
}

class _AdminVerifyListingsPageState extends State<AdminVerifyListingsPage> {
  final ContentFilterService _contentFilterService = ContentFilterService();
  final AuthStateService _authService = AuthStateService();
  final NotificationService _notificationService = NotificationService();
  String _filterStatus = 'all'; // 'all', 'pending', 'flagged', 'approved', 'rejected'
  late final Ticker _ticker;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier<DateTime>(DateTime.now());
  Stream<QuerySnapshot>? _productsStream;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: RolePageHeader(
        title: 'Verify Listings',
        onBackTap: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminDashboard()),
            );
          }
        },
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              _filterStatus = value;
              _productsStream = _buildProductsStream();
            });
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'all', child: Text('All Products')),
            PopupMenuItem(value: 'pending', child: Text('Pending Review')),
            PopupMenuItem(value: 'flagged', child: Text('Content Flagged')),
            PopupMenuItem(value: 'approved', child: Text('Approved')),
            PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            PopupMenuItem(value: 'recently_processed', child: Text('Recently Processed')),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.filter_list, color: Color(0xFF4CAF50)),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          children: [
            // Filter Status Indicator
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: _getFilterColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(screenWidth * 0.02),
              ),
              child: Row(
                children: [
                  Icon(_getFilterIcon(), color: _getFilterColor(), size: screenWidth * 0.05),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    _getFilterText(),
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                      color: _getFilterColor(),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenWidth * 0.04),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _productsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: GroceryLoadingWidget(
                        size: 120,
                        showText: true,
                        loadingText: 'Loading products...',
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Container(
                        padding: EdgeInsets.all(screenWidth * 0.08),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: screenWidth * 0.15,
                              color: Color(0xFF6CA04A),
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            Text(
                              'No Products',
                              style: TextStyle(
                                fontSize: screenWidth * 0.06,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6CA04A),
                              ),
                            ),
                            SizedBox(height: screenWidth * 0.02),
                            Text(
                              _getEmptyStateMessage(),
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Color(0xFF757575),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final product = snapshot.data!.docs[index];
                      final productData = product.data() as Map<String, dynamic>;
                      final productId = product.id;

                      return _buildProductCard(context, screenWidth, productId, productData);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _productsStream = _buildProductsStream();
    _ticker = Ticker((_) {
      final current = DateTime.now();
      if (current.second != _nowNotifier.value.second) {
        _nowNotifier.value = current;
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    _nowNotifier.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _buildProductsStream() {
    final baseQuery = FirebaseFirestore.instance.collection('products');

    switch (_filterStatus) {
      case 'pending':
        return baseQuery
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots();
      case 'flagged':
        return baseQuery
            .where('contentFlagged', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots();
      case 'approved':
        return baseQuery
            .where('status', isEqualTo: 'approved')
            .orderBy('updatedAt', descending: true)
            .snapshots();
      case 'rejected':
        return baseQuery
            .where('status', isEqualTo: 'rejected')
            .orderBy('updatedAt', descending: true)
            .snapshots();
      case 'recently_processed':
        // Show products that were processed in the last 24 hours
        final yesterday = DateTime.now().subtract(const Duration(hours: 24));
        return baseQuery
            .where('updatedAt', isGreaterThan: Timestamp.fromDate(yesterday))
            .where('reviewedBy', whereIn: ['admin', 'system_auto_approval'])
            .orderBy('updatedAt', descending: true)
            .snapshots();
      default:
        return baseQuery.orderBy('createdAt', descending: true).snapshots();
    }
  }

  Color _getFilterColor() {
    switch (_filterStatus) {
      case 'pending':
        return Colors.orange;
      case 'flagged':
        return Colors.red;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'recently_processed':
        return Colors.purple;
      default:
        return Color(0xFF6CA04A);
    }
  }

  IconData _getFilterIcon() {
    switch (_filterStatus) {
      case 'pending':
        return Icons.pending;
      case 'flagged':
        return Icons.warning;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'recently_processed':
        return Icons.history;
      default:
        return Icons.list;
    }
  }

  String _getFilterText() {
    switch (_filterStatus) {
      case 'pending':
        return 'Pending Review';
      case 'flagged':
        return 'Content Flagged';
      case 'approved':
        return 'Approved Products';
      case 'rejected':
        return 'Rejected Products';
      case 'recently_processed':
        return 'Recently Processed';
      default:
        return 'All Products';
    }
  }

  String _getEmptyStateMessage() {
    switch (_filterStatus) {
      case 'pending':
        return 'All products have been reviewed';
      case 'flagged':
        return 'No content violations detected';
      case 'approved':
        return 'No approved products in this filter';
      case 'rejected':
        return 'No rejected products in this filter';
      case 'recently_processed':
        return 'No products have been processed in the last 24 hours.';
      default:
        return 'No pending listings to verify';
    }
  }

  String _formatTimeRemaining(Timestamp? autoApprovalScheduledAt, DateTime now) {
    if (autoApprovalScheduledAt == null) return '';
    
    final scheduledTime = autoApprovalScheduledAt.toDate();
    final difference = scheduledTime.difference(now);
    
    if (difference.isNegative) {
      return 'Auto-approval overdue';
    }
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;
    
    if (hours > 0) {
      return 'Auto-approval in ${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return 'Auto-approval in ${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return 'Auto-approval in ${seconds}s';
    }
  }

  Widget _buildProductCard(BuildContext context, double screenWidth, String productId, Map<String, dynamic> product) {
    final contentCheck = _contentFilterService.checkProductContent(
      productName: product['name'] ?? '',
      description: product['description'] ?? '',
      supplierId: product['sellerId'] ?? '',
      category: product['category'],
      price: product['price']?.toDouble(),
    );

    final isFlagged = product['contentFlagged'] == true || contentCheck.issues.isNotEmpty;
    final isTrusted = contentCheck.isTrustedSupplier;
    final autoApprovalScheduledAt = product['autoApprovalScheduledAt'] as Timestamp?;
    final reviewedBy = product['reviewedBy'] as String?;
    final isAutoApproved = reviewedBy == 'system_auto_approval';
    final isPending = product['status'] == 'pending' || product['status'] == null;

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badges row
                Row(
                  children: [
                    // Content Status Badge
                    if (isFlagged)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenWidth * 0.01),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(screenWidth * 0.02),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: screenWidth * 0.04),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              'Content Flagged',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isFlagged && isTrusted) SizedBox(width: screenWidth * 0.02),
                    if (isTrusted)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenWidth * 0.01),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(screenWidth * 0.02),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.green, size: screenWidth * 0.04),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              'Trusted Supplier',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isAutoApproved)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenWidth * 0.01),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(screenWidth * 0.02),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, color: Colors.blue, size: screenWidth * 0.04),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              'Auto-Approved',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: screenWidth * 0.02),
                
                // Product Image and Basic Info
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                      child: SizedBox(
                        width: screenWidth * 0.2,
                        height: screenWidth * 0.2,
                        child: product['imageUrl'] != null
                            ? Image.network(
                                product['imageUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Color(0xFFF8FAF5),
                                    child: Icon(
                                      Icons.image,
                                      color: Color(0xFF757575),
                                      size: screenWidth * 0.08,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Color(0xFFF8FAF5),
                                child: Icon(
                                  Icons.image,
                                  color: Color(0xFF757575),
                                  size: screenWidth * 0.08,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Unknown Product',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.01),
                          Text(
                            '\u20b1${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.01),
                          Text(
                            'Stock: ${product['quantity'] ?? 0} ${product['unit'] ?? ''}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenWidth * 0.03),
                
                // Supplier Info
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: Color(0xFF6CA04A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: screenWidth * 0.05,
                        color: Color(0xFF6CA04A),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: Text(
                          'Supplier: ${product['supplierName'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Color(0xFF6CA04A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenWidth * 0.03),
                
                // Description
                if (product['description'] != null && product['description'].toString().isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description:',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.01),
                      Text(
                        product['description'],
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Color(0xFF757575),
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.03),
                    ],
                  ),
                  
                // Content Issues (if any)
                if (contentCheck.issues.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Content Issues:',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.01),
                        ...contentCheck.issues.map((issue) => Padding(
                              padding: EdgeInsets.only(bottom: screenWidth * 0.01),
                              child: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red, size: screenWidth * 0.03),
                                  SizedBox(width: screenWidth * 0.01),
                                  Expanded(
                                    child: Text(
                                      issue,
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.03,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.03),
                ],
                
                // Auto-approval timer info for pending products
                if (isPending && autoApprovalScheduledAt != null) ...[
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.orange, size: screenWidth * 0.04),
                        SizedBox(width: screenWidth * 0.02),
                        Expanded(
                          child: ValueListenableBuilder<DateTime>(
                            valueListenable: _nowNotifier,
                            builder: (_, now, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-approval scheduled for 5 minutes after submission',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.03,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatTimeRemaining(autoApprovalScheduledAt, now),
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.03),
                ],
                
                // Action Buttons
                if (isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6CA04A),
                          ),
                          onPressed: () => _verifyProduct(context, productId, true),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                            child: Text(
                              'Approve',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => _verifyProduct(context, productId, false),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                            child: Text(
                              'Reject',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Show processed status
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: (product['status'] == 'approved' ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      border: Border.all(color: product['status'] == 'approved' ? Colors.green : Colors.red),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          product['status'] == 'approved' ? Icons.check_circle : Icons.cancel,
                          color: product['status'] == 'approved' ? Colors.green : Colors.red,
                          size: screenWidth * 0.04,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          product['status'] == 'approved'
                              ? (isAutoApproved ? 'Product Auto-Approved - Now Visible to Buyers' : 'Product Approved - Now Visible to Buyers')
                              : 'Product Rejected',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: product['status'] == 'approved' ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            // Live countdown timer in upper right corner for pending products
            if (isPending)
              Positioned(
                top: 0,
                right: 0,
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _nowNotifier,
                  builder: (_, now, _) {
                    // First check if product is no longer pending (auto-approved or manually reviewed)
                    if (product['status'] != 'pending') {
                      if (product['status'] == 'approved' && product['autoApproved'] == true) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 18, color: Colors.green),
                              SizedBox(width: 6),
                              Text(
                                'AUTO-APPROVED',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (product['status'] == 'approved') {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 18, color: Colors.blue),
                              SizedBox(width: 6),
                              Text(
                                'APPROVED',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (product['status'] == 'rejected') {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cancel, size: 18, color: Colors.red),
                              SizedBox(width: 6),
                              Text(
                                'REJECTED',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }

                    // Calculate auto-approval time: use autoApprovalScheduledAt or fallback to createdAt + 5 minutes
                    DateTime scheduledTime;
                    if (autoApprovalScheduledAt != null) {
                      scheduledTime = autoApprovalScheduledAt.toDate();
                    } else {
                      // Fallback: use createdAt + 5 minutes if autoApprovalScheduledAt is not set
                      final createdAt = product['createdAt'] as Timestamp?;
                      if (createdAt != null) {
                        scheduledTime = createdAt.toDate().add(Duration(minutes: 5));
                      } else {
                        // Last fallback: assume created now + 5 minutes
                        scheduledTime = DateTime.now().add(Duration(minutes: 5));
                      }
                    }
                    
                    final timeLeft = scheduledTime.difference(now);
                    
                    String countdownText;
                    Color textColor = Colors.orange;
                    
                    if (timeLeft.isNegative) {
                      countdownText = 'PROCESSING...';
                      textColor = Colors.blue;
                    } else {
                      final minutes = timeLeft.inMinutes;
                      final seconds = timeLeft.inSeconds % 60;
                      
                      if (minutes > 0) {
                        countdownText = '${minutes}m ${seconds}s';
                      } else {
                        countdownText = '${seconds}s';
                        textColor = Colors.red;
                      }
                    }
                    
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: textColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: textColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            timeLeft.isNegative ? Icons.hourglass_empty : Icons.timer,
                            size: 18,
                            color: textColor,
                          ),
                          SizedBox(width: 6),
                          Text(
                            countdownText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyProduct(BuildContext context, String productId, bool isApproved) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Get product data for notification
      final productDoc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      final productData = productDoc.data();
      final productName = productData?['name'] ?? 'Unknown Product';
      final supplierId = productData?['supplierId'] ?? '';

      if (isApproved) {
        // Manual approval - this will cancel the Cloud Function auto-approval
        await FirebaseFirestore.instance.collection('products').doc(productId).update({
          'status': 'approved',
          'isVerified': true,
          'isActive': true,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': user.uid,
          'rejectionReason': '',
          'autoApproved': false,
          'updatedAt': FieldValue.serverTimestamp(),
          // Remove auto-approval scheduling since it's manually approved
          'autoApprovalScheduledAt': FieldValue.delete(),
        });

        // Send FCM notification to supplier about approval
        if (supplierId.isNotEmpty) {
          await _notificationService.sendProductApprovalNotification(
            productName: productName,
            status: 'approved',
            supplierId: supplierId,
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product approved and now visible to buyers!')),
        );

        // Switch to recently processed filter to show the result
        setState(() {
          _filterStatus = 'recently_processed';
        });
      } else {
        final reason = await _showRejectionDialog(context);
        if (reason == null || reason.trim().isEmpty) return;
        
        await FirebaseFirestore.instance.collection('products').doc(productId).update({
          'isVerified': false,
          'isActive': false,
          'status': 'rejected',
          'rejectionReason': reason.trim(),
          'reviewedBy': user.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'contentFlagged': true,
          'autoApproved': false,
          'updatedAt': FieldValue.serverTimestamp(),
          // Remove auto-approval scheduling since it's manually rejected
          'autoApprovalScheduledAt': FieldValue.delete(),
        });

        // Send FCM notification to supplier about rejection
        if (supplierId.isNotEmpty) {
          await _notificationService.sendProductApprovalNotification(
            productName: productName,
            status: 'rejected',
            supplierId: supplierId,
            reason: reason.trim(),
          );
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product rejected.')),
        );

        // Switch to recently processed filter to show the result
        setState(() {
          _filterStatus = 'recently_processed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying product: $e')),
      );
    }
  }

  Future<String?> _showRejectionDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This product will be auto-approved if not reviewed within 5 minutes. Please make your decision promptly.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Reason for rejection'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}