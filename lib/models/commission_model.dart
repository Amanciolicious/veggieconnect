import 'package:cloud_firestore/cloud_firestore.dart';

class CommissionCalculation {
  final double grossAmount;
  final double commissionRate;
  final double commissionAmount;
  final double netAmount;

  CommissionCalculation({
    required this.grossAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.netAmount,
  });

  factory CommissionCalculation.calculate(double grossAmount, {double rate = 0.05}) {
    final commissionAmount = grossAmount * rate;
    final netAmount = grossAmount - commissionAmount;
    
    return CommissionCalculation(
      grossAmount: grossAmount,
      commissionRate: rate,
      commissionAmount: commissionAmount,
      netAmount: netAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'grossAmount': grossAmount,
      'commissionRate': commissionRate,
      'commissionAmount': commissionAmount,
      'netAmount': netAmount,
    };
  }
}

class CommissionEarnings {
  final String id;
  final String orderId;
  final String supplierId;
  final double grossAmount;
  final double commissionAmount;
  final double netAmount;
  final double commissionRate;
  final DateTime createdAt;

  CommissionEarnings({
    required this.id,
    required this.orderId,
    required this.supplierId,
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.commissionRate,
    required this.createdAt,
  });

  factory CommissionEarnings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommissionEarnings(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      supplierId: data['supplierId'] ?? '',
      grossAmount: (data['grossAmount'] ?? 0.0).toDouble(),
      commissionAmount: (data['commissionAmount'] ?? 0.0).toDouble(),
      netAmount: (data['netAmount'] ?? 0.0).toDouble(),
      commissionRate: (data['commissionRate'] ?? 0.05).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'supplierId': supplierId,
      'grossAmount': grossAmount,
      'commissionAmount': commissionAmount,
      'netAmount': netAmount,
      'commissionRate': commissionRate,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
