// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class ProductRatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a rating for a specific product
  static Future<bool> submitProductRating({
    required String productId,
    required String supplierId,
    required int rating,
    String? feedback,
    String? productName,
    String? supplierName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Check if user has already rated this product
      final existingRating = await _firestore
          .collection('product_ratings')
          .where('productId', isEqualTo: productId)
          .where('buyerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existingRating.docs.isNotEmpty) {
        throw Exception('You have already rated this product');
      }

      // Save rating to Firestore
      await _firestore.collection('product_ratings').add({
        'productId': productId,
        'supplierId': supplierId,
        'buyerId': user.uid,
        'buyerName': user.displayName ?? 'Customer',
        'rating': rating,
        'feedback': feedback?.trim(),
        'productName': productName,
        'supplierName': supplierName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update product with average rating
      await _updateProductRating(productId);

      // Send notification to supplier about new rating
      await _sendProductRatingNotification(productId, supplierId, rating, productName, supplierName);

      return true;
    } catch (e) {
      print('Error submitting product rating: $e');
      return false;
    }
  }

  /// Get all ratings for a specific product
  static Future<List<Map<String, dynamic>>> getProductRatings(String productId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('product_ratings')
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: true)
          .get();

      return ratingsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'timestamp': data['timestamp']?.toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting product ratings: $e');
      return [];
    }
  }

  /// Get product rating statistics
  static Future<Map<String, dynamic>> getProductRatingStats(String productId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('product_ratings')
          .where('productId', isEqualTo: productId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
          'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        };
      }

      final ratings = ratingsSnapshot.docs.map((doc) => doc['rating'] as int).toList();
      final totalRatings = ratings.length;
      final averageRating = ratings.reduce((a, b) => a + b) / totalRatings;

      // Calculate rating distribution
      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final rating in ratings) {
        if (rating >= 1 && rating <= 5) {
          distribution[rating] = (distribution[rating] ?? 0) + 1;
        }
      }

      return {
        'averageRating': averageRating,
        'totalRatings': totalRatings,
        'ratingDistribution': distribution,
      };
    } catch (e) {
      print('Error getting product rating stats: $e');
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
        'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }
  }

  /// Update product with average rating
  static Future<void> _updateProductRating(String productId) async {
    try {
      final stats = await getProductRatingStats(productId);
      
      await _firestore.collection('products').doc(productId).update({
        'averageRating': stats['averageRating'],
        'totalRatings': stats['totalRatings'],
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product rating: $e');
    }
  }

  /// Send notification to supplier about new product rating
  static Future<void> _sendProductRatingNotification(
    String productId,
    String supplierId,
    int rating,
    String? productName,
    String? supplierName,
  ) async {
    try {
      final notificationService = NotificationService();
      notificationService.sendRatingNotification(
        orderId: productId, // Using productId as orderId for product ratings
        customerName: _auth.currentUser?.displayName ?? 'Customer',
        rating: rating,
        supplierId: supplierId,
      );
    } catch (e) {
      print('Error sending product rating notification: $e');
    }
  }

  /// Get user's rating for a specific product
  static Future<Map<String, dynamic>?> getUserProductRating(String productId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final ratingDoc = await _firestore
          .collection('product_ratings')
          .where('productId', isEqualTo: productId)
          .where('buyerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (ratingDoc.docs.isEmpty) return null;

      final data = ratingDoc.docs.first.data();
      return {
        'id': ratingDoc.docs.first.id,
        ...data,
        'timestamp': data['timestamp']?.toDate(),
      };
    } catch (e) {
      print('Error getting user product rating: $e');
      return null;
    }
  }

  /// Update existing product rating
  static Future<bool> updateProductRating({
    required String ratingId,
    required int rating,
    String? feedback,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get the rating document to find productId
      final ratingDoc = await _firestore.collection('product_ratings').doc(ratingId).get();
      if (!ratingDoc.exists) {
        throw Exception('Rating not found');
      }

      final data = ratingDoc.data()!;
      if (data['buyerId'] != user.uid) {
        throw Exception('You can only update your own ratings');
      }

      // Update the rating
      await _firestore.collection('product_ratings').doc(ratingId).update({
        'rating': rating,
        'feedback': feedback?.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update product with new average rating
      await _updateProductRating(data['productId']);

      return true;
    } catch (e) {
      print('Error updating product rating: $e');
      return false;
    }
  }

  /// Delete product rating
  static Future<bool> deleteProductRating(String ratingId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get the rating document to find productId
      final ratingDoc = await _firestore.collection('product_ratings').doc(ratingId).get();
      if (!ratingDoc.exists) {
        throw Exception('Rating not found');
      }

      final data = ratingDoc.data()!;
      if (data['buyerId'] != user.uid) {
        throw Exception('You can only delete your own ratings');
      }

      // Delete the rating
      await _firestore.collection('product_ratings').doc(ratingId).delete();

      // Update product with new average rating
      await _updateProductRating(data['productId']);

      return true;
    } catch (e) {
      print('Error deleting product rating: $e');
      return false;
    }
  }

  /// Initialize product rating fields when a product is created
  static Future<void> initializeProductRating(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'averageRating': 0.0,
        'totalRatings': 0,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error initializing product rating: $e');
    }
  }

  /// Get product rating stream for real-time updates
  static Stream<Map<String, dynamic>> getProductRatingStream(String productId) {
    return _firestore
        .collection('product_ratings')
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
          'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        };
      }

      final ratings = snapshot.docs.map((doc) => doc['rating'] as int).toList();
      final totalRatings = ratings.length;
      final averageRating = ratings.reduce((a, b) => a + b) / totalRatings;

      // Calculate rating distribution
      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final rating in ratings) {
        if (rating >= 1 && rating <= 5) {
          distribution[rating] = (distribution[rating] ?? 0) + 1;
        }
      }

      return {
        'averageRating': averageRating,
        'totalRatings': totalRatings,
        'ratingDistribution': distribution,
      };
    });
  }
}
