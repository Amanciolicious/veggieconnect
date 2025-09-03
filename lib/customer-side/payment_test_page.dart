import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../services/paymongo_config.dart';

class PaymentTestPage extends StatefulWidget {
  const PaymentTestPage({super.key});

  @override
  State<PaymentTestPage> createState() => _PaymentTestPageState();
}

class _PaymentTestPageState extends State<PaymentTestPage> {
  final PaymentService _paymentService = PaymentService();
  Map<String, dynamic>? _connectionResult;
  Map<String, dynamic>? _paymentResult;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionResult = null;
    });

    try {
      final result = await _paymentService.testPaymongoConnection();
      setState(() {
        _connectionResult = result;
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _connectionResult = {
          'success': false,
          'error': 'Test failed',
          'details': e.toString(),
        };
        _isTesting = false;
      });
    }
  }

  Future<void> _testPayment() async {
    setState(() {
      _isTesting = true;
      _paymentResult = null;
    });

    try {
      final result = await _paymentService.createExternalPaymentIntent(
        amount: 100.0,
        currency: 'PHP',
        paymentMethod: 'gcash',
        orderId: 'test_order_${DateTime.now().millisecondsSinceEpoch}',
        customerEmail: 'test@example.com',
        customerName: 'Test Customer',
      );

      setState(() {
        _paymentResult = result;
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _paymentResult = {
          'success': false,
          'error': 'Payment test failed',
          'details': e.toString(),
        };
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Configuration Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paymongo Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Environment: ${PaymongoConfig.environment}'),
                    Text('Base URL: ${PaymongoConfig.baseUrl}'),
                    Text('Secret Key: ${PaymongoConfig.secretKey.substring(0, 10)}...'),
                    Text('Public Key: ${PaymongoConfig.publicKey.substring(0, 10)}...'),
                    Text('Is Configured: ${PaymongoConfig.isConfigured}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    child: const Text('Test Connection'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _testPayment,
                    child: const Text('Test Payment'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Connection Test Result
            if (_connectionResult != null) ...[
              Card(
                color: _connectionResult!['success'] ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Test Result',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _connectionResult!['success'] ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Success: ${_connectionResult!['success']}'),
                      if (_connectionResult!['error'] != null)
                        Text('Error: ${_connectionResult!['error']}'),
                      if (_connectionResult!['details'] != null)
                        Text('Details: ${_connectionResult!['details']}'),
                      if (_connectionResult!['message'] != null)
                        Text('Message: ${_connectionResult!['message']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Payment Test Result
            if (_paymentResult != null) ...[
              Card(
                color: _paymentResult!['success'] ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Test Result',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _paymentResult!['success'] ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Success: ${_paymentResult!['success']}'),
                      if (_paymentResult!['error'] != null)
                        Text('Error: ${_paymentResult!['error']}'),
                      if (_paymentResult!['details'] != null)
                        Text('Details: ${_paymentResult!['details']}'),
                      if (_paymentResult!['redirect_url'] != null)
                        Text('Redirect URL: ${_paymentResult!['redirect_url']}'),
                      if (_paymentResult!['source_id'] != null)
                        Text('Source ID: ${_paymentResult!['source_id']}'),
                    ],
                  ),
                ),
              ),
            ],

            if (_isTesting) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 