// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_state_service.dart';
import '../services/paymongo_gcash_service.dart';
import 'customer_digital_receipt_page.dart';
import '../widgets/lottie_loading_widget.dart';

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
  final AuthStateService _authService = AuthStateService();
  AuthUser? get user => _authService.currentUser;

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
          _showPaymentInitiatedMessage();
          // Begin monitoring Firestore for webhook-confirmed order creation
          _monitorPaymentCompletion();
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

  void _showPaymentInitiatedMessage() {
    // Keep processing state true; only navigate once webhook confirms
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Continue in PayMongo'),
        content: Text(
          'Your ${_getPaymentMethodDisplayName()} payment has been initiated. Complete the payment in the PayMongo page.\n\n'
          'Once PayMongo confirms your payment, we will automatically show your digital receipt here.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
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
          final orderDoc = orderQuery.docs.first;
          final data = orderDoc.data();
          final method = (data['paymentMethod'] as String?) ?? widget.paymentMethod;
          _navigateToSuccess(method);
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
            final orderDoc2 = orderQuery2.docs.first;
            final data2 = orderDoc2.data();
            final method2 = (data2['paymentMethod'] as String?) ?? widget.paymentMethod;
            _navigateToSuccess(method2);
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
          'We didn\'t receive payment confirmation yet. If you\'ve completed payment, please wait a bit longer.\n\n'
          'If you cancelled the payment, you can close this and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToSuccess([String? paymentMethodOverride]) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DigitalReceiptPage(
          cartItems: widget.cartItems,
          total: widget.total,
          paymentMethod: paymentMethodOverride ?? widget.paymentMethod,
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
      // Resolve buyer name for supplier views
      String buyerName = user?.displayName ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
        if (userDoc.exists) {
          buyerName = (userDoc.data() as Map<String, dynamic>)['name'] ?? buyerName;
        }
      } catch (_) {}

      // Store temporary order data for webhook processing
      await FirebaseFirestore.instance.collection('temp_orders').doc(widget.orderId).set({
        'orderId': widget.orderId,
        'buyerId': user?.uid,
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
      rethrow;
    }
  }

  Future<void> _storeOrderToFirestore() async {
    try {
      // Resolve buyer name for supplier views
      String buyerName = user?.displayName ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
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
          'buyerId': user?.uid,
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
      rethrow;
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
              const GroceryLoadingWidget(
                size: 120,
                showText: true,
                loadingText: 'Awaiting payment confirmation...',
              ),
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Awaiting payment confirmation from PayMongo...',
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.045 : screenWidth * 0.05,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth * 0.02),
              Text(
                'Complete your payment in the opened PayMongo page. This screen will update automatically once confirmed.',
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
                  color: Colors.grey[600],
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
              // Fallback (should not normally be reached now)
              const GroceryLoadingWidget(
                size: 100,
                showText: true,
                loadingText: 'Preparing secure checkout...',
              ),
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Preparing secure checkout...',
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                  color: Colors.grey[600],
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