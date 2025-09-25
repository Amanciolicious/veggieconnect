// ignore_for_file: avoid_types_as_parameter_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Modern Analytics Service with latest KPIs and real-time metrics
/// Implements contemporary analytics indicators commonly used by developers in 2024

class ModernAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Real-time KPIs and Metrics
  static Stream<Map<String, dynamic>> getRealTimeKPIsStream() {
    return _firestore.collection('orders')
        .where('status', isEqualTo: 'picked_up')
        .snapshots()
        .asyncMap((snapshot) async {
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastWeek = today.subtract(const Duration(days: 7));
      final lastMonth = today.subtract(const Duration(days: 30));

      // Calculate real-time metrics
      double todayRevenue = 0.0;
      double yesterdayRevenue = 0.0;
      double lastWeekRevenue = 0.0;
      double lastMonthRevenue = 0.0;
      
      int todayOrders = 0;
      int yesterdayOrders = 0;
      int lastWeekOrders = 0;
      int lastMonthOrders = 0;

      Set<String> todayCustomers = {};
      Set<String> yesterdayCustomers = {};
      Set<String> lastWeekCustomers = {};
      Set<String> lastMonthCustomers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['totalAmount'] ?? 0).toDouble();
        final buyerId = data['buyerId']?.toString();

        if (createdAt != null && buyerId != null) {
          final orderDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
          
          if (orderDate.isAtSameMomentAs(today)) {
            todayRevenue += amount;
            todayOrders++;
            todayCustomers.add(buyerId);
          } else if (orderDate.isAtSameMomentAs(yesterday)) {
            yesterdayRevenue += amount;
            yesterdayOrders++;
            yesterdayCustomers.add(buyerId);
          } else if (orderDate.isAfter(lastWeek)) {
            lastWeekRevenue += amount;
            lastWeekOrders++;
            lastWeekCustomers.add(buyerId);
          } else if (orderDate.isAfter(lastMonth)) {
            lastMonthRevenue += amount;
            lastMonthOrders++;
            lastMonthCustomers.add(buyerId);
          }
        }
      }

      // Calculate growth rates
      final dailyGrowth = yesterdayRevenue > 0 
          ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100)
          : 0.0;
      
      final weeklyGrowth = lastWeekRevenue > 0 
          ? ((todayRevenue * 7 - lastWeekRevenue) / lastWeekRevenue * 100)
          : 0.0;

      final monthlyGrowth = lastMonthRevenue > 0 
          ? ((todayRevenue * 30 - lastMonthRevenue) / lastMonthRevenue * 100)
          : 0.0;

      // Calculate average order value
      final todayAOV = todayOrders > 0 ? todayRevenue / todayOrders : 0.0;
      final yesterdayAOV = yesterdayOrders > 0 ? yesterdayRevenue / yesterdayOrders : 0.0;

      return {
        'todayRevenue': todayRevenue,
        'yesterdayRevenue': yesterdayRevenue,
        'lastWeekRevenue': lastWeekRevenue,
        'lastMonthRevenue': lastMonthRevenue,
        'todayOrders': todayOrders,
        'yesterdayOrders': yesterdayOrders,
        'lastWeekOrders': lastWeekOrders,
        'lastMonthOrders': lastMonthOrders,
        'todayCustomers': todayCustomers.length,
        'yesterdayCustomers': yesterdayCustomers.length,
        'lastWeekCustomers': lastWeekCustomers.length,
        'lastMonthCustomers': lastMonthCustomers.length,
        'dailyGrowth': dailyGrowth,
        'weeklyGrowth': weeklyGrowth,
        'monthlyGrowth': monthlyGrowth,
        'todayAOV': todayAOV,
        'yesterdayAOV': yesterdayAOV,
        'aovGrowth': yesterdayAOV > 0 ? ((todayAOV - yesterdayAOV) / yesterdayAOV * 100) : 0.0,
      };
    });
  }

  // User Engagement Analytics
  static Stream<Map<String, dynamic>> getUserEngagementStream() {
    return _firestore.collection('users')
        .snapshots()
        .asyncMap((snapshot) async {
      
      int totalUsers = 0;
      int activeUsers = 0;
      int newUsers = 0;
      int returningUsers = 0;
      
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 7));
      final last30Days = now.subtract(const Duration(days: 30));

      Map<String, int> userActivityByDay = {};
      Map<String, int> userRoleDistribution = {};
      List<Map<String, dynamic>> topActiveUsers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final lastLoginAt = (data['lastLoginAt'] as Timestamp?)?.toDate();
        final role = data['role']?.toString() ?? 'unknown';
        final userId = doc.id;

        // Skip admin and sub_admin users - only count suppliers and buyers
        if (role.toLowerCase() == 'admin' || role.toLowerCase() == 'sub_admin') {
          continue;
        }

        // Count total users (excluding admins)
        totalUsers++;

        // Count role distribution (excluding admins)
        userRoleDistribution[role] = (userRoleDistribution[role] ?? 0) + 1;

        // Count new users (excluding admins)
        if (createdAt != null && createdAt.isAfter(last30Days)) {
          newUsers++;
        }

        // Count active users (logged in within last 7 days, excluding admins)
        if (lastLoginAt != null && lastLoginAt.isAfter(last7Days)) {
          activeUsers++;
          
          // Track daily activity
          final loginDate = DateTime(lastLoginAt.year, lastLoginAt.month, lastLoginAt.day);
          final dateKey = '${loginDate.year}-${loginDate.month.toString().padLeft(2, '0')}-${loginDate.day.toString().padLeft(2, '0')}';
          userActivityByDay[dateKey] = (userActivityByDay[dateKey] ?? 0) + 1;

          // Get user activity score
          final activityScore = await _calculateUserActivityScore(userId);
          topActiveUsers.add({
            'id': userId,
            'name': data['name'] ?? 'Unknown',
            'role': role,
            'activityScore': activityScore,
            'lastLogin': lastLoginAt,
          });
        }

        // Count returning users (multiple logins, excluding admins)
        if (lastLoginAt != null && createdAt != null && lastLoginAt.isAfter(createdAt.add(const Duration(days: 1)))) {
          returningUsers++;
        }
      }

      // Sort and get top active users
      topActiveUsers.sort((a, b) => (b['activityScore'] as double).compareTo(a['activityScore'] as double));

      // Calculate engagement metrics
      final activeUserRate = totalUsers > 0 ? (activeUsers / totalUsers * 100) : 0.0;
      final newUserRate = totalUsers > 0 ? (newUsers / totalUsers * 100) : 0.0;
      final returningUserRate = activeUsers > 0 ? (returningUsers / activeUsers * 100) : 0.0;

      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'newUsers': newUsers,
        'returningUsers': returningUsers,
        'activeUserRate': activeUserRate,
        'newUserRate': newUserRate,
        'returningUserRate': returningUserRate,
        'userActivityByDay': userActivityByDay,
        'userRoleDistribution': userRoleDistribution,
        'topActiveUsers': topActiveUsers.take(10).toList(),
      };
    });
  }

  // Business Performance Metrics
  static Stream<Map<String, dynamic>> getBusinessPerformanceStream() {
    return _firestore.collection('orders')
        .snapshots()
        .asyncMap((snapshot) async {
      
      double totalRevenue = 0.0;
      int totalOrders = 0;
      int completedOrders = 0;
      int pendingOrders = 0;
      int cancelledOrders = 0;
      
      double totalOrderValue = 0.0;
      Map<String, double> revenueByStatus = {};
      Map<String, int> ordersByStatus = {};
      List<Map<String, dynamic>> recentOrders = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? 'pending';
        final amount = (data['totalAmount'] ?? 0).toDouble();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        totalOrders++;
        totalOrderValue += amount;
        revenueByStatus[status] = (revenueByStatus[status] ?? 0) + amount;
        ordersByStatus[status] = (ordersByStatus[status] ?? 0) + 1;

        switch (status) {
          case 'picked_up':
            completedOrders++;
            totalRevenue += amount;
            break;
          case 'pending':
            pendingOrders++;
            break;
          case 'cancelled':
            cancelledOrders++;
            break;
        }

        // Collect recent orders for analysis
        if (createdAt != null) {
          recentOrders.add({
            'id': doc.id,
            'amount': amount,
            'status': status,
            'createdAt': createdAt,
            'buyerId': data['buyerId'],
            'supplierId': data['supplierId'],
          });
        }
      }

      // Sort recent orders by date
      recentOrders.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

      // Calculate performance metrics
      final completionRate = totalOrders > 0 ? (completedOrders / totalOrders * 100) : 0.0;
      final cancellationRate = totalOrders > 0 ? (cancelledOrders / totalOrders * 100) : 0.0;
      final averageOrderValue = totalOrders > 0 ? totalOrderValue / totalOrders : 0.0;

      // Calculate conversion funnel
      final conversionFunnel = {
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'pendingOrders': pendingOrders,
        'cancelledOrders': cancelledOrders,
        'completionRate': completionRate,
        'cancellationRate': cancellationRate,
      };

      return {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'pendingOrders': pendingOrders,
        'cancelledOrders': cancelledOrders,
        'completionRate': completionRate,
        'cancellationRate': cancellationRate,
        'averageOrderValue': averageOrderValue,
        'revenueByStatus': revenueByStatus,
        'ordersByStatus': ordersByStatus,
        'conversionFunnel': conversionFunnel,
        'recentOrders': recentOrders.take(20).toList(),
      };
    });
  }

  // Product Performance Analytics
  static Stream<Map<String, dynamic>> getProductPerformanceStream() {
    return _firestore.collection('products')
        .snapshots()
        .asyncMap((snapshot) async {
      
      int totalProducts = snapshot.docs.length;
      int activeProducts = 0;
      int lowStockProducts = 0;
      int outOfStockProducts = 0;
      double totalInventoryValue = 0.0;
      
      Map<String, int> categoryDistribution = {};
      Map<String, double> categoryRevenue = {};
      List<Map<String, dynamic>> topPerformingProducts = [];
      List<Map<String, dynamic>> lowStockAlerts = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final productId = doc.id;
        final isActive = data['isActive'] == true;
        final quantity = (data['quantity'] ?? 0).toDouble();
        final price = (data['price'] ?? 0).toDouble();
        final category = data['category']?.toString() ?? 'Other';
        final name = data['name']?.toString() ?? 'Unknown';

        if (isActive) activeProducts++;

        // Inventory analysis
        final inventoryValue = quantity * price;
        totalInventoryValue += inventoryValue;

        if (quantity <= 0) {
          outOfStockProducts++;
          lowStockAlerts.add({
            'id': productId,
            'name': name,
            'category': category,
            'quantity': quantity,
            'status': 'Out of Stock',
          });
        } else if (quantity <= 5) {
          lowStockProducts++;
          lowStockAlerts.add({
            'id': productId,
            'name': name,
            'category': category,
            'quantity': quantity,
            'status': 'Low Stock',
          });
        }

        // Category distribution
        categoryDistribution[category] = (categoryDistribution[category] ?? 0) + 1;

        // Get product revenue
        final ordersQuery = await _firestore
            .collection('orders')
            .where('productId', isEqualTo: productId)
            .where('status', isEqualTo: 'picked_up')
            .get();

        double productRevenue = 0.0;
        int orderCount = 0;
        for (var order in ordersQuery.docs) {
          final orderData = order.data();
          productRevenue += (orderData['totalAmount'] ?? 0).toDouble();
          orderCount++;
        }

        categoryRevenue[category] = (categoryRevenue[category] ?? 0) + productRevenue;

        topPerformingProducts.add({
          'id': productId,
          'name': name,
          'category': category,
          'revenue': productRevenue,
          'orders': orderCount,
          'quantity': quantity,
          'price': price,
          'inventoryValue': inventoryValue,
        });
      }

      // Sort products by revenue
      topPerformingProducts.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

      // Calculate inventory metrics
      final inventoryTurnover = totalInventoryValue > 0 
          ? (topPerformingProducts.fold(0.0, (sum, product) => sum + (product['revenue'] as double)) / totalInventoryValue)
          : 0.0;

      final stockHealthScore = totalProducts > 0 
          ? ((totalProducts - lowStockProducts - outOfStockProducts) / totalProducts * 100)
          : 0.0;

      return {
        'totalProducts': totalProducts,
        'activeProducts': activeProducts,
        'lowStockProducts': lowStockProducts,
        'outOfStockProducts': outOfStockProducts,
        'totalInventoryValue': totalInventoryValue,
        'inventoryTurnover': inventoryTurnover,
        'stockHealthScore': stockHealthScore,
        'categoryDistribution': categoryDistribution,
        'categoryRevenue': categoryRevenue,
        'topPerformingProducts': topPerformingProducts.take(10).toList(),
        'lowStockAlerts': lowStockAlerts,
      };
    });
  }

  // Market Trends and Insights
  static Stream<Map<String, dynamic>> getMarketTrendsStream() {
    return _firestore.collection('orders')
        .snapshots()
        .asyncMap((snapshot) async {
      
      Map<String, double> hourlyRevenue = {};
      Map<String, int> hourlyOrders = {};
      Map<String, double> dailyRevenue = {};
      Map<String, int> dailyOrders = {};
      Map<String, double> monthlyRevenue = {};
      Map<String, int> monthlyOrders = {};

      List<Map<String, dynamic>> seasonalTrends = [];
      Map<String, double> categoryTrends = {};
      Map<String, int> peakHours = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['totalAmount'] ?? 0).toDouble();
        final productId = data['productId']?.toString();

        if (createdAt != null) {
          // Hourly trends
          final hour = createdAt.hour;
          final hourKey = '${hour.toString().padLeft(2, '0')}:00';
          hourlyRevenue[hourKey] = (hourlyRevenue[hourKey] ?? 0) + amount;
          hourlyOrders[hourKey] = (hourlyOrders[hourKey] ?? 0) + 1;

          // Daily trends
          final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + amount;
          dailyOrders[dayKey] = (dailyOrders[dayKey] ?? 0) + 1;

          // Monthly trends
          final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
          monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + amount;
          monthlyOrders[monthKey] = (monthlyOrders[monthKey] ?? 0) + 1;

          // Peak hours analysis
          if (hour >= 8 && hour <= 20) {
            peakHours[hourKey] = (peakHours[hourKey] ?? 0) + 1;
          }

          // Get product category for trend analysis
          if (productId != null) {
            final productDoc = await _firestore.collection('products').doc(productId).get();
            if (productDoc.exists) {
              final productData = productDoc.data() as Map<String, dynamic>;
              final category = productData['category']?.toString() ?? 'Other';
              categoryTrends[category] = (categoryTrends[category] ?? 0) + amount;
            }
          }
        }
      }

      // Calculate seasonal patterns
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentSeason = _getSeason(currentMonth);

      // Find peak hours
      final sortedPeakHours = peakHours.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'hourlyRevenue': hourlyRevenue,
        'hourlyOrders': hourlyOrders,
        'dailyRevenue': dailyRevenue,
        'dailyOrders': dailyOrders,
        'monthlyRevenue': monthlyRevenue,
        'monthlyOrders': monthlyOrders,
        'categoryTrends': categoryTrends,
        'peakHours': sortedPeakHours.take(5).map((e) => {'hour': e.key, 'orders': e.value}).toList(),
        'currentSeason': currentSeason,
        'seasonalTrends': seasonalTrends,
      };
    });
  }

  // Helper method to calculate user activity score
  static Future<double> _calculateUserActivityScore(String userId) async {
    // Get user's orders, products (if supplier), and other activities
    final ordersQuery = await _firestore
        .collection('orders')
        .where('buyerId', isEqualTo: userId)
        .get();
    
    final productsQuery = await _firestore
        .collection('products')
        .where('supplierId', isEqualTo: userId)
        .get();

    final orderCount = ordersQuery.docs.length;
    final productCount = productsQuery.docs.length;
    
    // Simple activity score calculation
    return (orderCount * 2.0) + (productCount * 1.5);
  }

  // Helper method to get season
  static String _getSeason(int month) {
    switch (month) {
      case 12:
      case 1:
      case 2:
        return 'Winter';
      case 3:
      case 4:
      case 5:
        return 'Spring';
      case 6:
      case 7:
      case 8:
        return 'Summer';
      case 9:
      case 10:
      case 11:
        return 'Fall';
      default:
        return 'Unknown';
    }
  }

  // Utility methods for formatting
  static String formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '₱${amount.toStringAsFixed(0)}';
    }
  }

  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }

  static String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  static String formatDuration(double hours) {
    if (hours >= 24) {
      return '${(hours / 24).toStringAsFixed(1)} days';
    } else {
      return '${hours.toStringAsFixed(1)} hours';
    }
  }
}
