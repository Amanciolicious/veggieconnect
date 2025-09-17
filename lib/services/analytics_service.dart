// ignore_for_file: avoid_types_as_parameter_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Core Analytics Data Models
  static Stream<Map<String, dynamic>> getSupplierPerformanceStream() {
    return _firestore.collection('users')
        .where('role', isEqualTo: 'supplier')
        .snapshots()
        .asyncMap((snapshot) async {
      
      Map<String, dynamic> analytics = {
        'totalSuppliers': snapshot.docs.length,
        'verifiedSuppliers': 0,
        'activeSuppliers': 0,
        'topSuppliers': <Map<String, dynamic>>[],
        'averageRating': 0.0,
        'supplierGrowth': 0.0,
      };

      int verifiedCount = 0;
      int activeCount = 0;
      double totalRating = 0.0;
      int ratedSuppliers = 0;
      List<Map<String, dynamic>> supplierData = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final supplierId = doc.id;
        
        // Count verified suppliers
        if (data['isVerified'] == true) verifiedCount++;
        
        // Count active suppliers (have active products)
        final productsQuery = await _firestore
            .collection('products')
            .where('supplierId', isEqualTo: supplierId)
            .where('isActive', isEqualTo: true)
            .get();
        
        if (productsQuery.docs.isNotEmpty) activeCount++;

        // Get supplier revenue
        final ordersQuery = await _firestore
            .collection('orders')
            .where('supplierId', isEqualTo: supplierId)
            .where('status', isEqualTo: 'completed')
            .get();
        
        double revenue = 0.0;
        for (var order in ordersQuery.docs) {
          final orderData = order.data();
          revenue += (orderData['totalPrice'] ?? 0).toDouble();
        }

        // Calculate average rating
        double rating = (data['averageRating'] ?? 0.0).toDouble();
        if (rating > 0) {
          totalRating += rating;
          ratedSuppliers++;
        }

        supplierData.add({
          'id': supplierId,
          'name': data['name'] ?? 'Unknown',
          'revenue': revenue,
          'rating': rating,
          'productCount': productsQuery.docs.length,
          'isVerified': data['isVerified'] ?? false,
        });
      }

      // Sort suppliers by revenue and get top 5
      supplierData.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      analytics['topSuppliers'] = supplierData.take(5).toList();

      analytics['verifiedSuppliers'] = verifiedCount;
      analytics['activeSuppliers'] = activeCount;
      analytics['averageRating'] = ratedSuppliers > 0 ? totalRating / ratedSuppliers : 0.0;

      // Calculate growth (simplified - compare with last month)
      final lastMonth = DateTime.now().subtract(const Duration(days: 30));
      final lastMonthSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'supplier')
          .where('createdAt', isLessThan: Timestamp.fromDate(lastMonth))
          .get();
      
      final previousCount = lastMonthSnapshot.docs.length;
      analytics['supplierGrowth'] = previousCount > 0 
          ? ((snapshot.docs.length - previousCount) / previousCount * 100)
          : 0.0;

      return analytics;
    });
  }

  static Stream<Map<String, dynamic>> getProductCategoryAnalyticsStream() {
    return _firestore.collection('products')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      
      Map<String, dynamic> analytics = {
        'totalProducts': snapshot.docs.length,
        'categoryBreakdown': <String, int>{},
        'topCategories': <Map<String, dynamic>>[],
        'averagePrice': 0.0,
        'organicPercentage': 0.0,
      };

      Map<String, int> categoryCount = {};
      Map<String, double> categoryRevenue = {};
      double totalPrice = 0.0;
      int organicCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = (data['category'] ?? 'Other').toString();
        final price = (data['price'] ?? 0).toDouble();
        final isOrganic = data['isOrganic'] == true;

        // Count by category
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        
        // Calculate category revenue
        final productId = doc.id;
        final ordersQuery = await _firestore
            .collection('orders')
            .where('productId', isEqualTo: productId)
            .where('status', isEqualTo: 'completed')
            .get();
        
        double productRevenue = 0.0;
        for (var order in ordersQuery.docs) {
          final orderData = order.data();
          productRevenue += (orderData['totalPrice'] ?? 0).toDouble();
        }
        categoryRevenue[category] = (categoryRevenue[category] ?? 0) + productRevenue;

        totalPrice += price;
        if (isOrganic) organicCount++;
      }

      analytics['categoryBreakdown'] = categoryCount;
      analytics['averagePrice'] = snapshot.docs.isNotEmpty ? totalPrice / snapshot.docs.length : 0.0;
      analytics['organicPercentage'] = snapshot.docs.isNotEmpty ? (organicCount / snapshot.docs.length * 100) : 0.0;

      // Create top categories list
      List<Map<String, dynamic>> topCategories = [];
      categoryCount.forEach((category, count) {
        topCategories.add({
          'name': category,
          'count': count,
          'revenue': categoryRevenue[category] ?? 0.0,
          'percentage': (count / snapshot.docs.length * 100),
        });
      });
      
      topCategories.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      analytics['topCategories'] = topCategories.take(5).toList();

      return analytics;
    });
  }

  static Stream<Map<String, dynamic>> getCustomerBehaviorAnalyticsStream() {
    return _firestore.collection('users')
        .where('role', isEqualTo: 'buyer')
        .snapshots()
        .asyncMap((snapshot) async {
      
      Map<String, dynamic> analytics = {
        'totalCustomers': snapshot.docs.length,
        'activeCustomers': 0,
        'averageOrderValue': 0.0,
        'repeatCustomerRate': 0.0,
        'customerGrowth': 0.0,
        'topCustomers': <Map<String, dynamic>>[],
      };

      int activeCount = 0;
      double totalOrderValue = 0.0;
      int totalOrders = 0;
      int repeatCustomers = 0;
      List<Map<String, dynamic>> customerData = [];

      for (var doc in snapshot.docs) {
        final customerId = doc.id;
        final customerInfo = doc.data();
        
        // Get customer orders
        final ordersQuery = await _firestore
            .collection('orders')
            .where('buyerId', isEqualTo: customerId)
            .get();
        
        final orderCount = ordersQuery.docs.length;
        double customerRevenue = 0.0;

        for (var order in ordersQuery.docs) {
          final orderData = order.data();
          customerRevenue += (orderData['totalPrice'] ?? 0).toDouble();
        }

        if (orderCount > 0) {
          activeCount++;
          totalOrderValue += customerRevenue;
          totalOrders += orderCount;
          
          if (orderCount > 1) repeatCustomers++;

          customerData.add({
            'id': customerId,
            'name': customerInfo['name'] ?? 'Unknown',
            'orderCount': orderCount,
            'totalSpent': customerRevenue,
            'averageOrderValue': orderCount > 0 ? customerRevenue / orderCount : 0.0,
          });
        }
      }

      analytics['activeCustomers'] = activeCount;
      analytics['averageOrderValue'] = totalOrders > 0 ? totalOrderValue / totalOrders : 0.0;
      analytics['repeatCustomerRate'] = activeCount > 0 ? (repeatCustomers / activeCount * 100) : 0.0;

      // Sort customers by total spent and get top 5
      customerData.sort((a, b) => (b['totalSpent'] as double).compareTo(a['totalSpent'] as double));
      analytics['topCustomers'] = customerData.take(5).toList();

      // Calculate customer growth
      final lastMonth = DateTime.now().subtract(const Duration(days: 30));
      final lastMonthSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'buyer')
          .where('createdAt', isLessThan: Timestamp.fromDate(lastMonth))
          .get();
      
      final previousCount = lastMonthSnapshot.docs.length;
      analytics['customerGrowth'] = previousCount > 0 
          ? ((snapshot.docs.length - previousCount) / previousCount * 100)
          : 0.0;

      return analytics;
    });
  }

  static Stream<Map<String, dynamic>> getOperationalAnalyticsStream() {
    return _firestore.collection('products')
        .snapshots()
        .asyncMap((snapshot) async {
      
      Map<String, dynamic> analytics = {
        'pendingProducts': 0,
        'approvedProducts': 0,
        'rejectedProducts': 0,
        'averageApprovalTime': 0.0,
        'autoApprovalRate': 0.0,
        'qualityScore': 0.0,
      };

      int pendingCount = 0;
      int approvedCount = 0;
      int rejectedCount = 0;
      int autoApprovedCount = 0;
      double totalApprovalTime = 0.0;
      int processedProducts = 0;
      double totalRating = 0.0;
      int ratedProducts = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'pending';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final approvedAt = (data['approvedAt'] as Timestamp?)?.toDate();
        final isAutoApproved = data['isAutoApproved'] == true;
        final rating = (data['averageRating'] ?? 0.0).toDouble();

        switch (status) {
          case 'pending':
            pendingCount++;
            break;
          case 'approved':
            approvedCount++;
            if (isAutoApproved) autoApprovedCount++;
            
            if (createdAt != null && approvedAt != null) {
              final approvalTime = approvedAt.difference(createdAt).inHours.toDouble();
              totalApprovalTime += approvalTime;
              processedProducts++;
            }
            break;
          case 'rejected':
            rejectedCount++;
            
            if (createdAt != null && approvedAt != null) {
              final approvalTime = approvedAt.difference(createdAt).inHours.toDouble();
              totalApprovalTime += approvalTime;
              processedProducts++;
            }
            break;
        }

        if (rating > 0) {
          totalRating += rating;
          ratedProducts++;
        }
      }

      analytics['pendingProducts'] = pendingCount;
      analytics['approvedProducts'] = approvedCount;
      analytics['rejectedProducts'] = rejectedCount;
      analytics['averageApprovalTime'] = processedProducts > 0 ? totalApprovalTime / processedProducts : 0.0;
      analytics['autoApprovalRate'] = approvedCount > 0 ? (autoApprovedCount / approvedCount * 100) : 0.0;
      analytics['qualityScore'] = ratedProducts > 0 ? totalRating / ratedProducts : 0.0;

      return analytics;
    });
  }

  static Stream<Map<String, dynamic>> getGeographicAnalyticsStream() {
    return _firestore.collection('users')
        .snapshots()
        .asyncMap((snapshot) async {
      
      Map<String, dynamic> analytics = {
        'locationBreakdown': <String, Map<String, int>>{},
        'topCities': <Map<String, dynamic>>[],
        'supplierDistribution': <String, int>{},
        'customerDistribution': <String, int>{},
      };

      Map<String, int> supplierByCity = {};
      Map<String, int> customerByCity = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final role = data['role'] ?? '';
        final address = data['address'] ?? '';
        
        // Extract city from address (simplified)
        String city = 'Unknown';
        if (address.isNotEmpty) {
          final addressParts = address.split(',');
          if (addressParts.isNotEmpty) {
            city = addressParts.last.trim();
          }
        }

        if (role.toLowerCase() == 'supplier') {
          supplierByCity[city] = (supplierByCity[city] ?? 0) + 1;
        } else if (role.toLowerCase() == 'buyer') {
          customerByCity[city] = (customerByCity[city] ?? 0) + 1;
        }
      }

      analytics['supplierDistribution'] = supplierByCity;
      analytics['customerDistribution'] = customerByCity;

      // Create combined city data
      Set<String> allCities = {...supplierByCity.keys, ...customerByCity.keys};
      List<Map<String, dynamic>> cityData = [];
      
      for (String city in allCities) {
        final suppliers = supplierByCity[city] ?? 0;
        final customers = customerByCity[city] ?? 0;
        final total = suppliers + customers;
        
        cityData.add({
          'city': city,
          'suppliers': suppliers,
          'customers': customers,
          'total': total,
        });
      }

      cityData.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
      analytics['topCities'] = cityData.take(10).toList();

      return analytics;
    });
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

  static String formatDuration(double hours) {
    if (hours >= 24) {
      return '${(hours / 24).toStringAsFixed(1)} days';
    } else {
      return '${hours.toStringAsFixed(1)} hours';
    }
  }
}
