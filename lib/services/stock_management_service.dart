// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class StockManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Updates product stock when an order is marked as picked up
  /// Returns true if successful, false otherwise
  static Future<bool> updateStockOnPickup({
    required String productId,
    required int orderQuantity,
    required String orderId,
  }) async {
    try {
      // Get current product data to check available stock
      final productDoc = await _firestore
          .collection('products')
          .doc(productId)
          .get();
      
      if (!productDoc.exists) {
        print('Product not found: $productId');
        return false;
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final currentStock = productData['quantity'] ?? 0;
      
      // Check if there's enough stock
      if (currentStock >= orderQuantity) {
        // Update both soldCount and decrease stock quantity
        await _firestore
            .collection('products')
            .doc(productId)
            .update({
          'soldCount': FieldValue.increment(orderQuantity),
          'quantity': FieldValue.increment(-orderQuantity), // Decrease stock
          'lastSoldAt': FieldValue.serverTimestamp(),
          'lastStockUpdate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(), // Update this field to trigger real-time refresh
        });
        
        print('✅ Stock updated for product $productId: -$orderQuantity units, soldCount: +$orderQuantity');
        return true;
      } else {
        print('⚠️ Insufficient stock for order $orderId. Current: $currentStock, Required: $orderQuantity');
        
        // Still update soldCount but log the discrepancy
        await _firestore
            .collection('products')
            .doc(productId)
            .update({
          'soldCount': FieldValue.increment(orderQuantity),
          'lastSoldAt': FieldValue.serverTimestamp(),
          'stockDiscrepancy': FieldValue.serverTimestamp(), // Flag for admin review
          'updatedAt': FieldValue.serverTimestamp(), // Update this field to trigger real-time refresh
        });
        
        return false; // Return false to indicate stock issue
      }
    } catch (e) {
      print('❌ Failed to update product stock for order $orderId: $e');
      return false;
    }
  }

  /// Restores product stock when an order is cancelled
  /// Only restores if the order was previously picked up
  static Future<bool> restoreStockOnCancellation({
    required String productId,
    required int orderQuantity,
    required String orderId,
    required String originalStatus,
  }) async {
    try {
      // Only restore stock if the order was previously picked up
      if (originalStatus == 'picked_up') {
        await _firestore
            .collection('products')
            .doc(productId)
            .update({
          'quantity': FieldValue.increment(orderQuantity), // Restore stock
          'soldCount': FieldValue.increment(-orderQuantity), // Decrease sold count
          'lastStockUpdate': FieldValue.serverTimestamp(),
          'lastCancellation': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(), // Update this field to trigger real-time refresh
        });
        
        print('✅ Stock restored for product $productId: +$orderQuantity units (order $orderId cancelled)');
        return true;
      } else {
        print('ℹ️ No stock restoration needed for order $orderId (was not picked up)');
        return true; // Not an error, just no action needed
      }
    } catch (e) {
      print('❌ Failed to restore product stock for cancelled order $orderId: $e');
      return false;
    }
  }

  /// Gets real-time stock information for a product
  static Stream<Map<String, dynamic>?> getProductStockStream(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'quantity': data['quantity'] ?? 0,
          'soldCount': data['soldCount'] ?? 0,
          'lastStockUpdate': data['lastStockUpdate'],
          'stockDiscrepancy': data['stockDiscrepancy'],
        };
      }
      return null;
    });
  }

  /// Validates if there's enough stock for an order
  static Future<bool> validateStockAvailability({
    required String productId,
    required int requestedQuantity,
  }) async {
    try {
      final productDoc = await _firestore
          .collection('products')
          .doc(productId)
          .get();
      
      if (!productDoc.exists) {
        return false;
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final availableStock = productData['quantity'] ?? 0;
      
      return availableStock >= requestedQuantity;
    } catch (e) {
      print('❌ Error validating stock availability: $e');
      return false;
    }
  }

  /// Gets products with low stock (less than 10 units)
  static Stream<List<QueryDocumentSnapshot>> getLowStockProductsStream(String supplierId) {
    return _firestore
        .collection('products')
        .where('sellerId', isEqualTo: supplierId)
        .where('status', isEqualTo: 'approved')
        .where('quantity', isLessThan: 10)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Gets products that are out of stock
  static Stream<List<QueryDocumentSnapshot>> getOutOfStockProductsStream(String supplierId) {
    return _firestore
        .collection('products')
        .where('sellerId', isEqualTo: supplierId)
        .where('status', isEqualTo: 'approved')
        .where('quantity', isEqualTo: 0)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Updates stock quantity manually (for supplier stock management)
  static Future<bool> updateStockQuantity({
    required String productId,
    required int newQuantity,
    required String reason,
  }) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .update({
        'quantity': newQuantity,
        'lastStockUpdate': FieldValue.serverTimestamp(),
        'lastStockAdjustment': {
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
      
      print('✅ Stock quantity updated for product $productId: $newQuantity units (Reason: $reason)');
      return true;
    } catch (e) {
      print('❌ Failed to update stock quantity for product $productId: $e');
      return false;
    }
  }
}
