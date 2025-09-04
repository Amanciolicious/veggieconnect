import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promo_model.dart';

class PromoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'customer_promos';
  static const double _firstTimeDiscountPercentage = 40.0;

  /// Initialize promo tracking for new customer
  static Future<void> initializeCustomerPromo(String customerId) async {
    try {
      final promoDoc = await _firestore.collection(_collection).doc(customerId).get();
      
      if (!promoDoc.exists) {
        final customerPromo = CustomerPromo(
          customerId: customerId,
          hasUsedFirstTimePromo: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _firestore.collection(_collection).doc(customerId).set(customerPromo.toFirestore());
      }
    } catch (e) {
      throw Exception('Failed to initialize customer promo: $e');
    }
  }

  /// Check if customer has available first-time promo
  static Future<bool> hasAvailableFirstTimePromo(String customerId) async {
    try {
      final promoDoc = await _firestore.collection(_collection).doc(customerId).get();
      
      if (!promoDoc.exists) {
        // Initialize promo for customer if not exists
        await initializeCustomerPromo(customerId);
        return true;
      }
      
      final customerPromo = CustomerPromo.fromFirestore(promoDoc);
      return !customerPromo.hasUsedFirstTimePromo;
    } catch (e) {
      return false;
    }
  }

  /// Get customer promo details
  static Future<CustomerPromo?> getCustomerPromo(String customerId) async {
    try {
      final promoDoc = await _firestore.collection(_collection).doc(customerId).get();
      
      if (!promoDoc.exists) {
        await initializeCustomerPromo(customerId);
        // Return the newly created promo
        final newPromoDoc = await _firestore.collection(_collection).doc(customerId).get();
        return CustomerPromo.fromFirestore(newPromoDoc);
      }
      
      return CustomerPromo.fromFirestore(promoDoc);
    } catch (e) {
      print('Error getting customer promo: $e');
      return null;
    }
  }

  /// Calculate discount for order
  static PromoDiscount? calculateFirstTimeDiscount(double originalAmount, bool hasAvailablePromo) {
    if (!hasAvailablePromo || originalAmount <= 0) {
      return null;
    }
    
    return PromoDiscount.calculate(
      originalAmount: originalAmount,
      discountPercentage: _firstTimeDiscountPercentage,
      promoType: 'First Time Customer',
    );
  }

  /// Mark first-time promo as used
  static Future<void> markFirstTimePromoAsUsed(String customerId) async {
    try {
      // First ensure the customer promo document exists
      await initializeCustomerPromo(customerId);
      
      // Then mark it as used
      await _firestore.collection(_collection).doc(customerId).update({
        'hasUsedFirstTimePromo': true,
        'firstTimePromoUsedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Successfully marked first-time promo as used for customer: $customerId');
    } catch (e) {
      print('Failed to mark promo as used: $e');
      throw Exception('Failed to mark promo as used: $e');
    }
  }

  /// Check if customer has ever used the first-time promo
  static Future<bool> hasUsedFirstTimePromo(String customerId) async {
    try {
      final promoDoc = await _firestore.collection(_collection).doc(customerId).get();
      
      if (!promoDoc.exists) {
        return false; // No promo document means never used
      }
      
      final customerPromo = CustomerPromo.fromFirestore(promoDoc);
      return customerPromo.hasUsedFirstTimePromo;
    } catch (e) {
      print('Error checking if promo was used: $e');
      return false;
    }
  }

  /// Get promo statistics for admin
  static Future<Map<String, dynamic>> getPromoStatistics() async {
    try {
      final promoSnapshot = await _firestore.collection(_collection).get();
      
      int totalCustomers = promoSnapshot.docs.length;
      int usedPromos = 0;
      int availablePromos = 0;
      
      for (var doc in promoSnapshot.docs) {
        final data = doc.data();
        if (data['hasUsedFirstTimePromo'] == true) {
          usedPromos++;
        } else {
          availablePromos++;
        }
      }
      
      return {
        'totalCustomers': totalCustomers,
        'usedPromos': usedPromos,
        'availablePromos': availablePromos,
        'usagePercentage': totalCustomers > 0 ? (usedPromos / totalCustomers * 100) : 0,
      };
    } catch (e) {
      return {
        'totalCustomers': 0,
        'usedPromos': 0,
        'availablePromos': 0,
        'usagePercentage': 0,
      };
    }
  }

  /// Stream of customer promo status
  static Stream<CustomerPromo?> streamCustomerPromo(String customerId) {
    return _firestore.collection(_collection).doc(customerId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return CustomerPromo.fromFirestore(doc);
    });
  }
}
