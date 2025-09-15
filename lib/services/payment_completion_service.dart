// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_state_service.dart';
import 'notification_service.dart';

class PaymentCompletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final AuthStateService _authService = AuthStateService();

  static AuthUser? get _currentUser => _authService.currentUser;

  static Future<void> completeOrder(String orderId) async {
    print('PaymentCompletionService.completeOrder called with orderId: $orderId');
    
    try {
      if (_currentUser == null) {
        print('No user found, cannot complete order');
        return;
      }

      print('User found: ${_currentUser!.uid}');

      // First check if there's a temporary order that needs to be processed
      final tempOrderDoc = await _firestore
          .collection('temp_orders')
          .doc(orderId)
          .get();

      if (tempOrderDoc.exists) {
        print('Found temporary order, processing...');
        final tempOrderData = tempOrderDoc.data()!;
        
        // Create individual orders for each cart item
        final batch = _firestore.batch();
        final ordersRef = _firestore.collection('orders');

        for (final item in tempOrderData['cartItems']) {
          final orderDoc = ordersRef.doc();
          batch.set(orderDoc, {
            'buyerId': tempOrderData['buyerId'],
            'buyerName': tempOrderData['buyerName'],
            'productId': item['productId'],
            'sellerId': item['sellerId'],
            'productName': item['name'],
            'quantity': item['quantity'],
            'unit': item['unit'],
            'price': item['price'],
            'status': 'completed',
            'createdAt': FieldValue.serverTimestamp(),
            'paymentMethod': _getPaymentMethodDisplayName('online_payment'),
            'paymentStatus': 'completed',
            'paymentAmount': tempOrderData['amount'],
            'originalAmount': tempOrderData['originalAmount'] ?? tempOrderData['amount'],
            'discountAmount': tempOrderData['discountAmount'] ?? 0.0,
            'hasPromoApplied': tempOrderData['hasPromoApplied'] ?? false,
            'promoType': tempOrderData['promoType'],
            'paymentDate': FieldValue.serverTimestamp(),
            'imageUrl': item['imageUrl'],
            'supplierName': item['supplierName'],
            'orderId': orderId,
            'totalAmount': tempOrderData['amount'],
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Commit the batch to create all orders
        await batch.commit();
        print('Created ${tempOrderData['cartItems'].length} orders for orderId: $orderId');

        // Send notifications to suppliers
        await _sendOrderNotificationsToSuppliers(tempOrderData['cartItems'], orderId);

        // Remove items from cart
        if (tempOrderData['cartItems'] != null && tempOrderData['cartItems'] is List) {
          final cartBatch = _firestore.batch();
          
          for (final item in tempOrderData['cartItems']) {
            if (item['cartDocId'] != null) {
              final cartDocRef = _firestore
                  .collection('users')
                  .doc(tempOrderData['buyerId'])
                  .collection('cart')
                  .doc(item['cartDocId']);
              
              cartBatch.delete(cartDocRef);
            }
          }
          
          await cartBatch.commit();
          print('Cart items removed for order $orderId');
        }

        // Delete temporary order
        await _firestore
            .collection('temp_orders')
            .doc(orderId)
            .delete();

        print('Order $orderId completed via temp order processing');
        return;
      }

      // Find all orders with the same orderId
      print('Searching for orders with orderId: $orderId');
      final ordersQuery = await _firestore
          .collection('orders')
          .where('orderId', isEqualTo: orderId)
          .get();

      print('Found ${ordersQuery.docs.length} orders with orderId: $orderId');

      if (ordersQuery.docs.isNotEmpty) {
        // Update all orders with the same orderId to completed
        final batch = _firestore.batch();
        
        for (final orderDoc in ordersQuery.docs) {
          print('Updating order: ${orderDoc.id}');
          batch.update(orderDoc.reference, {
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'paymentStatus': 'completed',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        print('Orders completed: $orderId (${ordersQuery.docs.length} orders)');
        
        // Send notifications to suppliers for existing orders
        await _sendOrderNotificationsForExistingOrders(ordersQuery.docs, orderId);
        
        // Clear cart after successful order completion
        print('Clearing cart for order: $orderId');
        await _clearCartForOrder(orderId, _currentUser!.uid);
      } else {
        print('No orders found with orderId: $orderId');
      }
    } catch (e) {
      print('Error completing order: $e');
    }
  }

  static Future<bool> isOrderCompleted(String orderId) async {
    try {
      final orderDoc = await _firestore
          .collection('orders')
          .doc(orderId)
          .get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data()!;
        return orderData['status'] == 'completed';
      }
      return false;
    } catch (e) {
      print('Error checking order status: $e');
      return false;
    }
  }

  static Future<void> _clearCartForOrder(String orderId, String userId) async {
    try {
      // Get all cart items for the user
      final cartQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .get();

      print('Found ${cartQuery.docs.length} cart items for user $userId');
      
      if (cartQuery.docs.isNotEmpty) {
        // Clear all cart items
        final cartBatch = _firestore.batch();
        
        for (final cartDoc in cartQuery.docs) {
          print('Deleting cart item: ${cartDoc.id}');
          cartBatch.delete(cartDoc.reference);
        }
        
        await cartBatch.commit();
        print('Cart cleared for user $userId (${cartQuery.docs.length} items)');
      } else {
        print('No cart items found for user $userId');
      }
    } catch (e) {
      print('Error clearing cart for order: $e');
    }
  }

  // Debug method to check cart status
  static Future<void> debugCartStatus(String userId) async {
    try {
      final cartQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .get();

      print('=== CART DEBUG INFO ===');
      print('User ID: $userId');
      print('Cart items count: ${cartQuery.docs.length}');
      
      for (final cartDoc in cartQuery.docs) {
        final cartData = cartDoc.data();
        print('Cart item ${cartDoc.id}: ${cartData['name']} x${cartData['quantity']}');
      }
      print('=== END CART DEBUG ===');
    } catch (e) {
      print('Error debugging cart: $e');
    }
  }

  // Convert PayMongo payment method to display name
  static String _getPaymentMethodDisplayName(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
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

  // Send notifications to suppliers for new orders
  static Future<void> _sendOrderNotificationsToSuppliers(List<dynamic> cartItems, String orderId) async {
    try {
      final notificationService = NotificationService();
      final Set<String> notifiedSuppliers = <String>{};
      
      for (final item in cartItems) {
        final sellerId = item['sellerId'] as String?;
        if (sellerId != null && !notifiedSuppliers.contains(sellerId)) {
          notifiedSuppliers.add(sellerId);
          
          await notificationService.sendFCMNotification(
            recipientId: sellerId,
            title: 'New Order Received!',
            body: 'You have a new order #${orderId.substring(0, 8)} from a customer.',
            type: 'order_update',
            data: {
              'orderId': orderId,
              'status': 'pending',
              'screen': 'supplier_orders',
              'action': 'new_order',
            },
          );
          
          print('Notification sent to supplier: $sellerId for order: $orderId');
        }
      }
    } catch (e) {
      print('Error sending notifications to suppliers: $e');
    }
  }

  // Send notifications to suppliers for existing orders
  static Future<void> _sendOrderNotificationsForExistingOrders(List<QueryDocumentSnapshot> orders, String orderId) async {
    try {
      final notificationService = NotificationService();
      final Set<String> notifiedSuppliers = <String>{};
      
      for (final orderDoc in orders) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final sellerId = orderData['sellerId'] as String?;
        
        if (sellerId != null && !notifiedSuppliers.contains(sellerId)) {
          notifiedSuppliers.add(sellerId);
          
          await notificationService.sendFCMNotification(
            recipientId: sellerId,
            title: 'Order Payment Completed!',
            body: 'Payment for order #${orderId.substring(0, 8)} has been completed.',
            type: 'order_update',
            data: {
              'orderId': orderId,
              'status': 'completed',
              'screen': 'supplier_orders',
              'action': 'payment_completed',
            },
          );
          
          print('Payment completion notification sent to supplier: $sellerId for order: $orderId');
        }
      }
    } catch (e) {
      print('Error sending payment completion notifications to suppliers: $e');
    }
  }
}
