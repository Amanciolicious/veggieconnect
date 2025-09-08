// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GCashPaymentService {
  // Replace with your backend URL
  static const String _baseUrl = 'http://10.0.2.2:5000'; // For Android emulator
  // For physical device, use your computer's IP address like: 'http://192.168.1.100:5000'
  
  /// Creates a payment intent and returns checkout URL
  static Future<Map<String, dynamic>> createPaymentIntent({
    required int amount, // Amount in cents (e.g., 10000 = PHP 100.00)
    required String currency,
    String? description,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/create_payment_intent');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'description': description ?? 'VeggieConnect Order Payment',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'payment_intent_id': data['payment_intent_id'],
            'checkout_url': data['checkout_url'],
            'amount': data['amount'],
            'currency': data['currency'],
          };
        } else {
          return {
            'success': false,
            'error': data['error']?.first?['detail'] ?? 'Payment creation failed',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Checks payment status
  static Future<Map<String, dynamic>> checkPaymentStatus(String paymentIntentId) async {
    try {
      final url = Uri.parse('$_baseUrl/payment_status/$paymentIntentId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'status': data['status'],
            'amount': data['amount'],
            'currency': data['currency'],
            'created_at': data['created_at'],
            'updated_at': data['updated_at'],
          };
        } else {
          return {
            'success': false,
            'status': 'not_found',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Launches PayMongo checkout URL in external browser
  static Future<bool> launchGCashCheckout(String checkoutUrl) async {
    try {
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        // Use external browser to open PayMongo checkout
        await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error launching PayMongo checkout: $e');
      return false;
    }
  }

  /// Converts PHP amount to cents
  static int phpToCents(double phpAmount) {
    return (phpAmount * 100).round();
  }

  /// Converts cents to PHP amount
  static double centsToPhp(int cents) {
    return cents / 100.0;
  }
}
