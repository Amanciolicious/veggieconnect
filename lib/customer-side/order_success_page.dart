import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'digital_receipt_page.dart';
import 'buyer_order_history_page.dart';

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
          
          // Check if any orders are still processing
          bool hasProcessingOrders = false;
          for (final doc in ordersQuery.docs) {
            final data = doc.data();
            if (data['status'] == 'processing' || data['status'] == 'pending') {
              hasProcessingOrders = true;
              break;
            }
          }
          
          // Update all orders to completed if any are still processing
          if (hasProcessingOrders) {
            final batch = FirebaseFirestore.instance.batch();
            for (final doc in ordersQuery.docs) {
              batch.update(doc.reference, {
                'status': 'completed',
                'completedAt': FieldValue.serverTimestamp(),
                'paymentStatus': 'completed',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
            await batch.commit();
            
            // Update the order data
            orderData['status'] = 'completed';
            orderData['paymentStatus'] = 'completed';
          }
          
          setState(() {
            _orderData = orderData;
            _isLoading = false;
          });
          
          // Automatically show the digital receipt after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _viewReceipt();
            }
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

  void _viewReceipt() {
    if (_orderData == null) return;

    // Create a simple completion message and navigate to order history
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Order Placed Successfully! 🎉'),
        content: Text(
          'Your order #${widget.orderId!.substring(0, 8).toUpperCase()} has been placed and payment confirmed.\n\n'
          'You will receive updates about your order status. Thank you for choosing VeggieConnect!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BuyerOrderHistoryPage(),
                ),
              );
            },
            child: const Text('View Orders'),
          ),
        ],
      ),
    );
  }

  void _viewOrders() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const BuyerOrderHistoryPage(),
      ),
    );
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF5),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
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
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6CA04A),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: Text(
                    'Go Back',
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
                      Text(
                        'Payment Successful!',
                        style: GoogleFonts.quicksand(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6CA04A),
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      Text(
                        'Your order has been placed successfully. Welcome to the league!',
                        style: GoogleFonts.quicksand(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      
                      // Order Info
                      if (_orderData != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6CA04A).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order #${widget.orderId!.substring(0, 8).toUpperCase()}',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6CA04A),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Processing',
                                      style: GoogleFonts.quicksand(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.payment, color: Color(0xFF6CA04A), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getPaymentMethodDisplayName(_orderData!['paymentMethod'] ?? 'Online Payment'),
                                    style: GoogleFonts.quicksand(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                          onPressed: _viewOrders,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF6CA04A), width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'View All Orders',
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
    );
  }
}
