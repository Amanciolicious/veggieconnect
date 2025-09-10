// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/paymongo_gcash_service.dart';

class PayMongoTestPage extends StatefulWidget {
  const PayMongoTestPage({super.key});

  @override
  State<PayMongoTestPage> createState() => _PayMongoTestPageState();
}

class _PayMongoTestPageState extends State<PayMongoTestPage> {
  bool _isProcessing = false;
  String? _lastResult;

  Future<void> _testPayMongoPayment() async {
    setState(() {
      _isProcessing = true;
      _lastResult = null;
    });

    try {
      final result = await PayMongoGCashService.processPayment(
        context: context,
        amount: 200.00, // ₱200.00 test amount
        orderId: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        description: 'PayMongo Test Payment',
        cartItems: const [], // Empty cart for test
      );

      setState(() {
        _isProcessing = false;
        _lastResult = result?.success == true 
            ? '✅ Payment initiated successfully!\nCheckout URL: ${result?.checkoutUrl}'
            : '❌ Payment failed: ${result?.error ?? 'Unknown error'}';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _lastResult = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6CA04A),
        title: Text(
          'PayMongo Test',
          style: GoogleFonts.quicksand(
            fontSize: screenWidth * 0.055,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test Info Card
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF8D9773).withOpacity(0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PayMongo Integration Test',
                    style: GoogleFonts.quicksand(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6CA04A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This will test the complete PayMongo payment flow:\n'
                    '• Creates PayMongo Checkout Session\n'
                    '• Opens PayMongo checkout page\n'
                    '• Shows GCash payment options\n'
                    '• Handles payment authorization',
                    style: GoogleFonts.quicksand(
                      fontSize: screenWidth * 0.04,
                      color: const Color(0xFF757575),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6CA04A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF6CA04A).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF6CA04A),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Test Amount: ₱200.00\nThis is a test payment using PayMongo test environment.',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.035,
                              color: const Color(0xFF6CA04A),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Test Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _testPayMongoPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6CA04A),
                padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isProcessing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Testing PayMongo...',
                          style: GoogleFonts.quicksand(
                            fontSize: screenWidth * 0.045,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Test PayMongo Payment',
                          style: GoogleFonts.quicksand(
                            fontSize: screenWidth * 0.045,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // Result Display
            if (_lastResult != null)
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lastResult!.startsWith('✅') 
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastResult!.startsWith('✅') 
                              ? Icons.check_circle
                              : Icons.error,
                          color: _lastResult!.startsWith('✅') 
                              ? Colors.green
                              : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Test Result',
                          style: GoogleFonts.quicksand(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w600,
                            color: _lastResult!.startsWith('✅') 
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _lastResult!,
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.04,
                        color: const Color(0xFF757575),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
