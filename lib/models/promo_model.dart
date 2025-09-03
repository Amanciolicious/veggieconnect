import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerPromo {
  final String customerId;
  final bool hasUsedFirstTimePromo;
  final DateTime? firstTimePromoUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerPromo({
    required this.customerId,
    required this.hasUsedFirstTimePromo,
    this.firstTimePromoUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerPromo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomerPromo(
      customerId: doc.id,
      hasUsedFirstTimePromo: data['hasUsedFirstTimePromo'] ?? false,
      firstTimePromoUsedAt: data['firstTimePromoUsedAt']?.toDate(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hasUsedFirstTimePromo': hasUsedFirstTimePromo,
      'firstTimePromoUsedAt': firstTimePromoUsedAt,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CustomerPromo copyWith({
    String? customerId,
    bool? hasUsedFirstTimePromo,
    DateTime? firstTimePromoUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerPromo(
      customerId: customerId ?? this.customerId,
      hasUsedFirstTimePromo: hasUsedFirstTimePromo ?? this.hasUsedFirstTimePromo,
      firstTimePromoUsedAt: firstTimePromoUsedAt ?? this.firstTimePromoUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PromoDiscount {
  final double originalAmount;
  final double discountPercentage;
  final double discountAmount;
  final double finalAmount;
  final String promoType;

  PromoDiscount({
    required this.originalAmount,
    required this.discountPercentage,
    required this.discountAmount,
    required this.finalAmount,
    required this.promoType,
  });

  factory PromoDiscount.calculate({
    required double originalAmount,
    required double discountPercentage,
    required String promoType,
  }) {
    final discountAmount = originalAmount * (discountPercentage / 100);
    final finalAmount = originalAmount - discountAmount;
    
    return PromoDiscount(
      originalAmount: originalAmount,
      discountPercentage: discountPercentage,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      promoType: promoType,
    );
  }
}
