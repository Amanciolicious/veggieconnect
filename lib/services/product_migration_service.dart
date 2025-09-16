// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class ProductMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize missing fields in existing products
  /// This ensures all products have the required fields for filtering
  static Future<void> initializeMissingFields() async {
    try {
      print('🔄 Starting product field initialization...');
      
      // Get all products
      final QuerySnapshot allProducts = await _firestore
          .collection('products')
          .get();

      final WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in allProducts.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Map<String, dynamic> updates = {};
        
        // Initialize favoriteCount if missing
        if (!data.containsKey('favoriteCount')) {
          updates['favoriteCount'] = 0;
        }
        
        // Initialize isActive if missing
        if (!data.containsKey('isActive')) {
          updates['isActive'] = true;
        }
        
        // Initialize rating fields if missing
        if (!data.containsKey('rating')) {
          updates['rating'] = 0.0;
        }
        
        if (!data.containsKey('totalRatings')) {
          updates['totalRatings'] = 0;
        }
        
        // Initialize soldCount if missing
        if (!data.containsKey('soldCount')) {
          updates['soldCount'] = 0;
        }
        
        // Initialize Quick Actions fields if missing
        if (!data.containsKey('paymentMethods')) {
          updates['paymentMethods'] = ['cashOnPickup', 'online'];
        }
        
        if (!data.containsKey('isFreshToday')) {
          // Check if product was created today
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final now = DateTime.now();
            final yesterday = now.subtract(const Duration(hours: 24));
            final createdDate = createdAt.toDate();
            updates['isFreshToday'] = createdDate.isAfter(yesterday);
          } else {
            updates['isFreshToday'] = false;
          }
        }
        
        if (!data.containsKey('location')) {
          updates['location'] = 'nearMe';
        }
        
        if (!data.containsKey('isBestDeal')) {
          final price = (data['price'] ?? 0) as num;
          updates['isBestDeal'] = price <= 50.0;
        }
        
        // Only update if there are changes
        if (updates.isNotEmpty) {
          updates['lastFieldUpdate'] = FieldValue.serverTimestamp();
          batch.update(doc.reference, updates);
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('✅ Updated $updateCount products with missing fields');
      } else {
        print('✅ All products already have required fields');
      }
    } catch (e) {
      print('❌ Error initializing product fields: $e');
    }
  }

  /// Fix favoriteCount for products based on actual user favorites
  /// This recalculates the favoriteCount field by counting actual favorites
  static Future<void> recalculateFavoriteCounts() async {
    try {
      print('🔄 Recalculating favorite counts...');
      
      // Get all users with favorites
      final QuerySnapshot users = await _firestore
          .collection('users')
          .where('favorites', isNotEqualTo: null)
          .get();

      // Count favorites for each product
      final Map<String, int> favoriteCounts = {};
      
      for (final userDoc in users.docs) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final favorites = List<String>.from(userData['favorites'] ?? []);
        
        for (final productId in favorites) {
          favoriteCounts[productId] = (favoriteCounts[productId] ?? 0) + 1;
        }
      }

      // Update products with correct favorite counts
      final WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (final entry in favoriteCounts.entries) {
        final productRef = _firestore.collection('products').doc(entry.key);
        batch.update(productRef, {
          'favoriteCount': entry.value,
          'lastFavoriteUpdate': FieldValue.serverTimestamp(),
        });
        updateCount++;
      }

      // Also reset products with no favorites to 0
      final QuerySnapshot allProducts = await _firestore
          .collection('products')
          .get();

      for (final doc in allProducts.docs) {
        if (!favoriteCounts.containsKey(doc.id)) {
          batch.update(doc.reference, {
            'favoriteCount': 0,
            'lastFavoriteUpdate': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('✅ Recalculated favorite counts for $updateCount products');
      }
    } catch (e) {
      print('❌ Error recalculating favorite counts: $e');
    }
  }

  /// Run all migration tasks
  static Future<void> runAllMigrations() async {
    print('🚀 Starting product migrations...');
    await initializeMissingFields();
    await recalculateFavoriteCounts();
    print('🎉 Product migrations completed!');
  }
}
