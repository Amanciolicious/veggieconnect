// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:veggieconnect/config/paymongo_config.dart';
import '../widgets/lottie_loading_widget.dart';

class PayMongoGCashService {
  // Creates a Checkout Session via Cloud Function and launches the PayMongo URL
  static Future<GCashPaymentResult?> processPayment({
    required BuildContext context,
    required double amount,
    required String orderId,
    required String description,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => _buildPaymentDialog(c, 'Preparing secure checkout...'),
    );

    try {
      final int amountCentavos = (amount * 100).round();

      final response = await http.post(
        Uri.parse(PaymongoConfig.checkoutFunctionUrl),
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncode({
          'amount': amountCentavos,
          'description': description,
          'successUrl': _buildSuccessUrl(orderId),
          'cancelUrl': _buildCancelUrl(orderId),
          'customerName': await _getBuyerName(),
          'customerEmail': await _getBuyerEmail(),
          'customerPhone': await _getBuyerPhone(),
          'metadata': {
            'orderId': orderId,
            'app': 'VeggieConnect',
            'version': '1.0.0',
          },
        }),
      );

      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode != 200) {
        final error = response.body.isNotEmpty ? response.body : 'Failed to create checkout';
        return GCashPaymentResult(success: false, error: error);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final checkoutUrl = data['checkout_url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return GCashPaymentResult(success: false, error: 'No checkout URL received');
      }

      final canLaunch = await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      if (!canLaunch) {
        return GCashPaymentResult(success: false, error: 'Could not launch checkout URL');
      }

      return GCashPaymentResult(success: true, orderId: orderId, checkoutUrl: checkoutUrl, message: 'Redirected to PayMongo');
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      return GCashPaymentResult(success: false, error: e.toString());
    }
  }


  static String _buildSuccessUrl(String orderId) {
    // You can add query params to identify the order when you handle redirect/webhook
    return '${PaymongoConfig.successUrl}?orderId=$orderId&status=success';
  }

  static String _buildCancelUrl(String orderId) {
    return '${PaymongoConfig.cancelUrl}?orderId=$orderId&status=cancelled';
  }

  static Future<String> _getBuyerName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Guest';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      return (data?['name'] as String?) ?? (user.displayName ?? 'Guest');
    } catch (_) {
      return user.displayName ?? 'Guest';
    }
  }

  static Future<String> _getBuyerEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? 'guest@example.com';
  }

  static Future<String> _getBuyerPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final data = doc.data();
      final phone = data?['phone'] as String?;
      return phone ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Build loading dialog
  static Widget _buildPaymentDialog(BuildContext context, String message) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GroceryLoadingWidget(
            size: 80,
            showText: false,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class GCashPaymentResult {
  final bool success;
  final String? transactionId;
  final String? orderId;
  final String? paymentIntentId;
  final String? error;
  final String? checkoutUrl;
  final String? message;

  GCashPaymentResult({
    required this.success,
    this.transactionId,
    this.orderId,
    this.paymentIntentId,
    this.error,
    this.checkoutUrl,
    this.message,
  });
}
