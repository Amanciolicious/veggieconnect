// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:veggieconnect/customer-side/customer_dashboard.dart';
import 'package:veggieconnect/admin-side/admin_dashboard.dart';
import 'package:veggieconnect/supplier-side/supplier_dashboard.dart';
import 'package:veggieconnect/customer-side/customer_onboarding_page.dart';
import '../services/auth_state_service.dart';
import 'package:google_fonts/google_fonts.dart';

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
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final data = doc.data();
      if (data == null) throw Exception('User not found');
      final pin = data['pin'] as String?;
      final expiresAt = (data['pinExpiresAt'] as Timestamp?)?.toDate();
      if (_pinController.text.trim() != pin) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'verified': true});
      if (!mounted) return;
      
      // Get updated user data after verification
      final updatedDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final updatedData = updatedDoc.data();
      final userRole = updatedData != null ? updatedData['role'] ?? 'buyer' : 'buyer';
      final isNewlyRegistered = updatedData != null ? updatedData['isNewlyRegistered'] ?? false : false;
      final onboardingCompleted = updatedData != null ? updatedData['onboardingCompleted'] ?? false : false;
      
      // Authenticate the user in AuthStateService before navigation
      if (updatedData != null) {
        await AuthStateService().setFirestoreAuthUser(widget.userId, updatedData);
        print('PIN Verification: User authenticated in AuthStateService - ID: ${widget.userId}');
      }
      
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
          // Already verified/registered buyers go straight into the app
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const CustomerHomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.grey[700],
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Verify PIN',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         kToolbarHeight - 48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  SizedBox(height: 20),
                  
                  // Header Icon
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.security,
                        size: 35,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Title
                  Center(
                    child: Text(
                      'Enter Verification PIN',
                      style: GoogleFonts.quicksand(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 10),
                  
                  // Subtitle
                  Center(
                    child: Text(
                      'Please enter the 5-digit PIN sent to your email address.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  // PIN Display
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _pinController.text.length > index ? Color(0xFF4CAF50) : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _pinController.text.length > index ? '●' : '',
                              style: GoogleFonts.quicksand(
                                fontSize: 24,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Number Pad
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
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
                  
                  SizedBox(height: 28),
                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _pinController.text.length == 5 ? _verifyPin : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Verify PIN',
                              style: GoogleFonts.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Resend PIN Info
                  Center(
                    child: Text(
                      'Resend PIN in ${_formatTime(_secondsLeft)}',
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Resend Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _resendPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Resend PIN',
                        style: GoogleFonts.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  ],
                ),
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
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: GoogleFonts.quicksand(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
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
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red[200]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.red[600],
            size: 24,
          ),
        ),
      ),
    );
  }
}