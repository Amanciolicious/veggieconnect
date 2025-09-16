import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'farm_location_request_service.dart';
import 'notification_service.dart';

class AutoApprovalService {
  static final AutoApprovalService _instance = AutoApprovalService._internal();
  factory AutoApprovalService() => _instance;
  AutoApprovalService._internal();

  final FarmLocationRequestService _requestService = FarmLocationRequestService();
  Timer? _autoApprovalTimer;
  bool _isRunning = false;

  /// Manual admin approval method (called from admin interface)
  Future<void> manualApproveProduct(String productId) async {
    try {
      debugPrint('👨‍💼 Admin manually approving product $productId');
      
      // Get the product data first
      final productDoc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final productData = productDoc.data()!;
      
      // Mark for manual approval processing
      await FirebaseFirestore.instance.collection('products').doc(productId).update({
        'manualApprovalRequested': true,
        'verifiedBy': 'admin',
      });
      
      // Process the manual approval
      await _processManualApproval(productId, productData);
      
      debugPrint('✅ Product $productId successfully manually approved by admin');
      
    } catch (e) {
      debugPrint('💥 Error in manual approval for product $productId: $e');
      throw Exception('Manual approval failed: $e');
    }
  }

  /// Process manual admin approval (bypasses content filtering)
  Future<void> _processManualApproval(String productId, Map<String, dynamic> productData) async {
    try {
      debugPrint('👨‍💼 Processing manual admin approval for product $productId');
      
      await FirebaseFirestore.instance.collection('products').doc(productId).update({
        'status': 'approved',
        'isVerified': true,
        'autoApproved': false, // Not auto-approved, manually approved
        'approvedAt': FieldValue.serverTimestamp(),
        'autoApprovalCompleted': true,
        'autoApprovalFailed': false,
        'approvalMethod': 'manual',
        'verifiedBy': 'admin',
        'verificationDate': FieldValue.serverTimestamp(),
        'manualApprovalRequested': false, // Reset the flag
        'contentFlagged': false, // Clear content flag since admin approved
        'requiresManualReview': false, // Clear manual review flag
      });

      debugPrint('✅ Product $productId manually approved by admin');
      
      // Send notification to supplier
      await _sendApprovalNotification(productData['sellerId'], productData['name']);
      
    } catch (e) {
      debugPrint('💥 Error processing manual approval for product $productId: $e');
      throw Exception('Failed to process manual approval: $e');
    }
  }

  /// Send approval notification to supplier
  Future<void> _sendApprovalNotification(String? supplierId, String productName) async {
    if (supplierId == null) return;

    try {
      final notificationService = NotificationService();
      
      // Send single unified notification (FCM + in-app)
      await notificationService.sendFCMNotification(
        recipientId: supplierId,
        title: 'Product Approved',
        body: 'Your product "$productName" has been approved and is now live',
        type: 'product_approval',
        data: {
          'productName': productName,
          'status': 'approved',
          'screen': 'products',
        },
      );
      
      debugPrint('✅ Product approval notification sent to supplier $supplierId');
    } catch (e) {
      debugPrint('❌ Error sending approval notification: $e');
    }
  }

  /// Get auto-approval statistics (simplified)
  Map<String, dynamic> getAutoApprovalStats() {
    return {
      'pendingApprovalsCount': 0,
      'pendingProductIds': [],
      'approvalDelayMinutes': 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Clean up resources (simplified)
  void dispose() {
    debugPrint('AutoApprovalService disposed');
  }

  // Start the auto-approval service
  void startAutoApprovalService() {
    if (_isRunning) return;

    _isRunning = true;
    
    // Process auto-approvals every 30 seconds
    _autoApprovalTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        await _requestService.processAutoApprovals();
        if (kDebugMode) {
          print('Auto-approval check completed at ${DateTime.now()}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Auto-approval check failed: $e');
        }
      }
    });

    if (kDebugMode) {
      print('Auto-approval service started');
    }
  }

  // Stop the auto-approval service
  void stopAutoApprovalService() {
    _autoApprovalTimer?.cancel();
    _autoApprovalTimer = null;
    _isRunning = false;
    
    if (kDebugMode) {
      print('Auto-approval service stopped');
    }
  }

  // Check if the service is running
  bool get isRunning => _isRunning;

  // Manual trigger for auto-approvals (useful for testing)
  Future<void> triggerAutoApprovals() async {
    try {
      await _requestService.processAutoApprovals();
      if (kDebugMode) {
        print('Manual auto-approval trigger completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Manual auto-approval trigger failed: $e');
      }
      rethrow;
    }
  }
}