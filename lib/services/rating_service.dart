// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a rating for a supplier
  static Future<bool> submitRating({
    required String orderId,
    required String supplierId,
    required int rating,
    String? feedback,
    String? orderNumber,
    String? supplierName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Check if user has already rated this order
      final existingRating = await _firestore
          .collection('order_ratings')
          .where('orderId', isEqualTo: orderId)
          .where('buyerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existingRating.docs.isNotEmpty) {
        throw Exception('You have already rated this order');
      }

      // Save rating to Firestore
      await _firestore.collection('order_ratings').add({
        'orderId': orderId,
        'supplierId': supplierId,
        'buyerId': user.uid,
        'rating': rating,
        'feedback': feedback?.trim(),
        'orderNumber': orderNumber,
        'supplierName': supplierName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update order with rating status
      await _firestore.collection('orders').doc(orderId).update({
        'hasRating': true,
        'rating': rating,
        'ratingTimestamp': FieldValue.serverTimestamp(),
      });

      // Update supplier average rating
      await _updateSupplierRating(supplierId);

      return true;
    } catch (e) {
      print('Error submitting rating: $e');
      return false;
    }
  }

  /// Update supplier's average rating
  static Future<void> _updateSupplierRating(String supplierId) async {
    try {
      // Get all ratings for this supplier
      final ratingsSnapshot = await _firestore
          .collection('order_ratings')
          .where('supplierId', isEqualTo: supplierId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

      // Calculate average rating
      double totalRating = 0;
      int ratingCount = 0;

      for (var doc in ratingsSnapshot.docs) {
        final rating = doc['rating'] as int? ?? 0;
        if (rating > 0) {
          totalRating += rating;
          ratingCount++;
        }
      }

      if (ratingCount > 0) {
        final averageRating = totalRating / ratingCount;

        // Update supplier's average rating
        await _firestore.collection('suppliers').doc(supplierId).update({
          'averageRating': averageRating,
          'ratingCount': ratingCount,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating supplier rating: $e');
    }
  }

  /// Get supplier's average rating
  static Future<Map<String, dynamic>> getSupplierRating(String supplierId) async {
    try {
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      
      if (!supplierDoc.exists) {
        return {
          'averageRating': 0.0,
          'ratingCount': 0,
          'hasRating': false,
        };
      }

      final data = supplierDoc.data()!;
      return {
        'averageRating': data['averageRating'] ?? 0.0,
        'ratingCount': data['ratingCount'] ?? 0,
        'hasRating': (data['ratingCount'] ?? 0) > 0,
      };
    } catch (e) {
      print('Error getting supplier rating: $e');
      return {
        'averageRating': 0.0,
        'ratingCount': 0,
        'hasRating': false,
      };
    }
  }

  /// Check if user has rated a specific order
  static Future<bool> hasUserRatedOrder(String orderId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final ratingDoc = await _firestore
          .collection('order_ratings')
          .where('orderId', isEqualTo: orderId)
          .where('buyerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      return ratingDoc.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if user rated order: $e');
      return false;
    }
  }

  /// Get all ratings for a supplier
  static Future<List<Map<String, dynamic>>> getSupplierRatings(String supplierId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('order_ratings')
          .where('supplierId', isEqualTo: supplierId)
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
      print('Error getting supplier ratings: $e');
      return [];
    }
  }

  /// Get user's rating for a specific order
  static Future<Map<String, dynamic>?> getUserOrderRating(String orderId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final ratingDoc = await _firestore
          .collection('order_ratings')
          .where('orderId', isEqualTo: orderId)
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
      print('Error getting user order rating: $e');
      return null;
    }
  }
} 