import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierReport {
  final String id;
  final String supplierId;
  final String reporterId;
  final String productId;
  final String reason;
  final DateTime createdAt;
  final String? productName;
  final String? supplierName;
  final String? orderId;

  SupplierReport({
    required this.id,
    required this.supplierId,
    required this.reporterId,
    required this.productId,
    required this.reason,
    required this.createdAt,
    this.productName,
    this.supplierName,
    this.orderId,
  });

  factory SupplierReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupplierReport(
      id: doc.id,
      supplierId: data['supplierId'] ?? '',
      reporterId: data['reporterId'] ?? '',
      productId: data['productId'] ?? '',
      reason: data['reason'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productName: data['productName'],
      supplierName: data['supplierName'],
      orderId: data['orderId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'supplierId': supplierId,
      'reporterId': reporterId,
      'productId': productId,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'productName': productName,
      'supplierName': supplierName,
      'orderId': orderId,
    };
  }
}

class SupplierReportStats {
  final String supplierId;
  final int reportCount;
  final double reportPercentage;

  SupplierReportStats({
    required this.supplierId,
    required this.reportCount,
    required this.reportPercentage,
  });
}
