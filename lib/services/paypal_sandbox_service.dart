// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PayPalSandboxService {
  // Sample PayPal Sandbox URLs - Replace with your actual PayPal Developer Dashboard URLs
  static const String _sandboxBaseUrl = 'https://www.sandbox.paypal.com';
  static const String _sampleCheckoutUrl = 'https://www.sandbox.paypal.com/checkoutnow?token=EC-60U79048BN7719609';
  
  // PayPal Sandbox Test Accounts (for demo purposes)
  static const Map<String, String> testAccounts = {
    'buyer': 'buyer@paypalsandbox.com',
    'seller': 'seller@paypalsandbox.com',
    'password': 'PayPal123!',
  };

  /// Generate a PayPal Sandbox checkout URL
  /// In real implementation, this would call PayPal API to create payment
  static String generateCheckoutUrl({
    required double amount,
    required String currency,
    required String orderId,
    required String description,
  }) {
    // For demo purposes, we'll use the sample URL
    // In real implementation, you would:
    // 1. Call PayPal API to create payment
    // 2. Get approval URL from PayPal response
    // 3. Return the actual checkout URL
    
    return _sampleCheckoutUrl;
  }

  /// Process PayPal payment by opening browser
  static Future<PayPalPaymentResult?> processPayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String orderId,
    required String description,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems,
  }) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildPaymentDialog(context, 'Opening PayPal...'),
      );

      // Generate checkout URL
      final checkoutUrl = generateCheckoutUrl(
        amount: amount,
        currency: currency,
        orderId: orderId,
        description: description,
      );

      // Launch PayPal checkout in browser
      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        Navigator.of(context).pop(); // Close loading dialog
        return PayPalPaymentResult(
          success: false,
          error: 'Could not open PayPal checkout page',
        );
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Show payment status dialog
      return await _showPaymentStatusDialog(
        context,
        amount,
        currency,
        orderId,
        cartItems,
      );

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      return PayPalPaymentResult(
        success: false,
        error: 'Payment failed: $e',
      );
    }
  }

  /// Show payment status dialog with success/cancel options
  static Future<PayPalPaymentResult?> _showPaymentStatusDialog(
    BuildContext context,
    double amount,
    String currency,
    String orderId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems,
  ) async {
    return await showDialog<PayPalPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'PayPal Payment',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Complete your payment in the browser window that opened.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Order Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Order ID: $orderId'),
                  Text('Amount: ₱${amount.toStringAsFixed(2)}'),
                  Text('Items: ${cartItems.length}'),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Did you complete the payment?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(PayPalPaymentResult(
                success: false,
                error: 'Payment cancelled by user',
              ));
            },
            child: Text(
              'Cancel Payment',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Simulate successful payment processing
              Navigator.of(context).pop(PayPalPaymentResult(
                success: true,
                transactionId: 'PAYPAL-${DateTime.now().millisecondsSinceEpoch}',
                orderId: orderId,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Payment Complete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build loading dialog
  static Widget _buildPaymentDialog(BuildContext context, String message) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Process order after successful payment
  static Future<void> processSuccessfulOrder({
    required BuildContext context,
    required String orderId,
    required String transactionId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems,
    required double total,
    required String paymentMethod,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create batch for Firestore operations
      final batch = FirebaseFirestore.instance.batch();
      
      // Get buyer name
      String buyerName = user.displayName ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          buyerName = (userDoc.data() as Map<String, dynamic>)['name'] ?? buyerName;
        }
      } catch (_) {}

      // Create orders
      final ordersRef = FirebaseFirestore.instance.collection('orders');
      final cartRef = FirebaseFirestore.instance.collection('cart').doc(user.uid).collection('items');

      for (final doc in cartItems) {
        final data = doc.data();
        batch.set(ordersRef.doc(), {
          'buyerId': user.uid,
          'buyerName': buyerName,
          'productId': data['productId'],
          'sellerId': data['sellerId'],
          'productName': data['name'],
          'quantity': data['quantity'],
          'unit': data['unit'],
          'price': data['price'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'paymentMethod': paymentMethod,
          'paymentStatus': 'paid',
          'transactionId': transactionId,
          'orderId': orderId,
        });
        
        // Remove from cart
        batch.delete(cartRef.doc(doc.id));
      }

      await batch.commit();

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order placed successfully! Transaction ID: $transactionId'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get PayPal test account information
  static Map<String, String> getTestAccountInfo() {
    return {
      'Buyer Email': testAccounts['buyer']!,
      'Seller Email': testAccounts['seller']!,
      'Password': testAccounts['password']!,
      'Note': 'Use these credentials to test PayPal Sandbox payments',
    };
  }
}

class PayPalPaymentResult {
  final bool success;
  final String? transactionId;
  final String? orderId;
  final String? error;

  PayPalPaymentResult({
    required this.success,
    this.transactionId,
    this.orderId,
    this.error,
  });
}
