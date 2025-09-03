import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auto_approval_service.dart';

class CountdownTimerService {
  static final CountdownTimerService _instance = CountdownTimerService._internal();
  factory CountdownTimerService() => _instance;
  CountdownTimerService._internal();

  final Map<String, Timer> _timers = {};
  final Map<String, StreamController<int>> _countdownControllers = {};
  final Map<String, int> _remainingTimes = {};
  final AutoApprovalService _autoApprovalService = AutoApprovalService();

  /// Start a 2-minute countdown for a pending product
  void startCountdown(String productId) {
    // Cancel existing timer if any
    cancelCountdown(productId);
    
    const int totalSeconds = 120; // 2 minutes
    _remainingTimes[productId] = totalSeconds;
    
    // Create stream controller for countdown updates
    _countdownControllers[productId] = StreamController<int>.broadcast();
    
    // Start the timer
    _timers[productId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingTimes[productId] = (_remainingTimes[productId] ?? 0) - 1;
      final remainingSeconds = _remainingTimes[productId] ?? 0;
      
      // Emit the remaining seconds
      _countdownControllers[productId]?.add(remainingSeconds);
      
      if (remainingSeconds <= 0) {
        // Timer finished, automatically approve the product
        _autoApproveProduct(productId);
        cancelCountdown(productId);
      }
    });
    
    debugPrint('⏰ Started 2-minute countdown for product $productId');
  }

  /// Cancel countdown for a specific product
  void cancelCountdown(String productId) {
    _timers[productId]?.cancel();
    _timers.remove(productId);
    _countdownControllers[productId]?.close();
    _countdownControllers.remove(productId);
    _remainingTimes.remove(productId);
  }

  /// Cancel all countdowns
  void cancelAllCountdowns() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    
    for (var controller in _countdownControllers.values) {
      controller.close();
    }
    _countdownControllers.clear();
    _remainingTimes.clear();
  }

  /// Get countdown stream for a product
  Stream<int>? getCountdownStream(String productId) {
    return _countdownControllers[productId]?.stream;
  }

  /// Check if a countdown is active for a product
  bool isCountdownActive(String productId) {
    return _timers.containsKey(productId);
  }

  /// Get remaining time for a product (in seconds)
  int? getRemainingTime(String productId) {
    return _remainingTimes[productId];
  }

  /// Automatically approve a product when countdown reaches zero
  Future<void> _autoApproveProduct(String productId) async {
    try {
      debugPrint('✅ Auto-approving product $productId after countdown completion');
      
      // Use the existing manual approval service
      await _autoApprovalService.manualApproveProduct(productId);
      
      debugPrint('✅ Product $productId automatically approved after countdown');
      
    } catch (e) {
      debugPrint('💥 Error auto-approving product $productId: $e');
    }
  }

  /// Start countdown for all pending products
  void startCountdownForPendingProducts() async {
    try {
      final pendingProducts = await FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in pendingProducts.docs) {
        final productId = doc.id;
        final productData = doc.data();
        
        // Only start countdown if not already active and product is still pending
        if (!isCountdownActive(productId) && productData['status'] == 'pending') {
          startCountdown(productId);
        }
      }
      
      debugPrint('⏰ Started countdowns for ${pendingProducts.docs.length} pending products');
    } catch (e) {
      debugPrint('💥 Error starting countdowns for pending products: $e');
    }
  }

  /// Dispose of all resources
  void dispose() {
    cancelAllCountdowns();
  }
} 