import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/deep_link_service.dart';

class TestPaymentFlowPage extends StatefulWidget {
  const TestPaymentFlowPage({super.key});

  @override
  State<TestPaymentFlowPage> createState() => _TestPaymentFlowPageState();
}

class _TestPaymentFlowPageState extends State<TestPaymentFlowPage> {
  final TextEditingController _orderIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set a default order ID for testing
    _orderIdController.text = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Payment Flow'),
        backgroundColor: const Color(0xFF6CA04A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Test Payment Completion Flow',
              style: GoogleFonts.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _orderIdController,
              decoration: const InputDecoration(
                labelText: 'Order ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () {
                final orderId = _orderIdController.text;
                if (orderId.isNotEmpty) {
                  // Simulate deep link
                  final deepLinkUrl = 'veggieconnect://order-success?orderId=$orderId&status=success';
                  print('Simulating deep link: $deepLinkUrl');
                  DeepLinkService.handleDeepLink(deepLinkUrl);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6CA04A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Simulate Payment Success Deep Link'),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () {
                // Test with a random order ID
                final orderId = DateTime.now().millisecondsSinceEpoch.toString();
                _orderIdController.text = orderId;
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Generate Random Order ID'),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Instructions:\n'
              '1. Enter an order ID (or use the random generator)\n'
              '2. Click "Simulate Payment Success Deep Link"\n'
              '3. This will test the deep link flow and order completion\n'
              '4. Check the console for debug information',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }
}
