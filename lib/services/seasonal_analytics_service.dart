import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class SeasonalAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<Map<String, dynamic>> getSeasonalAnalyticsStream() {
    return _firestore.collection('products')
        .snapshots()
        .asyncMap((snapshot) async {
      
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentSeason = _getSeason(currentMonth);
      
      Map<String, dynamic> analytics = {
        'currentSeason': currentSeason,
        'seasonalTrends': <String, Map<String, dynamic>>{},
        'monthlyBreakdown': <String, Map<String, dynamic>>{},
        'peakHarvestMonths': <String, int>{},
        'seasonalRevenue': <String, double>{},
        'topSeasonalProducts': <Map<String, dynamic>>[],
      };

      // Initialize seasonal data
      Map<String, Map<String, dynamic>> seasonalData = {
        'Spring': {'products': 0, 'revenue': 0.0, 'categories': <String, int>{}},
        'Summer': {'products': 0, 'revenue': 0.0, 'categories': <String, int>{}},
        'Fall': {'products': 0, 'revenue': 0.0, 'categories': <String, int>{}},
        'Winter': {'products': 0, 'revenue': 0.0, 'categories': <String, int>{}},
      };

      Map<String, Map<String, dynamic>> monthlyData = {};
      Map<String, int> harvestMonths = {};
      List<Map<String, dynamic>> productSeasonalData = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final productId = doc.id;
        final category = data['category'] ?? 'Other';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        if (createdAt != null) {
          final month = createdAt.month;
          final season = _getSeason(month);
          final monthName = _getMonthName(month);
          
          // Count products by season
          seasonalData[season]!['products'] = (seasonalData[season]!['products'] as int) + 1;
          
          // Count categories by season
          Map<String, int> seasonCategories = seasonalData[season]!['categories'] as Map<String, int>;
          seasonCategories[category] = (seasonCategories[category] ?? 0) + 1;
          
          // Count harvest months
          harvestMonths[monthName] = (harvestMonths[monthName] ?? 0) + 1;
          
          // Initialize monthly data
          if (!monthlyData.containsKey(monthName)) {
            monthlyData[monthName] = {
              'products': 0,
              'revenue': 0.0,
              'orders': 0,
            };
          }
          monthlyData[monthName]!['products'] = (monthlyData[monthName]!['products'] as int) + 1;

          // Get product revenue and orders
          final ordersQuery = await _firestore
              .collection('orders')
              .where('productId', isEqualTo: productId)
              .where('status', isEqualTo: 'picked_up')
              .get();
          
          double productRevenue = 0.0;
          int productOrders = ordersQuery.docs.length;
          
          for (var order in ordersQuery.docs) {
            final orderData = order.data();
            final orderDate = (orderData['createdAt'] as Timestamp?)?.toDate();
            final orderAmount = (orderData['totalAmount'] ?? 0).toDouble();
            productRevenue += orderAmount;
            
            if (orderDate != null) {
              final orderMonth = orderDate.month;
              final orderSeason = _getSeason(orderMonth);
              final orderMonthName = _getMonthName(orderMonth);
              
              // Add to seasonal revenue
              seasonalData[orderSeason]!['revenue'] = 
                  (seasonalData[orderSeason]!['revenue'] as double) + orderAmount;
              
              // Add to monthly revenue
              if (!monthlyData.containsKey(orderMonthName)) {
                monthlyData[orderMonthName] = {
                  'products': 0,
                  'revenue': 0.0,
                  'orders': 0,
                };
              }
              monthlyData[orderMonthName]!['revenue'] = 
                  (monthlyData[orderMonthName]!['revenue'] as double) + orderAmount;
              monthlyData[orderMonthName]!['orders'] = 
                  (monthlyData[orderMonthName]!['orders'] as int) + 1;
            }
          }

          productSeasonalData.add({
            'id': productId,
            'name': data['name'] ?? 'Unknown',
            'category': category,
            'season': season,
            'month': monthName,
            'revenue': productRevenue,
            'orders': productOrders,
            'price': (data['price'] ?? 0).toDouble(),
          });
        }
      }

      analytics['seasonalTrends'] = seasonalData;
      analytics['monthlyBreakdown'] = monthlyData;
      analytics['peakHarvestMonths'] = harvestMonths;

      // Extract seasonal revenue
      Map<String, double> seasonalRevenue = {};
      seasonalData.forEach((season, data) {
        seasonalRevenue[season] = data['revenue'] as double;
      });
      analytics['seasonalRevenue'] = seasonalRevenue;

      // Get top seasonal products for current season
      final currentSeasonProducts = productSeasonalData
          .where((product) => product['season'] == currentSeason)
          .toList();
      currentSeasonProducts.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      analytics['topSeasonalProducts'] = currentSeasonProducts.take(5).toList();

      return analytics;
    });
  }

  static Stream<Map<String, dynamic>> getWeatherImpactAnalyticsStream() {
    return _firestore.collection('orders')
        .snapshots()
        .asyncMap((snapshot) async {
      
      Map<String, dynamic> analytics = {
        'rainySeasonSales': 0.0,
        'drySeasonSales': 0.0,
        'weatherTrends': <String, double>{},
        'impactedCategories': <String, Map<String, dynamic>>{},
      };

      double rainySeasonRevenue = 0.0;
      double drySeasonRevenue = 0.0;
      Map<String, double> monthlyRevenue = {};
      Map<String, Map<String, dynamic>> categoryWeatherData = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['totalAmount'] ?? 0).toDouble();
        
        if (createdAt != null) {
          final month = createdAt.month;
          final monthName = _getMonthName(month);
          final isRainySeason = _isRainySeason(month);
          
          monthlyRevenue[monthName] = (monthlyRevenue[monthName] ?? 0) + amount;
          
          if (isRainySeason) {
            rainySeasonRevenue += amount;
          } else {
            drySeasonRevenue += amount;
          }

          // Get product category for weather impact analysis
          final productId = data['productId'];
          if (productId != null) {
            final productDoc = await _firestore.collection('products').doc(productId).get();
            if (productDoc.exists) {
              final productData = productDoc.data() as Map<String, dynamic>;
              final category = productData['category'] ?? 'Other';
              
              if (!categoryWeatherData.containsKey(category)) {
                categoryWeatherData[category] = {
                  'rainyRevenue': 0.0,
                  'dryRevenue': 0.0,
                  'rainyOrders': 0,
                  'dryOrders': 0,
                };
              }
              
              if (isRainySeason) {
                categoryWeatherData[category]!['rainyRevenue'] = 
                    (categoryWeatherData[category]!['rainyRevenue'] as double) + amount;
                categoryWeatherData[category]!['rainyOrders'] = 
                    (categoryWeatherData[category]!['rainyOrders'] as int) + 1;
              } else {
                categoryWeatherData[category]!['dryRevenue'] = 
                    (categoryWeatherData[category]!['dryRevenue'] as double) + amount;
                categoryWeatherData[category]!['dryOrders'] = 
                    (categoryWeatherData[category]!['dryOrders'] as int) + 1;
              }
            }
          }
        }
      }

      analytics['rainySeasonSales'] = rainySeasonRevenue;
      analytics['drySeasonSales'] = drySeasonRevenue;
      analytics['weatherTrends'] = monthlyRevenue;
      analytics['impactedCategories'] = categoryWeatherData;

      return analytics;
    });
  }

  // Helper methods
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

  static String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  static bool _isRainySeason(int month) {
    // Philippines rainy season: June to November
    return month >= 6 && month <= 11;
  }

  static String formatSeasonalTrend(double current, double previous) {
    if (previous == 0) return 'New';
    final change = ((current - previous) / previous * 100);
    return change >= 0 ? '+${change.toStringAsFixed(1)}%' : '${change.toStringAsFixed(1)}%';
  }

  static String getSeasonalRecommendation(String season, Map<String, dynamic> data) {
    switch (season) {
      case 'Spring':
        return 'Focus on leafy greens and herbs - peak growing season';
      case 'Summer':
        return 'Promote heat-resistant crops and root vegetables';
      case 'Fall':
        return 'Harvest season - expect high volume of fresh produce';
      case 'Winter':
        return 'Limited fresh produce - focus on stored crops';
      default:
        return 'Monitor seasonal patterns for optimization';
    }
  }
}
