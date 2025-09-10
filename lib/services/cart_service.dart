import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartService {
  static Future<void> clearCart(List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Clear cart from Firestore
      final cartBatch = FirebaseFirestore.instance.batch();
      for (final doc in cartItems) {
        cartBatch.delete(FirebaseFirestore.instance
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get all orders with the same orderId
      final ordersQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: orderId)
          .get();

      if (ordersQuery.docs.isNotEmpty) {
        // Clear all cart items for this user
        final cartBatch = FirebaseFirestore.instance.batch();
        final cartQuery = await FirebaseFirestore.instance
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
