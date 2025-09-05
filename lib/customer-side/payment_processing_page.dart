// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/paypal_sandbox_service.dart';
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
    _processPayment();
  }

  Future<void> _processPayment() async {
    if (widget.paymentMethod == 'cash_on_pickup') {
      // For cash on pickup, just navigate to success
      _navigateToSuccess();
      return;
    }

    if (widget.paymentMethod == 'paypal_sandbox') {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      try {
        final result = await PayPalSandboxService.processPayment(
          context: context,
          amount: widget.total,
          currency: 'PHP',
          orderId: widget.orderId,
          description: 'VeggieConnect Order - PayPal Sandbox',
          cartItems: widget.cartItems,
        );

        if (result?.success == true) {
          // Process successful order
          await PayPalSandboxService.processSuccessfulOrder(
            context: context,
            orderId: widget.orderId,
            transactionId: result!.transactionId!,
            cartItems: widget.cartItems,
            total: widget.total,
            paymentMethod: widget.paymentMethod,
          );
          
          // Navigate to success page
          _navigateToSuccess();
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = result?.error ?? 'Payment failed';
          });
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
      return;
    }

    // Unsupported payment method
    setState(() {
      _isProcessing = false;
      _errorMessage = 'Unsupported payment method: ${widget.paymentMethod}';
    });
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

  void _cancelPayment() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 720;

    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Processing Payment',
          style: TextStyle(
            fontSize: isSmallScreen ? screenWidth * 0.045 : screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              // Processing state
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
                strokeWidth: 4,
              ),
              SizedBox(height: screenWidth * 0.06),
              Text(
                'Processing your payment...',
                style: TextStyle(
                  fontSize: isSmallScreen ? screenWidth * 0.045 : screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: screenWidth * 0.02),
              Text(
                'Please wait while we process your ${_getPaymentMethodDisplayName()} payment.',
                style: TextStyle(
                  fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                  color: Colors.grey[600],
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (_errorMessage != null) ...[
              // Error state
              Icon(
                Icons.error_outline,
                size: screenWidth * 0.15,
                color: Colors.red,
              ),
              SizedBox(height: screenWidth * 0.04),
              Text(
                'Payment Failed',
                style: TextStyle(
                  fontSize: isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.055,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Colors.red,
                ),
              ),
              SizedBox(height: screenWidth * 0.02),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                  color: Colors.grey[600],
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth * 0.06),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _cancelPayment,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6CA04A),
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _retryPayment,
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
      ),
    );
  }

  String _getPaymentMethodDisplayName() {
    switch (widget.paymentMethod) {
      case 'cash_on_pickup':
        return 'Cash on Pickup';
      case 'paypal_sandbox':
        return 'PayPal Sandbox';
      default:
        return 'Payment';
    }
  }
}
