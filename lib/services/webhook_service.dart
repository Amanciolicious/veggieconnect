import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_service.dart';

class WebhookService {
  static final WebhookService _instance = WebhookService._internal();
  factory WebhookService() => _instance;
  WebhookService._internal();

  final PaymentService _paymentService = PaymentService();

  // Handle incoming webhook from Paymongo
  Future<Map<String, dynamic>> handleWebhook({
    required String webhookData,
    required String signature,
  }) async {
    try {
      // Verify webhook signature (implement signature verification)
      if (!_verifyWebhookSignature(webhookData, signature)) {
        return {
          'success': false,
          'error': 'Invalid webhook signature',
        };
      }

      final data = jsonDecode(webhookData);
      final eventType = data['type'];
      final eventData = data['data'];

      debugPrint('Processing webhook: $eventType');

      // Process the webhook through payment service
      final result = await _paymentService.handlePaymentWebhook(data);

      if (result['success']) {
        // Log successful webhook processing
        await _logWebhookEvent(eventType, eventData, true);
        
        return {
          'success': true,
          'event_type': eventType,
          'message': 'Webhook processed successfully',
        };
      } else {
        // Log failed webhook processing
        await _logWebhookEvent(eventType, eventData, false, result['error']);
        
        return result;
      }
    } catch (e) {
      debugPrint('Webhook Service Error: $e');
      return {
        'success': false,
        'error': 'Failed to process webhook: $e',
      };
    }
  }

  // Verify webhook signature (implement proper signature verification)
  bool _verifyWebhookSignature(String payload, String signature) {
  
    // For now, we'll accept all webhooks (not recommended for production)
    return true;
  }

  // Log webhook events for debugging and monitoring
  Future<void> _logWebhookEvent(
    String eventType,
    Map<String, dynamic> eventData,
    bool success, [
    String? error,
  ]) async {
    try {
      await FirebaseFirestore.instance.collection('webhook_logs').add({
        'event_type': eventType,
        'event_data': eventData,
        'success': success,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
        'processed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Webhook Log Error: $e');
    }
  }

  // Get webhook logs for debugging
  Stream<List<Map<String, dynamic>>> getWebhookLogs() {
    return FirebaseFirestore.instance
        .collection('webhook_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Manual payment status verification
  Future<Map<String, dynamic>> verifyPaymentStatusWithPaymongo({
    required String sourceId,
    required String orderId,
  }) async {
    try {
      // Debug: Check if payment service method exists
      debugPrint('WebhookService: Calling payment service verifyPaymentStatus');
      debugPrint('WebhookService: sourceId = $sourceId, orderId = $orderId');
      
      // Call the payment service's verifyPaymentStatus method with named parameters
      final result = await _paymentService.verifyPaymentStatus(
        sourceId: sourceId,
        orderId: orderId,
      );

      debugPrint('WebhookService: Payment service result = $result');

      if (result['success']) {
        // Log the manual verification
        await _logWebhookEvent(
          'manual_verification',
          {
            'payment_intent_id': sourceId,
            'order_id': orderId,
            'status': result['status'],
          },
          true,
        );
      }

      return result;
    } catch (e) {
      debugPrint('Manual Verification Error: $e');
      return {
        'success': false,
        'error': 'Failed to verify payment status: $e',
      };
    }
  }

  // Get payment status for an order
  Future<Map<String, dynamic>> getOrderPaymentStatus(String orderId) async {
    try {
      final ordersRef = FirebaseFirestore.instance.collection('orders');
      final querySnapshot = await ordersRef
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final orderData = querySnapshot.docs.first.data();
        return {
          'success': true,
          'order_id': orderId,
          'payment_status': orderData['paymentStatus'] ?? 'unknown',
          'payment_method': orderData['paymentMethod'] ?? 'unknown',
          'payment_verified_at': orderData['paymentVerifiedAt'],
          'last_updated': orderData['lastUpdated'],
        };
      } else {
        return {
          'success': false,
          'error': 'Order not found',
        };
      }
    } catch (e) {
      debugPrint('Get Order Status Error: $e');
      return {
        'success': false,
        'error': 'Failed to get order status: $e',
      };
    }
  }

  // Retry failed webhook processing
  Future<Map<String, dynamic>> retryWebhookProcessing(String webhookLogId) async {
    try {
      final logDoc = await FirebaseFirestore.instance
          .collection('webhook_logs')
          .doc(webhookLogId)
          .get();

      if (!logDoc.exists) {
        return {
          'success': false,
          'error': 'Webhook log not found',
        };
      }

      final logData = logDoc.data()!;
      final eventType = logData['event_type'];
      final eventData = logData['event_data'];

      // Reprocess the webhook
      final result = await _paymentService.handlePaymentWebhook({
        'type': eventType,
        'data': eventData,
      });

      if (result['success']) {
        // Update the log entry
        await FirebaseFirestore.instance
            .collection('webhook_logs')
            .doc(webhookLogId)
            .update({
          'retried_at': FieldValue.serverTimestamp(),
          'retry_success': true,
        });
      }

      return result;
    } catch (e) {
      debugPrint('Retry Webhook Error: $e');
      return {
        'success': false,
        'error': 'Failed to retry webhook processing: $e',
      };
    }
  }

  // Get webhook statistics
  Future<Map<String, dynamic>> getWebhookStatistics() async {
    try {
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('webhook_logs')
          .get();

      int totalWebhooks = 0;
      int successfulWebhooks = 0;
      int failedWebhooks = 0;
      Map<String, int> eventTypeStats = {};

      for (final doc in logsSnapshot.docs) {
        final data = doc.data();
        totalWebhooks++;
        
        if (data['success'] == true) {
          successfulWebhooks++;
        } else {
          failedWebhooks++;
        }

        final eventType = data['event_type'] ?? 'unknown';
        eventTypeStats[eventType] = (eventTypeStats[eventType] ?? 0) + 1;
      }

      return {
        'total_webhooks': totalWebhooks,
        'successful_webhooks': successfulWebhooks,
        'failed_webhooks': failedWebhooks,
        'success_rate': totalWebhooks > 0 ? (successfulWebhooks / totalWebhooks) * 100 : 0,
        'event_type_stats': eventTypeStats,
      };
    } catch (e) {
      debugPrint('Webhook Statistics Error: $e');
      return {
        'error': 'Failed to get webhook statistics: $e',
      };
    }
  }
} 