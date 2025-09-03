import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'farm_location_request_service.dart';

class FarmLocationCountdownService {
  static final FarmLocationCountdownService _instance = FarmLocationCountdownService._internal();
  factory FarmLocationCountdownService() => _instance;
  FarmLocationCountdownService._internal();

  final Map<String, Timer> _timers = {};
  final Map<String, StreamController<int>> _countdownControllers = {};
  final Map<String, int> _remainingTimes = {};
  final FarmLocationRequestService _requestService = FarmLocationRequestService();

  /// Start a 2-minute countdown for a pending farm location request
  void startCountdown(String requestId) {
    // Cancel existing timer if any
    cancelCountdown(requestId);
    
    const int totalSeconds = 120; // 2 minutes
    _remainingTimes[requestId] = totalSeconds;
    
    // Create stream controller for countdown updates
    _countdownControllers[requestId] = StreamController<int>.broadcast();
    
    // Start the timer
    _timers[requestId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingTimes[requestId] = (_remainingTimes[requestId] ?? 0) - 1;
      final remainingSeconds = _remainingTimes[requestId] ?? 0;
      
      // Emit the remaining seconds
      _countdownControllers[requestId]?.add(remainingSeconds);
      
      if (remainingSeconds <= 0) {
        // Timer finished, automatically approve the farm location request
        _autoApproveFarmLocation(requestId);
        cancelCountdown(requestId);
      }
    });
    
    debugPrint('⏰ Started 2-minute countdown for farm location request $requestId');
  }

  /// Cancel countdown for a specific request
  void cancelCountdown(String requestId) {
    _timers[requestId]?.cancel();
    _timers.remove(requestId);
    _countdownControllers[requestId]?.close();
    _countdownControllers.remove(requestId);
    _remainingTimes.remove(requestId);
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

  /// Get countdown stream for a request
  Stream<int>? getCountdownStream(String requestId) {
    return _countdownControllers[requestId]?.stream;
  }

  /// Check if a countdown is active for a request
  bool isCountdownActive(String requestId) {
    return _timers.containsKey(requestId);
  }

  /// Get remaining time for a request (in seconds)
  int? getRemainingTime(String requestId) {
    return _remainingTimes[requestId];
  }

  /// Automatically approve a farm location request when countdown reaches zero
  Future<void> _autoApproveFarmLocation(String requestId) async {
    try {
      debugPrint('✅ Auto-approving farm location request $requestId after countdown completion');
      
      // Use the existing auto-approval service
      await _requestService.processAutoApprovals();
      
      debugPrint('✅ Farm location request $requestId automatically approved after countdown');
      
    } catch (e) {
      debugPrint('💥 Error auto-approving farm location request $requestId: $e');
    }
  }

  /// Start countdown for all pending farm location requests
  void startCountdownForPendingRequests() async {
    try {
      final pendingRequests = await FirebaseFirestore.instance
          .collection('farm_location_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in pendingRequests.docs) {
        final requestId = doc.id;
        final requestData = doc.data();
        
        // Only start countdown if not already active and request is still pending
        if (!isCountdownActive(requestId) && requestData['status'] == 'pending') {
          startCountdown(requestId);
        }
      }
      
      debugPrint('⏰ Started countdowns for ${pendingRequests.docs.length} pending farm location requests');
    } catch (e) {
      debugPrint('💥 Error starting countdowns for pending farm location requests: $e');
    }
  }

  /// Start countdown for a specific request if it's pending
  void startCountdownIfPending(String requestId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('farm_location_requests')
          .doc(requestId)
          .get();
      
      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        if (requestData['status'] == 'pending' && !isCountdownActive(requestId)) {
          startCountdown(requestId);
        }
      }
    } catch (e) {
      debugPrint('💥 Error checking if request $requestId is pending: $e');
    }
  }

  /// Dispose of all resources
  void dispose() {
    cancelAllCountdowns();
  }
}
