import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class ClientAutoApprovalService {
  static final ClientAutoApprovalService _instance = ClientAutoApprovalService._internal();
  factory ClientAutoApprovalService() => _instance;
  ClientAutoApprovalService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  Timer? _autoApprovalTimer;
  bool _isRunning = false;

  /// Start the auto-approval service (runs every 30 seconds)
  void startAutoApproval() {
    if (_isRunning) return;
    
    _isRunning = true;
    _autoApprovalTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndAutoApproveProducts();
    });
    
    if (kDebugMode) {
      print('Client auto-approval service started');
    }
  }

  /// Stop the auto-approval service
  void stopAutoApproval() {
    _autoApprovalTimer?.cancel();
    _autoApprovalTimer = null;
    _isRunning = false;
    
    if (kDebugMode) {
      print('Client auto-approval service stopped');
    }
  }

  /// Check for products that need auto-approval
  Future<void> _checkAndAutoApproveProducts() async {
    try {
      final now = Timestamp.now();
      final fiveMinutesAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 5))
      );

      // Query for pending products
      final pendingProducts = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'pending')
          .get();

      if (kDebugMode) {
        print('Found ${pendingProducts.docs.length} pending products to check');
      }

      final batch = _firestore.batch();
      final autoApprovedProducts = <Map<String, dynamic>>[];

      for (final doc in pendingProducts.docs) {
        final productData = doc.data();
        bool shouldAutoApprove = false;

        // Check if product should be auto-approved
        if (productData['autoApprovalScheduledAt'] != null) {
          final scheduledTime = productData['autoApprovalScheduledAt'] as Timestamp;
          if (scheduledTime.compareTo(now) <= 0) {
            shouldAutoApprove = true;
          }
        } else if (productData['createdAt'] != null) {
          final createdTime = productData['createdAt'] as Timestamp;
          if (createdTime.compareTo(fiveMinutesAgo) <= 0) {
            shouldAutoApprove = true;
          }
        }

        if (shouldAutoApprove) {
          // Auto-approve the product
          batch.update(doc.reference, {
            'status': 'approved',
            'isVerified': true,
            'isActive': true,
            'reviewedAt': now,
            'reviewedBy': 'system_auto_approval',
            'rejectionReason': '',
            'autoApproved': true,
            'updatedAt': now,
            'autoApprovalScheduledAt': FieldValue.delete(),
          });

          autoApprovedProducts.add({
            'id': doc.id,
            'name': productData['name'] ?? 'Unknown Product',
            'supplierId': productData['sellerId'] ?? productData['supplierId'],
            'supplierName': productData['supplierName'] ?? 'Unknown Supplier',
          });
        }
      }

      // Commit all updates
      if (autoApprovedProducts.isNotEmpty) {
        await batch.commit();
        
        if (kDebugMode) {
          print('Auto-approved ${autoApprovedProducts.length} products');
        }

        // Send notifications for auto-approved products
        await _sendAutoApprovalNotifications(autoApprovedProducts);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error in client auto-approval: $error');
      }
    }
  }

  /// Send notifications for auto-approved products
  Future<void> _sendAutoApprovalNotifications(List<Map<String, dynamic>> products) async {
    for (final product in products) {
      try {
        // Send notification to supplier
        await _notificationService.sendProductApprovalNotification(
          productId: product['id'],
          productName: product['name'],
          supplierId: product['supplierId'],
          status: 'approved',
          isAutoApproval: true,
        );

        if (kDebugMode) {
          print('Sent auto-approval notification for product: ${product['name']}');
        }
      } catch (error) {
        if (kDebugMode) {
          print('Error sending notification for product ${product['name']}: $error');
        }
      }
    }

    // Send summary to admins if there are auto-approved products
    if (products.isNotEmpty) {
      try {
        await _notificationService.sendAutoApprovalSummaryNotification(products.length);
      } catch (error) {
        if (kDebugMode) {
          print('Error sending admin summary notification: $error');
        }
      }
    }
  }

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Dispose of the service
  void dispose() {
    stopAutoApproval();
  }
}
