// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:veggieconnect/authentication/login_page.dart';
import 'package:veggieconnect/admin-side/admin_dashboard.dart';
import 'package:veggieconnect/supplier-side/supplier_dashboard.dart';
import 'package:veggieconnect/customer-side/onboarding_page.dart';

class PinVerifyPage extends StatefulWidget {
  final String userId;
  final String email;
  const PinVerifyPage({super.key, required this.userId, required this.email});

  @override
  State<PinVerifyPage> createState() => _PinVerifyPageState();
}

class _PinVerifyPageState extends State<PinVerifyPage> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _secondsLeft = 300;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_tick);
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;
    setState(() {
      _secondsLeft = 300 - elapsed.inSeconds;
      if (_secondsLeft <= 0) {
        _ticker.stop();
        _secondsLeft = 0;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final data = doc.data();
      if (data == null) throw Exception('User not found');
      final pin = data['pin'] as String?;
      final expiresAt = (data['pinExpiresAt'] as Timestamp?)?.toDate();
      if (_pinController.text.trim() != pin) {
        setState(() {
          _errorMessage = 'Incorrect PIN.';
          _isLoading = false;
        });
        return;
      }
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _errorMessage = 'PIN expired. Please request a new one.';
          _isLoading = false;
        });
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'verified': true});
      if (!mounted) return;
      // Check user role and route accordingly
      final updatedDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final updatedData = updatedDoc.data();
      final userRole = updatedData != null ? updatedData['role'] ?? 'buyer' : 'buyer';
      final isNewlyRegistered = updatedData != null ? updatedData['isNewlyRegistered'] ?? false : false;
      final onboardingCompleted = updatedData != null ? updatedData['onboardingCompleted'] ?? false : false;
      
      if (userRole == 'admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AdminDashboard()),
          (route) => false,
        );
      } else if (userRole == 'supplier') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => SupplierDashboard()),
          (route) => false,
        );
      } else {
        // For buyers, check if they need onboarding
        if (isNewlyRegistered && !onboardingCompleted) {
          // Show onboarding for newly registered users
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => OnboardingPage(userId: widget.userId)),
            (route) => false,
          );
        } else {
          // Go to login page for existing users
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => LoginPage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed.';
        _isLoading = false;
      });
    }
  }

  Future<void> sendPinEmail(String email, String pin) async {
    const serviceId = 'your_service_id';
    const templateId = 'your_template_id';
    const userId = 'your_user_id';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': userId,
        'template_params': {
          'to_email': email,
          'pin': pin,
        },
      }),
    );
    if (response.statusCode == 200) {
      print('PIN email sent!');
    } else {
      print('Failed to send PIN email: \\${response.body}');
    }
  }

  Future<void> _resendPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Generate new PIN
      final newPin = (Random().nextInt(90000) + 10000).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'pin': newPin,
        'pinExpiresAt': expiresAt,
      });
      await sendPinEmail(widget.email, newPin);
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _secondsLeft = 300;
      });
      _ticker.stop();
      _ticker.start();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new PIN has been sent to your email!')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to resend PIN.';
      });
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        title: Text(
          'Verify PIN',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.security,
                      size: 80,
                      color: Color(0xFF6CA04A),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter Your PIN',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please enter your 5-digit PIN to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // PIN Input
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // PIN Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _pinController.text.length > index ? Color(0xFF6CA04A) : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _pinController.text.length > index ? '●' : '',
                              style: TextStyle(
                                fontSize: 24,
                                color: Color(0xFF6CA04A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    // Number Pad
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          return Container(); // Empty space
                        } else if (index == 10) {
                          return _buildNumberButton('0');
                        } else if (index == 11) {
                          return _buildBackspaceButton();
                        } else {
                          return _buildNumberButton('${index + 1}');
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _pinController.text.length == 5 ? _verifyPin : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6CA04A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                )
                              : Text(
                                  'Verify PIN',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _pinController.text += number;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF6CA04A).withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Color(0xFF6CA04A).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6CA04A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_pinController.text.isNotEmpty) {
            _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.red,
            size: 24,
          ),
        ),
      ),
    );
  }
}