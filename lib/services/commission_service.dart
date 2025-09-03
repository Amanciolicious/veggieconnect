import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/commission_model.dart';

class CommissionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _commissionsCollection = 'commission_earnings';
  static const double _defaultCommissionRate = 0.05; // 5%

  /// Calculate commission for a given amount
  static CommissionCalculation calculateCommission(double grossAmount, {double? customRate}) {
    return CommissionCalculation.calculate(
      grossAmount,
      rate: customRate ?? _defaultCommissionRate,
    );
  }

  /// Store commission earnings in Firestore
  static Future<void> recordCommissionEarnings({
    required String orderId,
    required String supplierId,
    required double grossAmount,
    double? customRate,
  }) async {
    try {
      final calculation = calculateCommission(grossAmount, customRate: customRate);
      
      final commissionEarnings = CommissionEarnings(
        id: '',
        orderId: orderId,
        supplierId: supplierId,
        grossAmount: calculation.grossAmount,
        commissionAmount: calculation.commissionAmount,
        netAmount: calculation.netAmount,
        commissionRate: calculation.commissionRate,
        createdAt: DateTime.now(),
      );

      await _firestore.collection(_commissionsCollection).add(commissionEarnings.toFirestore());
    } catch (e) {
      throw Exception('Failed to record commission earnings: $e');
    }
  }

  /// Get total commission earnings for admin dashboard
  static Future<double> getTotalCommissionEarnings() async {
    try {
      final querySnapshot = await _firestore.collection(_commissionsCollection).get();
      double total = 0.0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        total += (data['commissionAmount'] ?? 0.0).toDouble();
      }
      
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get total gross sales for admin dashboard
  static Future<double> getTotalGrossSales() async {
    try {
      final querySnapshot = await _firestore.collection(_commissionsCollection).get();
      double total = 0.0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        total += (data['grossAmount'] ?? 0.0).toDouble();
      }
      
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get total net payouts to suppliers for admin dashboard
  static Future<double> getTotalNetPayouts() async {
    try {
      final querySnapshot = await _firestore.collection(_commissionsCollection).get();
      double total = 0.0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        total += (data['netAmount'] ?? 0.0).toDouble();
      }
      
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get commission earnings for a specific supplier
  static Future<double> getSupplierNetEarnings(String supplierId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_commissionsCollection)
          .where('supplierId', isEqualTo: supplierId)
          .get();
      
      double total = 0.0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        total += (data['netAmount'] ?? 0.0).toDouble();
      }
      
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get commission earnings stream for real-time updates
  static Stream<List<CommissionEarnings>> getCommissionEarningsStream() {
    return _firestore
        .collection(_commissionsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommissionEarnings.fromFirestore(doc))
            .toList());
  }

  /// Get supplier commission earnings stream
  static Stream<List<CommissionEarnings>> getSupplierCommissionStream(String supplierId) {
    return _firestore
        .collection(_commissionsCollection)
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommissionEarnings.fromFirestore(doc))
            .toList());
  }

  /// Get commission rate
  static double getCommissionRate() => _defaultCommissionRate;

  /// Format currency for display
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }
}
