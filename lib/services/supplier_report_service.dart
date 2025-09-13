import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier_report_model.dart';
import 'notification_service.dart';

class SupplierReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'supplier_reports';

  /// Submit a report for a supplier
  static Future<void> submitReport({
    required String supplierId,
    required String reporterId,
    required String productId,
    required String reason,
    String? productName,
    String? supplierName,
    String? orderId,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'supplierId': supplierId,
        'reporterId': reporterId,
        'productId': productId,
        'reason': reason,
        'productName': productName,
        'supplierName': supplierName,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Get report count for a specific supplier
  static Future<int> getSupplierReportCount(String supplierId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('supplierId', isEqualTo: supplierId)
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get report statistics for a supplier
  static Future<SupplierReportStats> getSupplierReportStats(String supplierId) async {
    try {
      final reportCount = await getSupplierReportCount(supplierId);
      // Calculate percentage based on max of 3 reports (100% intensity)
      final percentage = (reportCount / 3.0 * 100).clamp(0.0, 100.0);
      
      return SupplierReportStats(
        supplierId: supplierId,
        reportCount: reportCount,
        reportPercentage: percentage,
      );
    } catch (e) {
      return SupplierReportStats(
        supplierId: supplierId,
        reportCount: 0,
        reportPercentage: 0.0,
      );
    }
  }

  /// Get all reports for admin management
  static Stream<List<SupplierReport>> getAllReports() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupplierReport.fromFirestore(doc))
            .toList());
  }

  /// Get reports for a specific supplier
  static Stream<List<SupplierReport>> getSupplierReports(String supplierId) {
    return _firestore
        .collection(_collection)
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupplierReport.fromFirestore(doc))
            .toList());
  }

  /// Delete a report (admin only)
  static Future<void> deleteReport(String reportId) async {
    try {
      await _firestore.collection(_collection).doc(reportId).delete();
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }

  /// Get color intensity based on report count (for admin UI)
  static double getReportColorIntensity(int reportCount) {
    // Returns a value between 0.2 and 1.0 based on report count
    // 0 reports = 0.2 (very light), 3+ reports = 1.0 (full intensity)
    return (0.2 + (reportCount / 3.0 * 0.8)).clamp(0.2, 1.0);
  }
}
