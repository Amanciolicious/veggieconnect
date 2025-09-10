// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/paymongo_gcash_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Defer until after first frame so BuildContext dependencies are available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPayment();
    });
  }

  Future<void> _processPayment() async {
    if (widget.paymentMethod == 'cash_on_pickup') {
      // For cash on pickup, just navigate to success
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
          'Your ${_getPaymentMethodDisplayName()} payment has been initiated. You will be redirected to complete the payment. '
          'Your order will be processed once payment is confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
            ],
          ],
        ),
      ),
    ));
  }
}