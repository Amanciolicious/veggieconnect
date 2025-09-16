// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class FreshProductsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Updates all products' isFreshToday field based on creation date
  /// Products created within the last 24 hours are marked as fresh
  static Future<void> updateFreshTodayStatus() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      
      // Get all products
      final QuerySnapshot allProducts = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .get();

      final WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in allProducts.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;
        
        if (createdAt != null) {
          final createdDate = createdAt.toDate();
          final isFresh = createdDate.isAfter(yesterday);
          
          // Only update if the value has changed
          if (data['isFreshToday'] != isFresh) {
            batch.update(doc.reference, {
              'isFreshToday': isFresh,
              'lastFreshUpdate': FieldValue.serverTimestamp(),
            });
            updateCount++;
          }
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('✅ Updated $updateCount products\' fresh status');
      }
    } catch (e) {
      print('❌ Error updating fresh products: $e');
    }
  }

  /// Get count of fresh products for real-time badge display
  static Stream<int> getFreshProductsCountStream() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .where('isFreshToday', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get count of best deal products for real-time badge display
  static Stream<int> getBestDealsCountStream() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .where('isBestDeal', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get count of top rated products for real-time badge display
  static Stream<int> getTopRatedCountStream() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .where('rating', isGreaterThanOrEqualTo: 4.5)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get count of cash on pickup products for real-time badge display
  static Stream<int> getCashOnPickupCountStream() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .where('paymentMethods', arrayContains: 'cashOnPickup')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get count of nearby products for real-time badge display
  static Stream<int> getNearMeCountStream() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .where('location', isEqualTo: 'nearMe')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Initialize fresh products service - call this on app startup
  static Future<void> initialize() async {
    // Update fresh status immediately
    await updateFreshTodayStatus();
    
    // Set up periodic updates (every hour)
    // Note: In production, this should be handled by Firebase Cloud Functions
    // or a background service for better performance
    print('🌱 Fresh Products Service initialized');
  }
}
