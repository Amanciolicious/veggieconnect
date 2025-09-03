import 'dart:async';
import 'package:flutter/foundation.dart';
import 'farm_location_request_service.dart';

class FarmAutoApprovalService {
  static final FarmAutoApprovalService _instance = FarmAutoApprovalService._internal();
  factory FarmAutoApprovalService() => _instance;
  FarmAutoApprovalService._internal();

  final FarmLocationRequestService _requestService = FarmLocationRequestService();
  Timer? _autoApprovalTimer;
  bool _isRunning = false;

  // Start the auto-approval service
  void startAutoApprovalService() {
    if (_isRunning) return;

    _isRunning = true;
    
    // Process auto-approvals every 15 seconds for faster response
    _autoApprovalTimer = Timer.periodic(Duration(seconds: 15), (timer) async {
      try {
        await _requestService.processAutoApprovals();
        if (kDebugMode) {
          print('Farm auto-approval check completed at ${DateTime.now()}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Farm auto-approval check failed: $e');
        }
      }
    });

    if (kDebugMode) {
      print('Farm auto-approval service started');
    }
  }

  // Stop the auto-approval service
  void stopAutoApprovalService() {
    _autoApprovalTimer?.cancel();
    _autoApprovalTimer = null;
    _isRunning = false;
    
    if (kDebugMode) {
      print('Farm auto-approval service stopped');
    }
  }

  // Check if the service is running
  bool get isRunning => _isRunning;

  // Manual trigger for auto-approvals (useful for testing)
  Future<void> triggerAutoApprovals() async {
    try {
      await _requestService.processAutoApprovals();
      if (kDebugMode) {
        print('Manual farm auto-approval trigger completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Manual farm auto-approval trigger failed: $e');
      }
      rethrow;
    }
  }
}
