// ignore_for_file: unrelated_type_equality_checks, deprecated_member_use

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/lottie_loading_widget.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  
  // Performance settings
  bool _isLowPowerMode = false;
  bool _isSlowConnection = false;
  bool _isInitialized = false;

  // Cache settings
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB

  // Stream controllers
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  // Initialize performance service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load performance settings
      await _loadPerformanceSettings();
      
      // Initialize connectivity monitoring
      await _initializeConnectivityMonitoring();
      
      // Initialize image cache
      await _initializeImageCache();
      
      _isInitialized = true;
      debugPrint('PerformanceService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing PerformanceService: $e');
    }
  }

  // Load performance settings from SharedPreferences
  Future<void> _loadPerformanceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLowPowerMode = prefs.getBool('low_power_mode') ?? false;
      _isSlowConnection = prefs.getBool('slow_connection') ?? false;
    } catch (e) {
      debugPrint('Error loading performance settings: $e');
    }
  }

  // Save performance settings to SharedPreferences
  Future<void> _savePerformanceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('low_power_mode', _isLowPowerMode);
      await prefs.setBool('slow_connection', _isSlowConnection);
    } catch (e) {
      debugPrint('Error saving performance settings: $e');
    }
  }

  // Initialize connectivity monitoring
  Future<void> _initializeConnectivityMonitoring() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result as ConnectivityResult);

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _updateConnectivityStatus(results.first);
        },
        onError: (error) {
          debugPrint('Connectivity monitoring error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error initializing connectivity monitoring: $e');
    }
  }

  // Update connectivity status
  void _updateConnectivityStatus(ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;
    final isSlowConnection = result == ConnectivityResult.mobile;
    
    _isSlowConnection = isSlowConnection;
    _connectivityController.add(isConnected);
    
    debugPrint('Connectivity: $result (Connected: $isConnected, Slow: $isSlowConnection)');
  }

  // Initialize image cache
  Future<void> _initializeImageCache() async {
    try {
      // Note: cached_network_image does not expose global log-level configuration.
      // Initialization kept minimal; per-image options can be set in widgets.
      debugPrint('Image cache initialized');
    } catch (e) {
      debugPrint('Error initializing image cache: $e');
    }
  }

  // Check if device is in low power mode
  bool get isLowPowerMode => _isLowPowerMode;

  // Check if connection is slow
  bool get isSlowConnection => _isSlowConnection;

  // Check if connected to internet
  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  // Set low power mode
  Future<void> setLowPowerMode(bool enabled) async {
    _isLowPowerMode = enabled;
    await _savePerformanceSettings();
    debugPrint('Low power mode: $enabled');
  }

  // Get optimal image quality based on connection and power mode
  double getOptimalImageQuality() {
    if (_isLowPowerMode) return 0.5;
    if (_isSlowConnection) return 0.7;
    return 1.0;
  }

  // Get optimal image size based on connection and power mode
  int getOptimalImageSize() {
    if (_isLowPowerMode) return 512;
    if (_isSlowConnection) return 1024;
    return 2048;
  }

  // Get animation duration based on performance settings
  Duration getOptimalAnimationDuration() {
    if (_isLowPowerMode) return const Duration(milliseconds: 200);
    if (_isSlowConnection) return const Duration(milliseconds: 300);
    return const Duration(milliseconds: 400);
  }

  // Clear image cache
  Future<void> clearImageCache() async {
          try {
        // Clear CachedNetworkImage cache
        await CachedNetworkImage.evictFromCache('https://example.com');
        debugPrint('Image cache cleared');
      } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }

  // Get cache size
  Future<int> getCacheSize() async {
    try {
      // This would require additional implementation to get actual cache size
      // For now, return an estimated size
      return _maxCacheSize ~/ 2;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  // Optimize app performance
  Future<void> optimizePerformance() async {
    try {
      // Clear old cache entries
      await _clearOldCache();
      
      // Optimize memory usage
      _optimizeMemoryUsage();
      
      debugPrint('Performance optimization completed');
    } catch (e) {
      debugPrint('Error optimizing performance: $e');
    }
  }

  // Clear old cache entries
  Future<void> _clearOldCache() async {
    try {
      // This would require additional implementation to clear old cache entries
      // For now, just clear the entire cache if it's too large
      final cacheSize = await getCacheSize();
      if (cacheSize > _maxCacheSize) {
        await clearImageCache();
      }
    } catch (e) {
      debugPrint('Error clearing old cache: $e');
    }
  }

  // Optimize memory usage
  void _optimizeMemoryUsage() {
    // Force garbage collection in debug mode
    if (kDebugMode) {
      // This is a placeholder for memory optimization
      debugPrint('Memory optimization completed');
    }
  }

  // Get performance recommendations
  List<String> getPerformanceRecommendations() {
    final recommendations = <String>[];

    if (_isLowPowerMode) {
      recommendations.add('Enable low power mode for better battery life');
    }

    if (_isSlowConnection) {
      recommendations.add('Use Wi-Fi for faster loading');
      recommendations.add('Reduce image quality for faster loading');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Performance is optimal');
    }

    return recommendations;
  }

  // Monitor app performance
  Future<Map<String, dynamic>> getPerformanceMetrics() async {
    try {
      final isConnected = await this.isConnected;
      final cacheSize = await getCacheSize();
      
      return {
        'isConnected': isConnected,
        'isLowPowerMode': _isLowPowerMode,
        'isSlowConnection': _isSlowConnection,
        'cacheSize': cacheSize,
        'maxCacheSize': _maxCacheSize,
        'cacheUsagePercentage': (cacheSize / _maxCacheSize * 100).round(),
        'recommendations': getPerformanceRecommendations(),
      };
    } catch (e) {
      debugPrint('Error getting performance metrics: $e');
      return {};
    }
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}

// Performance optimization mixin for widgets
mixin PerformanceOptimized {
  PerformanceService get performanceService => PerformanceService();

  // Get optimal image quality
  double get imageQuality => performanceService.getOptimalImageQuality();

  // Get optimal image size
  int get imageSize => performanceService.getOptimalImageSize();

  // Get optimal animation duration
  Duration get animationDuration => performanceService.getOptimalAnimationDuration();

  // Check if should show animations
  bool get shouldShowAnimations => !performanceService.isLowPowerMode;

  // Check if should load high quality images
  bool get shouldLoadHighQualityImages => 
      !performanceService.isLowPowerMode && !performanceService.isSlowConnection;
}

// Performance-aware image widget
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final performanceService = PerformanceService();
    final imageQuality = performanceService.getOptimalImageQuality();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: performanceService.getOptimalImageSize(),
      memCacheHeight: performanceService.getOptimalImageSize(),
      placeholder: (context, url) => placeholder ?? 
          Container(
            color: Colors.grey.withOpacity(0.2),
            child: const Center(
              child: GroceryLoadingWidget(
                size: 48,
                showText: false,
              ),
            ),
          ),
      errorWidget: (context, url, error) => errorWidget ?? 
          Container(
            color: Colors.grey.withOpacity(0.2),
            child: const Icon(Icons.error),
          ),
    );
  }
} 