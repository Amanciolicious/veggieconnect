// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/paymongo_gcash_service.dart';
import '../services/payment_completion_service.dart';
import 'digital_receipt_page.dart';

class PaymentProcessingPage extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems;
  final double total;
  final String paymentMethod;
  final String orderId;
  final double? discountAmount;
  final double? originalAmount;
  final bool? hasPromoApplied;
  final String? promoType;

  const PaymentProcessingPage({
    super.key,
    required this.cartItems,
    required this.total,
    required this.paymentMethod,
    required this.orderId,
    this.discountAmount,
    this.originalAmount,
    this.hasPromoApplied,
    this.promoType,
  });

  @override
  State<PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

class _PaymentProcessingPageState extends State<PaymentProcessingPage> {
  bool _isProcessing = false;
  String? _errorMessage;
  Timer? _autoCompleteTimer;

  @override
  void initState() {
    super.initState();
    // Defer until after first frame so BuildContext dependencies are available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPayment();
    });
  }

  @override
  void dispose() {
    _autoCompleteTimer?.cancel();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (widget.paymentMethod == 'cash_on_pickup') {
      // For cash on pickup, store order and navigate to success
      await _storeOrderToFirestore();
      _navigateToSuccess();
      return;
    }

    if (widget.paymentMethod == 'gcash' || widget.paymentMethod == 'grab_pay' || 
        widget.paymentMethod == 'paymaya' || widget.paymentMethod == 'card' || 
        widget.paymentMethod == 'online_payment') {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      try {
        // Store temporary order data for webhook processing
        await _storeTemporaryOrderData();
        
        // Use PayMongo service for all online payment methods
        final result = await PayMongoGCashService.processPayment(
          context: context,
          amount: widget.total,
          orderId: widget.orderId,
          description: 'VeggieConnect Order #${widget.orderId}',
          cartItems: widget.cartItems,
        );

        if (result?.success == true) {
          // Payment initiated successfully - user redirected to PayMongo
          _showPaymentSuccessMessage();
          // Start automatic order completion after 5 seconds
          _startAutoCompleteTimer();
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = result?.error ?? 'Payment failed. Please try again.';
          });
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Payment error: $e';
        });
      }
      return;
    }
  }

  void _showPaymentSuccessMessage() {
    setState(() {
      _isProcessing = false;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Initiated'),
        content: Text(
          'Your ${_getPaymentMethodDisplayName()} payment has been initiated. You will be redirected to complete the payment.\n\n'
          'Your order #${widget.orderId.substring(0, 8).toUpperCase()} has been saved and will be processed automatically once payment is confirmed.\n\n'
          'After completing payment, you will be redirected back to the app to view your order receipt.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Start monitoring for payment completion
              _monitorPaymentCompletion();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _monitorPaymentCompletion() {
    // Start a timer to check for payment completion
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      print('Checking for payment completion...');
      
      // Check if widget is still mounted before proceeding
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Check if the order has been completed by webhook
      final orderQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: widget.orderId)
          .get();
      
      if (orderQuery.docs.isNotEmpty) {
        timer.cancel();
        print('Order completed! Navigating to success page...');
        if (mounted) {
          _navigateToSuccess();
        }
        return;
      }
      
      // Check if temp order still exists (payment not completed)
      final tempOrderDoc = await FirebaseFirestore.instance
          .collection('temp_orders')
          .doc(widget.orderId)
          .get();
      
      if (!tempOrderDoc.exists) {
        // Temp order was processed, check for actual orders
        final orderQuery2 = await FirebaseFirestore.instance
            .collection('orders')
            .where('orderId', isEqualTo: widget.orderId)
            .get();
        
        if (orderQuery2.docs.isNotEmpty) {
          timer.cancel();
          print('Order completed! Navigating to success page...');
          if (mounted) {
            _navigateToSuccess();
          }
        }
      }
      
      // Stop monitoring after 2 minutes
      if (timer.tick >= 40) { // 40 * 3 seconds = 2 minutes
        timer.cancel();
        print('Payment monitoring timeout');
        if (mounted) {
          _showPaymentTimeoutDialog();
        }
      }
    });
  }

  void _showPaymentTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Completing Your Order'),
        content: const Text(
          'We are automatically completing your order. This may take a few moments.\n\n'
          'Please wait while we process your payment and create your order.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _autoCompleteOrder();
            },
            child: const Text('Complete Order'),
          ),
        ],
      ),
    );
  }

  void _startAutoCompleteTimer() {
    _autoCompleteTimer = Timer(const Duration(seconds: 5), () async {
      if (mounted) {
        await _autoCompleteOrder();
      }
    });
  }

  Future<void> _autoCompleteOrder() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Try to complete the order automatically
      await PaymentCompletionService.completeOrder(widget.orderId);
      
      // Check if order was created
      final orderQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: widget.orderId)
          .get();
      
      if (orderQuery.docs.isNotEmpty) {
        setState(() {
          _isProcessing = false;
        });
        if (mounted) {
          _navigateToSuccess();
        }
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Unable to complete order. Please contact support.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error completing order: $e';
      });
    }
  }

  void _navigateToSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DigitalReceiptPage(
          cartItems: widget.cartItems,
          total: widget.total,
          paymentMethod: widget.paymentMethod,
          orderId: widget.orderId,
          discountAmount: widget.discountAmount,
          originalAmount: widget.originalAmount,
          hasPromoApplied: widget.hasPromoApplied,
          promoType: widget.promoType,
        ),
      ),
    );
  }

  Future<void> _storeTemporaryOrderData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Resolve buyer name for supplier views
      String buyerName = user.displayName ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          buyerName = (userDoc.data() as Map<String, dynamic>)['name'] ?? buyerName;
        }
      } catch (_) {}

      // Store temporary order data for webhook processing
      await FirebaseFirestore.instance.collection('temp_orders').doc(widget.orderId).set({
        'orderId': widget.orderId,
        'buyerId': user.uid,
        'buyerName': buyerName,
        'amount': widget.total,
        'cartItems': widget.cartItems.map((doc) => {
          ...doc.data(),
          'cartDocId': doc.id, // Include cart document ID for removal
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending_payment',
        'paymentMethod': widget.paymentMethod,
        'originalAmount': widget.originalAmount ?? widget.total,
        'discountAmount': widget.discountAmount ?? 0.0,
        'hasPromoApplied': widget.hasPromoApplied ?? false,
        'promoType': widget.promoType,
      });
      
      print('Temporary order data stored: ${widget.orderId}');
    } catch (e) {
      print('Error storing temporary order data: $e');
      throw e;
    }
  }

  Future<void> _storeOrderToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Resolve buyer name for supplier views
      String buyerName = user.displayName ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          buyerName = (userDoc.data() as Map<String, dynamic>)['name'] ?? buyerName;
        }
      } catch (_) {}

      // Create individual orders for each cart item (same structure as checkout summary)
      final batch = FirebaseFirestore.instance.batch();
      final ordersRef = FirebaseFirestore.instance.collection('orders');

      for (final doc in widget.cartItems) {
        final data = doc.data();
        final orderDoc = ordersRef.doc();
        final itemTotal = (data['price'] ?? 0) * (data['quantity'] ?? 1);

        batch.set(orderDoc, {
          'buyerId': user.uid,
          'buyerName': buyerName,
          'productId': data['productId'],
          'sellerId': data['sellerId'],
          'productName': data['name'],
          'quantity': data['quantity'],
          'unit': data['unit'],
          'price': data['price'],
          'status': widget.paymentMethod == 'cash_on_pickup' ? 'pending' : 'processing',
          'createdAt': FieldValue.serverTimestamp(),
          'paymentMethod': widget.paymentMethod,
          'paymentStatus': widget.paymentMethod == 'cash_on_pickup' ? 'pending' : 'processing',
          'paymentAmount': widget.total,
          'originalAmount': widget.originalAmount ?? widget.total,
          'discountAmount': widget.discountAmount ?? 0.0,
          'hasPromoApplied': widget.hasPromoApplied ?? false,
          'promoType': widget.promoType,
          'paymentDate': FieldValue.serverTimestamp(),
          'imageUrl': data['imageUrl'],
          'supplierName': data['supplierName'],
          'orderId': widget.orderId,
          'totalAmount': widget.total,
        });
      }

      // Commit the batch to create all orders
      await batch.commit();
      print('Orders stored to Firestore: ${widget.orderId}');
    } catch (e) {
      print('Error storing orders to Firestore: $e');
      throw e;
    }
  }

  void _retryPayment() {
    _processPayment();
  }

  String _getPaymentMethodDisplayName() {
    switch (widget.paymentMethod.toLowerCase()) {
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
    final isSmallScreen = screenWidth <= 720;

    return HeroMode(
      enabled: false,
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Processing Payment',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6CA04A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6CA04A)),
                strokeWidth: 3,
              ),
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Processing your payment...',
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.045 : screenWidth * 0.05,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (_errorMessage != null) ...[
              Icon(
                Icons.error_outline,
                size: screenWidth * 0.15,
                color: Colors.red,
              ),
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Payment Error',
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.06,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: screenWidth * 0.03),
              Text(
                _errorMessage!,
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth * 0.05),
              ElevatedButton(
                onPressed: _retryPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6CA04A),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08,
                    vertical: screenWidth * 0.03,
                  ),
                ),
                child: Text(
                  'Retry Payment',
                  style: GoogleFonts.quicksand(
                    fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              Icon(
                Icons.check_circle,
                size: screenWidth * 0.15,
                color: Colors.green,
              ),
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Payment Successful',
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.06,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Your order is being processed automatically. Please wait...',
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth * 0.05),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6CA04A)),
                strokeWidth: 3,
              ),
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Automatically completing your order...',
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ));
  }
}