// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/webhook_service.dart';

class PaymentStatusChecker extends StatefulWidget {
  final String orderId;
  final String? sourceId;
  final VoidCallback? onStatusUpdated;

  const PaymentStatusChecker({
    super.key,
    required this.orderId,
    this.sourceId,
    this.onStatusUpdated,
  });

  @override
  State<PaymentStatusChecker> createState() => _PaymentStatusCheckerState();
}

class _PaymentStatusCheckerState extends State<PaymentStatusChecker> {
  final WebhookService _webhookService = WebhookService();
  bool _isChecking = false;
  Map<String, dynamic>? _paymentStatus;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPaymentStatus();
  }

  Future<void> _checkPaymentStatus() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      // First, try to get status from Firestore
      final statusResult = await _webhookService.getOrderPaymentStatus(widget.orderId);

      if (statusResult['success']) {
        setState(() {
          _paymentStatus = statusResult;
          _isChecking = false;
        });

        // If we have a source ID and status is pending, try to verify with Paymongo
        if (widget.sourceId != null && 
            statusResult['payment_status'] == 'pending') {
          await _verifyWithPaymongo();
        }

        // Call callback if status was updated
        widget.onStatusUpdated?.call();
      } else {
        setState(() {
          _error = statusResult['error'];
          _isChecking = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to check payment status: $e';
        _isChecking = false;
      });
    }
  }

  Future<void> _verifyWithPaymongo() async {
    if (widget.sourceId == null) return;

    try {
      final verifyResult = await _webhookService.verifyPaymentStatusWithPaymongo(
        sourceId: widget.sourceId!,
        orderId: widget.orderId,
      );

      if (verifyResult['success']) {
        setState(() {
          _paymentStatus = verifyResult;
        });

        // Call callback if status was updated
        widget.onStatusUpdated?.call();
      }
    } catch (e) {
      debugPrint('Paymongo verification error: $e');
    }
  }

  String _getStatusDisplayText() {
    if (_paymentStatus == null) return 'Unknown';
    
    final status = _paymentStatus!['payment_status'];
    switch (status) {
      case 'paid':
        return 'Payment Completed';
      case 'pending':
        return 'Payment Pending';
      case 'failed':
        return 'Payment Failed';
      case 'cancelled':
        return 'Payment Cancelled';
      default:
        return 'Unknown Status';
    }
  }

  Color _getStatusColor() {
    if (_paymentStatus == null) return Colors.grey;
    
    final status = _paymentStatus!['payment_status'];
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (_paymentStatus == null) return Icons.help_outline;
    
    final status = _paymentStatus!['payment_status'];
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'failed':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Payment Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isChecking)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Order ID
            Row(
              children: [
                const Text(
                  'Order ID: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  widget.orderId,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payment Status
            if (_paymentStatus != null) ...[
              Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusDisplayText(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Payment Method
              if (_paymentStatus!['payment_method'] != null)
                Row(
                  children: [
                    const Text(
                      'Payment Method: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(_paymentStatus!['payment_method']),
                  ],
                ),

              // Last Updated
              if (_paymentStatus!['last_updated'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Last Updated: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _formatTimestamp(_paymentStatus!['last_updated']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],

            // Error Message
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkPaymentStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Status'),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.sourceId != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _verifyWithPaymongo,
                      icon: const Icon(Icons.verified),
                      label: const Text('Verify with Paymongo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            // Instructions for external payment
            if (_paymentStatus != null && 
                _paymentStatus!['payment_status'] == 'pending') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Payment Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If you completed the payment in your browser, please wait a few minutes for the status to update. '
                      'You can also click "Verify with Paymongo" to check the status immediately.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate().toString().split('.')[0];
      } else if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return date.toString().split('.')[0];
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
} 