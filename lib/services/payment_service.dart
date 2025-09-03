import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'paymongo_config.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Payment methods
  static const Map<String, String> _paymentMethods = {
    'cash_on_pickup': 'Cash on Pickup',
    'gcash': 'GCash',
    'paymaya': 'PayMaya',
  };

  // Get available payment methods
  Map<String, String> getPaymentMethods() {
    return Map.from(_paymentMethods);
  }

  // Check if Paymongo is properly configured
  bool get isPaymongoConfigured => PaymongoConfig.isConfigured;

  // Get current environment
  String get environment => PaymongoConfig.environment;

  // Test Paymongo connection
  Future<Map<String, dynamic>> testConnection() async {
    return await testPaymongoConnection();
  }

  // Create payment intent with Paymongo for external browser processing
  Future<Map<String, dynamic>> createExternalPaymentIntent({
    required double amount,
    required String currency,
    required String paymentMethod,
    required String orderId,
    required String customerEmail,
    required String customerName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Check if Paymongo is configured
      if (!PaymongoConfig.isConfigured) {
        debugPrint('Paymongo Configuration Error: ${PaymongoConfig.configurationError}');
        return {
          'success': false,
          'error': 'Payment service not configured. Please use Cash on Pickup.',
          'details': PaymongoConfig.configurationError,
        };
      }

      // Map payment methods to Paymongo payment method types
      String paymongoPaymentMethod;
      switch (paymentMethod) {
        case 'gcash':
          paymongoPaymentMethod = 'gcash';
          break;
        case 'paymaya':
          paymongoPaymentMethod = 'paymaya';
          break;
        default:
          return {
            'success': false,
            'error': 'Unsupported payment method: $paymentMethod',
          };
      }

      debugPrint('Creating external payment intent for $paymentMethod');
      debugPrint('Amount: $amount, Currency: $currency, Order ID: $orderId');

      // Create payment source for external browser redirect
      final sourceResult = await createPaymentSource(
        amount: amount,
        currency: currency,
        paymentMethod: paymongoPaymentMethod,
        orderId: orderId,
        customerEmail: customerEmail,
        customerName: customerName,
        metadata: metadata,
      );

      if (!sourceResult['success']) {
        debugPrint('Payment Source Creation Failed: ${sourceResult['error']}');
        return {
          'success': false,
          'error': 'Failed to create payment source: ${sourceResult['error']}',
          'details': sourceResult['details'] ?? 'Unknown error',
        };
      }

      debugPrint('Payment source created successfully: ${sourceResult['source_id']}');

      return {
        'success': true,
        'payment_method': paymentMethod,
        'payment_status': 'pending',
        'order_id': orderId,
        'redirect_url': sourceResult['redirect_url'],
        'source_id': sourceResult['source_id'],
        'environment': PaymongoConfig.environment,
        'message': 'Redirect to external payment gateway',
      };
    } catch (e) {
      debugPrint('External Payment Error: $e');
      return {
        'success': false,
        'error': 'Failed to create external payment: $e',
        'details': 'Network or API error occurred',
      };
    }
  }

  // Launch external browser for payment
  Future<Map<String, dynamic>> launchExternalPayment({
    required String redirectUrl,
    required String orderId,
    required String paymentMethod,
  }) async {
    try {
      final Uri url = Uri.parse(redirectUrl);
      
      if (await canLaunchUrl(url)) {
        final bool launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          return {
            'success': true,
            'message': 'Payment gateway opened in external browser',
            'order_id': orderId,
            'payment_method': paymentMethod,
            'status': 'redirected',
          };
        } else {
          return {
            'success': false,
            'error': 'Failed to launch payment gateway',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Cannot launch payment gateway URL',
        };
      }
    } catch (e) {
      debugPrint('Launch Payment Error: $e');
      return {
        'success': false,
        'error': 'Failed to launch payment: $e',
      };
    }
  }

  // Create payment source for external browser redirect
  Future<Map<String, dynamic>> createPaymentSource({
    required double amount,
    required String currency,
    required String paymentMethod,
    required String orderId,
    required String customerEmail,
    required String customerName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Creating payment intent for $paymentMethod');
      debugPrint('API URL: ${PaymongoConfig.baseUrl}/payment_intents');
      debugPrint('Secret Key: ${PaymongoConfig.secretKey.substring(0, 10)}...');

      // Step 1: Create payment intent
      final intentUrl = Uri.parse('${PaymongoConfig.baseUrl}/payment_intents');
      
      final intentRequestBody = {
        'data': {
          'attributes': {
            'amount': (amount * 100).round(),
            'currency': currency,
            'payment_method_allowed': [paymentMethod],
            'payment_method_options': {
              paymentMethod: {
                'type': paymentMethod,
              }
            },
            'description': 'Order #$orderId',
            'metadata': {
              'order_id': orderId,
              'payment_method': paymentMethod,
              'environment': PaymongoConfig.environment,
              'customer_email': customerEmail,
              'customer_name': customerName,
              ...?metadata,
            },
          },
        },
      };

      debugPrint('Payment Intent Request Body: ${jsonEncode(intentRequestBody)}');

      final intentResponse = await http.post(
        intentUrl,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(intentRequestBody),
      );

      debugPrint('Payment Intent Response Status: ${intentResponse.statusCode}');
      debugPrint('Payment Intent Response Body: ${intentResponse.body}');

      if (intentResponse.statusCode != 201) {
        debugPrint('Payment Intent Error: ${intentResponse.body}');
        return {
          'success': false,
          'error': 'Failed to create payment intent',
          'details': intentResponse.body,
        };
      }

      final intentData = jsonDecode(intentResponse.body);
      final paymentIntentId = intentData['data']['id'];
      final clientKey = intentData['data']['attributes']['client_key'];

      debugPrint('Payment Intent Created: $paymentIntentId');
      debugPrint('Client Key: $clientKey');

      // Step 2: Create payment method
      final methodUrl = Uri.parse('${PaymongoConfig.baseUrl}/payment_methods');
      
      final methodRequestBody = {
        'data': {
          'attributes': {
            'type': paymentMethod,
            'billing': {
              'name': customerName,
              'email': customerEmail,
            },
            'metadata': {
              'order_id': orderId,
              'payment_method': paymentMethod,
              'environment': PaymongoConfig.environment,
              'customer_email': customerEmail,
              'customer_name': customerName,
              ...?metadata,
            },
          },
        },
      };

      debugPrint('Payment Method Request Body: ${jsonEncode(methodRequestBody)}');

      final methodResponse = await http.post(
        methodUrl,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(methodRequestBody),
      );

      debugPrint('Payment Method Response Status: ${methodResponse.statusCode}');
      debugPrint('Payment Method Response Body: ${methodResponse.body}');

      if (methodResponse.statusCode != 201) {
        debugPrint('Payment Method Error: ${methodResponse.body}');
        return {
          'success': false,
          'error': 'Failed to create payment method',
          'details': methodResponse.body,
        };
      }

      final methodData = jsonDecode(methodResponse.body);
      final paymentMethodId = methodData['data']['id'];

      debugPrint('Payment Method Created: $paymentMethodId');

      // Step 3: Attach payment method to payment intent
      final attachUrl = Uri.parse('${PaymongoConfig.baseUrl}/payment_intents/$paymentIntentId/attach');
      
      final attachRequestBody = {
        'data': {
          'attributes': {
            'payment_method': paymentMethodId,
            'return_url': {
              'success': 'https://vegieconnect.app/payment/success?order_id=$orderId',
              'failed': 'https://vegieconnect.app/payment/failed?order_id=$orderId',
            },
          },
        },
      };

      debugPrint('Attach Request Body: ${jsonEncode(attachRequestBody)}');

      final attachResponse = await http.post(
        attachUrl,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(attachRequestBody),
      );

      debugPrint('Attach Response Status: ${attachResponse.statusCode}');
      debugPrint('Attach Response Body: ${attachResponse.body}');

      if (attachResponse.statusCode != 200) {
        debugPrint('Attach Error: ${attachResponse.body}');
        return {
          'success': false,
          'error': 'Failed to attach payment method',
          'details': attachResponse.body,
        };
      }

      final attachData = jsonDecode(attachResponse.body);
      final status = attachData['data']['attributes']['status'];
      final nextAction = attachData['data']['attributes']['next_action'];

      debugPrint('Payment Status: $status');
      debugPrint('Next Action: $nextAction');

      // For GCash and PayMaya, we need to redirect to the payment gateway
      if (nextAction != null && nextAction['redirect'] != null) {
        return {
          'success': true,
          'payment_intent_id': paymentIntentId,
          'payment_method_id': paymentMethodId,
          'redirect_url': nextAction['redirect']['url'],
          'status': status,
          'environment': PaymongoConfig.environment,
        };
      } else {
        return {
          'success': true,
          'payment_intent_id': paymentIntentId,
          'payment_method_id': paymentMethodId,
          'status': status,
          'environment': PaymongoConfig.environment,
          'message': 'Payment processed successfully',
        };
      }
    } catch (e) {
      debugPrint('Payment Source Error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
        'details': 'Connection or timeout error',
      };
    }
  }

  // Verify payment status from webhook or manual check
  Future<Map<String, dynamic>> verifyPaymentStatus({
    required String sourceId,
    required String orderId,
  }) async {
    try {
      // Use payment_intents endpoint instead of sources
      final url = Uri.parse('${PaymongoConfig.baseUrl}/payment_intents/$sourceId');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['data']['attributes']['status'];
        
        // Update order payment status in Firestore
        await updateOrderPaymentStatus(orderId, status);
        
        return {
          'success': true,
          'status': status,
          'payment_intent_id': sourceId,
          'order_id': orderId,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to verify payment status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Update order payment status in Firestore
  Future<void> updateOrderPaymentStatus(String orderId, String status) async {
    try {
      final ordersRef = FirebaseFirestore.instance.collection('orders');
      final querySnapshot = await ordersRef
          .where('orderId', isEqualTo: orderId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'paymentStatus': status == 'chargeable' ? 'paid' : 'pending',
          'paymentVerifiedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Update Order Status Error: $e');
    }
  }

  // Handle webhook from Paymongo
  Future<Map<String, dynamic>> handlePaymentWebhook(Map<String, dynamic> webhookData) async {
    try {
      final eventType = webhookData['type'];
      final data = webhookData['data'];
      
      switch (eventType) {
        case 'source.chargeable':
          await _handlePaymentSuccess(data);
          break;
        case 'source.failed':
          await _handlePaymentFailure(data);
          break;
        case 'payment.paid':
          await _handlePaymentPaid(data);
          break;
        case 'payment.failed':
          await _handlePaymentFailed(data);
          break;
      }
      
      return {
        'success': true,
        'event_type': eventType,
        'message': 'Webhook processed successfully',
      };
    } catch (e) {
      debugPrint('Webhook Error: $e');
      return {
        'success': false,
        'error': 'Failed to process webhook: $e',
      };
    }
  }

  // Handle successful payment
  Future<void> _handlePaymentSuccess(Map<String, dynamic> data) async {
    final sourceId = data['id'];
    final orderId = data['attributes']['metadata']['order_id'];
    
    await updateOrderPaymentStatus(orderId, 'paid');
  }

  // Handle failed payment
  Future<void> _handlePaymentFailure(Map<String, dynamic> data) async {
    final sourceId = data['id'];
    final orderId = data['attributes']['metadata']['order_id'];
    
    await updateOrderPaymentStatus(orderId, 'failed');
  }

  // Handle payment paid event
  Future<void> _handlePaymentPaid(Map<String, dynamic> data) async {
    final paymentId = data['id'];
    final orderId = data['attributes']['metadata']['order_id'];
    
    await updateOrderPaymentStatus(orderId, 'paid');
  }

  // Handle payment failed event
  Future<void> _handlePaymentFailed(Map<String, dynamic> data) async {
    final paymentId = data['id'];
    final orderId = data['attributes']['metadata']['order_id'];
    
    await updateOrderPaymentStatus(orderId, 'failed');
  }

  // Create payment intent with Paymongo (legacy method for in-app payments)
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    required String paymentMethod,
    required String orderId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Check if Paymongo is configured
      if (!PaymongoConfig.isConfigured) {
        return {
          'success': false,
          'error': PaymongoConfig.configurationError,
        };
      }

      // Map payment methods to Paymongo payment method types
      String paymongoPaymentMethod;
      switch (paymentMethod) {
        case 'gcash':
          paymongoPaymentMethod = 'gcash';
          break;
        case 'paymaya':
          paymongoPaymentMethod = 'paymaya';
          break;
        default:
          return {
            'success': false,
            'error': 'Unsupported payment method: $paymentMethod',
          };
      }

      final url = Uri.parse('${PaymongoConfig.baseUrl}/payment_intents');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'amount': (amount * 100).round(), // Convert to centavos
              'currency': currency,
              'payment_method_allowed': [paymongoPaymentMethod],
              'payment_method_options': {
                paymongoPaymentMethod: {
                  'type': paymongoPaymentMethod,
                }
              },
              'description': 'Order #$orderId',
              'metadata': {
                'order_id': orderId,
                'payment_method': paymentMethod,
                'environment': PaymongoConfig.environment,
                ...?metadata,
              },
            },
          },
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'payment_intent_id': data['data']['id'],
          'client_secret': data['data']['attributes']['client_key'],
          'status': data['data']['attributes']['status'],
          'environment': PaymongoConfig.environment,
        };
      } else {
        debugPrint('Paymongo API Error: ${response.body}');
        
        // Handle specific error cases
        if (response.statusCode == 500) {
          return {
            'success': false,
            'error': 'Payment service temporarily unavailable. Please try Cash on Pickup.',
            'details': 'Paymongo API server error',
          };
        } else if (response.statusCode == 401) {
          return {
            'success': false,
            'error': 'Payment service not configured properly. Please use Cash on Pickup.',
            'details': 'Authentication failed - Check your API keys',
          };
        } else if (response.statusCode == 400) {
          return {
            'success': false,
            'error': 'Invalid payment request. Please try again.',
            'details': response.body,
          };
        } else {
          return {
            'success': false,
            'error': 'Payment service unavailable. Please use Cash on Pickup.',
            'details': response.body,
          };
        }
      }
    } catch (e) {
      debugPrint('Payment Service Error: $e');
      return {
        'success': false,
        'error': 'Payment service unavailable. Please use Cash on Pickup.',
      };
    }
  }

  // Process payment with Paymongo (legacy method)
  Future<Map<String, dynamic>> processPayment({
    required String paymentIntentId,
    required String paymentMethodId,
    required String orderId,
  }) async {
    try {
      final url = Uri.parse('${PaymongoConfig.baseUrl}/payment_intents/$paymentIntentId/attach');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'payment_method': paymentMethodId,
              'return_url': {
                'success': 'https://vegieconnect.app/payment/success',
                'failed': 'https://vegieconnect.app/payment/failed',
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['data']['attributes']['status'];
        
        return {
          'success': status == 'succeeded',
          'status': status,
          'payment_id': data['data']['id'],
          'order_id': orderId,
        };
      } else {
        debugPrint('Paymongo Payment Error: ${response.body}');
        return {
          'success': false,
          'error': 'Payment processing failed',
          'details': response.body,
        };
      }
    } catch (e) {
      debugPrint('Payment Processing Error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Create GCash payment source (legacy method)
  Future<Map<String, dynamic>> createGCashSource({
    required double amount,
    required String currency,
    required String orderId,
  }) async {
    try {
      final url = Uri.parse('${PaymongoConfig.baseUrl}/sources');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'type': 'gcash',
              'amount': (amount * 100).round(),
              'currency': currency,
              'redirect': {
                'success': 'https://vegieconnect.app/payment/success',
                'failed': 'https://vegieconnect.app/payment/failed',
              },
              'billing': {
                'name': 'Customer Name',
                'email': 'customer@example.com',
              },
            },
          },
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'source_id': data['data']['id'],
          'redirect_url': data['data']['attributes']['redirect']['checkout_url'],
          'status': data['data']['attributes']['status'],
        };
      } else {
        debugPrint('GCash Source Error: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to create GCash source',
          'details': response.body,
        };
      }
    } catch (e) {
      debugPrint('GCash Source Error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Process Cash on Pickup payment
  Future<Map<String, dynamic>> processCashOnPickup({
    required String orderId,
    required double amount,
  }) async {
    try {
      // For cash on pickup, we don't need to update existing orders
      // The payment information should already be set during order creation
      // Just return success since the order was already created with cash on pickup
      
      return {
        'success': true,
        'payment_method': 'cash_on_pickup',
        'payment_status': 'pending',
        'order_id': orderId,
      };
    } catch (e) {
      debugPrint('Cash on Pickup Error: $e');
      return {
        'success': false,
        'error': 'Failed to process cash on pickup payment: $e',
      };
    }
  }

  // Verify payment status (legacy method)
  Future<Map<String, dynamic>> verifyPaymentIntentStatus(String paymentIntentId) async {
    try {
      final url = Uri.parse('${PaymongoConfig.baseUrl}/payment_intents/$paymentIntentId');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['data']['attributes']['status'],
          'amount': data['data']['attributes']['amount'],
          'currency': data['data']['attributes']['currency'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to verify payment status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get payment history for user
  Stream<List<Map<String, dynamic>>> getUserPaymentHistory(String userId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Get payment statistics
  Future<Map<String, dynamic>> getPaymentStatistics() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();

      double totalRevenue = 0;
      int totalOrders = 0;
      Map<String, int> paymentMethodStats = {};
      Map<String, double> paymentMethodRevenue = {};

      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final amount = (data['price'] ?? 0) * (data['quantity'] ?? 1);
        final paymentMethod = data['paymentMethod'] ?? 'unknown';
        final paymentStatus = data['paymentStatus'] ?? 'unknown';

        if (paymentStatus == 'completed' || paymentStatus == 'paid') {
          totalRevenue += amount;
          totalOrders++;

          paymentMethodStats[paymentMethod] = 
              (paymentMethodStats[paymentMethod] ?? 0) + 1;
          paymentMethodRevenue[paymentMethod] = 
              (paymentMethodRevenue[paymentMethod] ?? 0) + amount;
        }
      }

      return {
        'total_revenue': totalRevenue,
        'total_orders': totalOrders,
        'average_order_value': totalOrders > 0 ? totalRevenue / totalOrders : 0,
        'payment_method_stats': paymentMethodStats,
        'payment_method_revenue': paymentMethodRevenue,
      };
    } catch (e) {
      debugPrint('Payment Statistics Error: $e');
      return {
        'error': 'Failed to get payment statistics: $e',
      };
    }
  }

  // Refund payment
  Future<Map<String, dynamic>> refundPayment({
    required String paymentIntentId,
    required double amount,
    String? reason,
  }) async {
    try {
      final url = Uri.parse('${PaymongoConfig.baseUrl}/refunds');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'amount': (amount * 100).round(),
              'reason': reason ?? 'Customer request',
              'payment_intent': paymentIntentId,
            },
          },
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'refund_id': data['data']['id'],
          'status': data['data']['attributes']['status'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to process refund',
          'details': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Test Paymongo API connection
  Future<Map<String, dynamic>> testPaymongoConnection() async {
    try {
      debugPrint('Testing Paymongo API connection...');
      debugPrint('Environment: ${PaymongoConfig.environment}');
      debugPrint('Base URL: ${PaymongoConfig.baseUrl}');
      debugPrint('Secret Key: ${PaymongoConfig.secretKey.substring(0, 10)}...');

      if (!PaymongoConfig.isConfigured) {
        return {
          'success': false,
          'error': 'Paymongo not configured',
          'details': PaymongoConfig.configurationError,
        };
      }

      // Test API connection by listing payment intents (simpler test)
      final url = Uri.parse('${PaymongoConfig.baseUrl}/payment_intents');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.secretKey}:'))}',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Test Response Status: ${response.statusCode}');
      debugPrint('Test Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Successfully connected to Paymongo API
        return {
          'success': true,
          'message': 'Paymongo API connection successful',
          'environment': PaymongoConfig.environment,
          'details': 'Test mode - Ready for payment processing',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication failed',
          'details': 'Invalid API credentials - Please check your test secret key',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'error': 'Invalid request',
          'details': 'API request format error: ${response.body}',
        };
      } else {
        return {
          'success': false,
          'error': 'API connection failed',
          'details': 'Status: ${response.statusCode}, Body: ${response.body}',
        };
      }
    } catch (e) {
      debugPrint('Paymongo Connection Test Error: $e');
      return {
        'success': false,
        'error': 'Connection test failed',
        'details': 'Network error: $e',
      };
    }
  }

  // Get payment method display name
  String getPaymentMethodDisplayName(String method) {
    return _paymentMethods[method] ?? method;
  }

  // Check if payment method is online
  bool isOnlinePaymentMethod(String method) {
    return method != 'cash_on_pickup';
  }

  // Check if payment method requires external browser
  bool requiresExternalBrowser(String method) {
    return method == 'gcash' || method == 'paymaya';
  }

  // Get payment method icon
  String getPaymentMethodIcon(String method) {
    switch (method) {
      case 'cash_on_pickup':
        return '💵';
      case 'gcash':
        return '📱';
      case 'paymaya':
        return '💳';
      default:
        return '💰';
    }
  }

  // Process online payment with Paymongo (legacy method)
  Future<Map<String, dynamic>> processOnlinePayment({
    required double amount,
    required String currency,
    required String paymentMethod,
    required String orderId,
    required String customerEmail,
    required String customerName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Check if Paymongo is configured
      if (!PaymongoConfig.isConfigured) {
        return {
          'success': false,
          'error': PaymongoConfig.configurationError,
        };
      }

      // Create payment intent
      final paymentIntent = await createPaymentIntent(
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        orderId: orderId,
        metadata: {
          'customer_email': customerEmail,
          'customer_name': customerName,
          ...?metadata,
        },
      );

      if (!paymentIntent['success']) {
        return paymentIntent;
      }

      // For GCash and PayMaya, we need to create a source and redirect
      if (paymentMethod == 'gcash' || paymentMethod == 'paymaya') {
        final source = await createPaymentSource(
          amount: amount,
          currency: currency,
          paymentMethod: paymentMethod,
          orderId: orderId,
          customerEmail: customerEmail,
          customerName: customerName,
        );

        if (source['success']) {
          return {
            'success': true,
            'payment_method': paymentMethod,
            'payment_status': 'pending',
            'order_id': orderId,
            'redirect_url': source['redirect_url'],
            'source_id': source['source_id'],
            'environment': PaymongoConfig.environment,
            'message': 'Redirect to payment gateway',
          };
        } else {
          return source;
        }
      }

      // For other payment methods, return the payment intent
      return {
        'success': true,
        'payment_method': paymentMethod,
        'payment_status': 'pending',
        'order_id': orderId,
        'payment_intent_id': paymentIntent['payment_intent_id'],
        'client_secret': paymentIntent['client_secret'],
        'environment': PaymongoConfig.environment,
        'message': 'Payment intent created successfully',
      };
    } catch (e) {
      debugPrint('Online Payment Error: $e');
      return {
        'success': false,
        'error': 'Failed to process online payment: $e',
      };
    }
  }
}

// Payment method model
class PaymentMethod {
  final String id;
  final String name;
  final String icon;
  final bool isOnline;
  final String description;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.isOnline,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isOnline': isOnline,
      'description': description,
    };
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      isOnline: json['isOnline'] ?? false,
      description: json['description'],
    );
  }
}

// Payment result model
class PaymentResult {
  final bool success;
  final String? error;
  final String? paymentId;
  final String? orderId;
  final String? status;
  final double? amount;
  final String? currency;

  PaymentResult({
    required this.success,
    this.error,
    this.paymentId,
    this.orderId,
    this.status,
    this.amount,
    this.currency,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'error': error,
      'paymentId': paymentId,
      'orderId': orderId,
      'status': status,
      'amount': amount,
      'currency': currency,
    };
  }

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      success: json['success'] ?? false,
      error: json['error'],
      paymentId: json['paymentId'],
      orderId: json['orderId'],
      status: json['status'],
      amount: json['amount']?.toDouble(),
      currency: json['currency'],
    );
  }
} 