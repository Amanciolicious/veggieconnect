import 'package:cloud_firestore/cloud_firestore.dart';

class TaxService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _taxRecordsCollection = 'tax_records';
  static const double _fixedTaxAmount = 5.0; // ₱5 fixed tax per product listing

  /// Calculate the net price after deducting tax
  static double calculateNetPrice(double originalPrice) {
    return originalPrice - _fixedTaxAmount;
  }

  /// Get the fixed tax amount
  static double getTaxAmount() => _fixedTaxAmount;

  /// Record tax deduction when a product is listed
  static Future<void> recordTaxDeduction({
    required String productId,
    required String supplierId,
    required double originalPrice,
    required double netPrice,
  }) async {
    try {
      await _firestore.collection(_taxRecordsCollection).add({
        'productId': productId,
        'supplierId': supplierId,
        'originalPrice': originalPrice,
        'taxAmount': _fixedTaxAmount,
        'netPrice': netPrice,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to record tax deduction: $e');
    }
  }

  /// Get total tax collected for admin dashboard
  static Future<double> getTotalTaxCollected() async {
    try {
      final querySnapshot = await _firestore.collection(_taxRecordsCollection).get();
      double total = 0.0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        total += (data['taxAmount'] ?? 0.0).toDouble();
      }
      
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get tax records for a specific supplier
  static Future<double> getSupplierTotalTax(String supplierId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_taxRecordsCollection)
          .where('supplierId', isEqualTo: supplierId)
          .get();
      
      double total = 0.0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        total += (data['taxAmount'] ?? 0.0).toDouble();
      }
      
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  /// Format currency for display
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  /// Validate if price is sufficient for tax deduction
  static bool isValidPriceForTax(double price) {
    return price > _fixedTaxAmount;
  }

  /// Get minimum required price (tax amount + minimum profit margin)
  static double getMinimumRequiredPrice() {
    return _fixedTaxAmount + 1.0; // ₱5 tax + ₱1 minimum profit
  }
}
