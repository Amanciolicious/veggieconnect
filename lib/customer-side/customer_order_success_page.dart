// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_digital_receipt_page.dart';
import 'customer_order_history_page.dart';
import '../widgets/lottie_loading_widget.dart';
import '../widgets/modern_app_bar.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'customer_dashboard.dart';

class OrderSuccessPage extends StatefulWidget {
  final String? orderId;
  final String? status;
  
  const OrderSuccessPage({
    super.key,
    this.orderId,
    this.status,
  });

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _orderData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    print('OrderSuccessPage initialized with orderId: ${widget.orderId}, status: ${widget.status}');
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    if (widget.orderId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No order ID provided';
      });
      return;
    }

    try {
      // Wait a bit for webhook to process the order
      await Future.delayed(const Duration(seconds: 2));
      
      // Try to fetch orders with retry logic
      int retryCount = 0;
      const maxRetries = 5;
      
      while (retryCount < maxRetries) {
        final ordersQuery = await FirebaseFirestore.instance
            .collection('orders')
            .where('orderId', isEqualTo: widget.orderId)
            .get();

        if (ordersQuery.docs.isNotEmpty) {
          // Use the first order as the main order data
          final firstOrder = ordersQuery.docs.first;
          final orderData = firstOrder.data();
          
          // Do NOT auto-complete here. Keep order status as-is (e.g., 'pending').
          
          setState(() {
            _orderData = orderData;
            _isLoading = false;
          });
          
          return;
        }
        
        // If no orders found, wait and retry
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      
      // If still no orders found after retries
      setState(() {
        _isLoading = false;
        _errorMessage = 'Order is being processed. Please check back in a few minutes.';
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load order: $e';
      });
    }
  }

  Future<void> _viewReceipt() async {
    if (widget.orderId == null) return;

    try {
      // Fetch the created orders for this orderId to build the receipt view
      final ordersQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: widget.orderId)
          .get();

      if (ordersQuery.docs.isEmpty) {
        // Fallback to order history if nothing found yet
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BuyerOrderHistoryPage()),
        );
        return;
      }

      // Compute total from orders or use first doc totalAmount
      double total = 0.0;
      for (final doc in ordersQuery.docs) {
        final data = doc.data();
        final double price = (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0;
        final int quantity = (data['quantity'] is num) ? (data['quantity'] as num).toInt() : 0;
        total += price * quantity;
      }
      if (total <= 0 && ordersQuery.docs.first.data().containsKey('totalAmount')) {
        final ta = ordersQuery.docs.first.data()['totalAmount'];
        if (ta is num) total = ta.toDouble();
      }

      final String paymentMethod = (ordersQuery.docs.first.data()['paymentMethod'] as String?) ?? 'online_payment';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DigitalReceiptPage(
            cartItems: ordersQuery.docs,
            total: total,
            paymentMethod: paymentMethod,
            orderId: widget.orderId!,
            discountAmount: (ordersQuery.docs.first.data()['discountAmount'] is num)
                ? (ordersQuery.docs.first.data()['discountAmount'] as num).toDouble()
                : null,
            originalAmount: (ordersQuery.docs.first.data()['originalAmount'] is num)
                ? (ordersQuery.docs.first.data()['originalAmount'] as num).toDouble()
                : null,
            hasPromoApplied: (ordersQuery.docs.first.data()['hasPromoApplied'] as bool?) ?? false,
            promoType: ordersQuery.docs.first.data()['promoType'] as String?,
          ),
        ),
      );
    } catch (e) {
      // If anything fails, go to order history as a safe fallback
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BuyerOrderHistoryPage()),
      );
    }
  }
  
  String _getPaymentMethodDisplayName(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'gcash':
        return 'GCash';
      case 'grab_pay':
        return 'GrabPay';
      case 'paymaya':
        return 'PayMaya';
      case 'card':
        return 'Credit/Debit Card';
      case 'online_payment':
        return 'Online Payment';
      default:
        return 'Online Payment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        // Ensure back navigates to the logged-in dashboard and preserves session
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CustomerHomePage()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAF5),
        appBar: const ModernAppBar(
          title: 'Payment Successful',
          showSearch: false,
          showBackButton: true,
        ),
        bottomNavigationBar: CurvedNavigationBar(
          backgroundColor: const Color(0xFF4CAF50),
          color: Colors.white,
          height: 60,
          animationDuration: const Duration(milliseconds: 300),
          items: const [
            Icon(Icons.home, size: 30, color: Colors.green),
            Icon(Icons.favorite, size: 30, color: Colors.green),
            Icon(Icons.shopping_cart, size: 30, color: Colors.green),
            Icon(Icons.search, size: 30, color: Colors.green),
            Icon(Icons.person, size: 30, color: Colors.green),
          ],
          onTap: (index) {
            // Navigate back to dashboard; default to its home tab
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const CustomerHomePage()),
              (route) => false,
            );
          },
        ),
        body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const GroceryLoadingWidget(
                  size: 100,
                  showText: true,
                  loadingText: 'Loading your order...'
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading your order...',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ] else if (_errorMessage.isNotEmpty) ...[
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 20),
                Text(
                  'Error',
                  style: GoogleFonts.quicksand(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage,
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const CustomerHomePage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6CA04A),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: Text(
                    'Go to Dashboard',
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                // Success UI
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.08),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Success Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6CA04A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Success Message
                      Center(
                        child: Text(
                          'Payment Successful!',
                          style: GoogleFonts.quicksand(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6CA04A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      Text(
                        'Your order has been placed successfully.',
                        style: GoogleFonts.quicksand(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      
                     // Order Info
                      if (_orderData != null) ...[
                        SizedBox( // ✅ keeps fixed width
                          width: 250, // set your desired fixed width here
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF6CA04A).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, // align everything left
                              children: [
                                // Order ID + Processing (stacked vertically on the left)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${widget.orderId!.substring(0, 8).toUpperCase()}',
                                      style: GoogleFonts.quicksand(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.visible, // ✅ prevents cropping
                                      softWrap: true,
                                    ),
                                    const SizedBox(height: 7),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6CA04A),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Processing',
                                        style: GoogleFonts.quicksand(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Payment method row
                                Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Flexible( // ✅ avoids overflow while keeping fixed container width
                                      child: Text(
                                        _getPaymentMethodDisplayName(
                                          _orderData!['paymentMethod'] ?? 'Online Payment',
                                        ),
                                        style: GoogleFonts.quicksand(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.visible,
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],

                      
                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _viewReceipt,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6CA04A),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'View Digital Receipt',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const CustomerHomePage()),
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF6CA04A), width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Continue Shopping',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              color: const Color(0xFF6CA04A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ));
  }
}
