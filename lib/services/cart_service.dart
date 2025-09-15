// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_state_service.dart';

class CartService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final AuthStateService _authService = AuthStateService();

  static AuthUser? get _currentUser => _authService.currentUser;

  static Future<void> clearCart(List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems) async {
    try {
      final user = _currentUser;
      if (user == null) return;

      // Clear cart from Firestore
      final cartBatch = _firestore.batch();
      for (final doc in cartItems) {
        cartBatch.delete(_firestore
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(doc.id));
      }

      await cartBatch.commit();
      print('Cart cleared successfully for user: ${user.uid}');
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }

  static Future<void> clearCartByOrderId(String orderId) async {
    try {
      final user = _currentUser;
      if (user == null) return;

      // Get all orders with the same orderId
      final ordersQuery = await _firestore
          .collection('orders')
          .where('orderId', isEqualTo: orderId)
          .get();

      if (ordersQuery.docs.isNotEmpty) {
        // Clear all cart items for this user
        final cartBatch = _firestore.batch();
        final cartQuery = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .get();

        for (final cartDoc in cartQuery.docs) {
          cartBatch.delete(cartDoc.reference);
        }

        await cartBatch.commit();
        print('Cart cleared for order: $orderId (${cartQuery.docs.length} items)');
      }
    } catch (e) {
      print('Error clearing cart by order ID: $e');
    }
  }
}
