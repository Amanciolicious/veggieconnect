import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_state_service.dart';

class RevenueService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final AuthStateService _authService = AuthStateService();

  static AuthUser? get _currentUser => _authService.currentUser;

  /// Get real-time stream of total revenue across all picked up orders (Admin view)
  static Stream<double> getTotalRevenueStream() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'picked_up')
        .snapshots()
        .map((snapshot) {
      double totalRevenue = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalRevenue += (data['totalPrice'] ?? 0).toDouble();
      }
      return totalRevenue;
    });
  }

  /// Get real-time stream of revenue for a specific supplier
  static Stream<double> getSupplierRevenueStream(String supplierId) {
    return _firestore
        .collection('orders')
        .where('sellerId', isEqualTo: supplierId)
        .where('status', isEqualTo: 'picked_up')
        .snapshots()
        .map((snapshot) {
      double supplierRevenue = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        supplierRevenue += (data['totalPrice'] ?? 0).toDouble();
      }
      return supplierRevenue;
    });
  }

  /// Get real-time stream of current user's revenue (for logged-in supplier)
  static Stream<double> getCurrentUserRevenueStream() {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return Stream.value(0.0);
    }
    return getSupplierRevenueStream(currentUser.uid);
  }

  /// Get real-time stream of revenue analytics for admin dashboard
  static Stream<Map<String, double>> getRevenueAnalyticsStream() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'picked_up')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final firstDayThisMonth = DateTime(now.year, now.month, 1);
      final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
      final firstDayThisYear = DateTime(now.year, 1, 1);
      final firstDayLastYear = DateTime(now.year - 1, 1, 1);

      double totalRevenue = 0.0;
      double thisMonthRevenue = 0.0;
      double lastMonthRevenue = 0.0;
      double thisYearRevenue = 0.0;
      double lastYearRevenue = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['totalPrice'] ?? 0).toDouble();
        
        totalRevenue += amount;
        
        if (createdAt != null) {
          if (createdAt.isAfter(firstDayThisMonth)) {
            thisMonthRevenue += amount;
          }
          if (createdAt.isAfter(firstDayLastMonth) && createdAt.isBefore(firstDayThisMonth)) {
            lastMonthRevenue += amount;
          }
          if (createdAt.isAfter(firstDayThisYear)) {
            thisYearRevenue += amount;
          }
          if (createdAt.isAfter(firstDayLastYear) && createdAt.isBefore(firstDayThisYear)) {
            lastYearRevenue += amount;
          }
        }
      }

      return {
        'total': totalRevenue,
        'thisMonth': thisMonthRevenue,
        'lastMonth': lastMonthRevenue,
        'thisYear': thisYearRevenue,
        'lastYear': lastYearRevenue,
        'monthlyGrowth': lastMonthRevenue > 0 
            ? ((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100 
            : 0.0,
        'yearlyGrowth': lastYearRevenue > 0 
            ? ((thisYearRevenue - lastYearRevenue) / lastYearRevenue) * 100 
            : 0.0,
      };
    });
  }

  /// Get real-time stream of supplier-specific revenue analytics
  static Stream<Map<String, double>> getSupplierRevenueAnalyticsStream(String supplierId) {
    return _firestore
        .collection('orders')
        .where('sellerId', isEqualTo: supplierId)
        .where('status', isEqualTo: 'picked_up')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final firstDayThisMonth = DateTime(now.year, now.month, 1);
      final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
      final firstDayThisYear = DateTime(now.year, 1, 1);

      double totalRevenue = 0.0;
      double thisMonthRevenue = 0.0;
      double lastMonthRevenue = 0.0;
      double thisYearRevenue = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['totalPrice'] ?? 0).toDouble();
        
        totalRevenue += amount;
        
        if (createdAt != null) {
          if (createdAt.isAfter(firstDayThisMonth)) {
            thisMonthRevenue += amount;
          }
          if (createdAt.isAfter(firstDayLastMonth) && createdAt.isBefore(firstDayThisMonth)) {
            lastMonthRevenue += amount;
          }
          if (createdAt.isAfter(firstDayThisYear)) {
            thisYearRevenue += amount;
          }
        }
      }

      return {
        'total': totalRevenue,
        'thisMonth': thisMonthRevenue,
        'lastMonth': lastMonthRevenue,
        'thisYear': thisYearRevenue,
        'monthlyGrowth': lastMonthRevenue > 0 
            ? ((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100 
            : 0.0,
      };
    });
  }

  /// Get current user's revenue analytics stream
  static Stream<Map<String, double>> getCurrentUserRevenueAnalyticsStream() {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return Stream.value({
        'total': 0.0,
        'thisMonth': 0.0,
        'lastMonth': 0.0,
        'thisYear': 0.0,
        'monthlyGrowth': 0.0,
      });
    }
    return getSupplierRevenueAnalyticsStream(currentUser.uid);
  }

  /// Format currency for display
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  /// Format currency without decimals for large amounts
  static String formatCurrencyCompact(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '₱${amount.toStringAsFixed(0)}';
    }
  }

  /// Get revenue growth percentage with proper formatting
  static String formatGrowthPercentage(double percentage) {
    if (percentage == 0) return '0%';
    final sign = percentage >= 0 ? '+' : '';
    return '$sign${percentage.toStringAsFixed(1)}%';
  }
}
