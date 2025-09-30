// ignore_for_file: avoid_print, deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veggieconnect/customer-side/customer_contact_info_page.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:veggieconnect/services/promo_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, this.onLoginTap});
  final VoidCallback? onLoginTap;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthdayController = TextEditingController();
  DateTime? _selectedBirthday;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'buyer';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> sendPinEmail(String email, String pin) async {
    const serviceId = 'service_iuouffm';
    const templateId = 'template_n68ct9l';
    const userId = 'LU5nqmNiQgb_vus3a';

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

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Generate 5-digit PIN
      final pin = (Random().nextInt(90000) + 10000).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));
      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'pin': pin,
        'pinExpiresAt': expiresAt,
        'verified': false,
        'isNewlyRegistered': true, // Track newly registered users
        'onboardingCompleted': false, // Track onboarding completion
      });
      // Initialize customer promo for new customers
      if (_selectedRole == 'buyer') {
        await PromoService.initializeCustomerPromo(credential.user!.uid);
      }
      // Send PIN email notification
      await sendPinEmail(_emailController.text.trim(), pin);
      if (!mounted) return;
      
      // All users go to contact info page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ContactInfoPage(userId: credential.user!.uid),
        ),
      );
    } on FirebaseAuthException {
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text = "${picked.month}/${picked.day}/${picked.year}";
      });
    }
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
          'Sign Up',
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
            child: IntrinsicHeight(
          child: Form(
            key: _formKey,
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
                          Icons.person_add,
                          size: 35,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Title
                    Center(
                      child: Text(
                        'Create Your Account',
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
                        'Join VeggieConnect and start your fresh produce journey today.',
                  textAlign: TextAlign.center,
                        style: GoogleFonts.quicksand(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 32),

                // Role Selection
                    Text(
                      'Account Type',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                Container(
                  decoration: BoxDecoration(
                        color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: Text(
                          'Buyer',
                              style: GoogleFonts.quicksand(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                        ),
                        subtitle: Text(
                          'Purchase fresh produce',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                        ),
                        value: 'buyer',
                        groupValue: _selectedRole,
                            activeColor: Color(0xFF4CAF50),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                      ),
                          Divider(height: 1, color: Colors.grey[300]),
                      RadioListTile<String>(
                        title: Text(
                          'Supplier',
                              style: GoogleFonts.quicksand(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                        ),
                        subtitle: Text(
                          'Sell your fresh produce',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                        ),
                        value: 'supplier',
                        groupValue: _selectedRole,
                            activeColor: Color(0xFF4CAF50),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                    
                SizedBox(height: 20),

                    // Username Field
                    Text(
                      'Username',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                TextFormField(
                  controller: _nameController,
                      enabled: !_isLoading,
                  decoration: InputDecoration(
                        hintText: 'Enter your username',
                        hintStyle: GoogleFonts.quicksand(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.grey[800],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                    
                    SizedBox(height: 20),

                // Email Field
                    Text(
                      'Email Address',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                  decoration: InputDecoration(
                        hintText: 'Enter your email address',
                        hintStyle: GoogleFonts.quicksand(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.grey[800],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                    
                    SizedBox(height: 20),

                // Password Field
                    Text(
                      'Password',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                      enabled: !_isLoading,
                  decoration: InputDecoration(
                        hintText: 'Enter your password',
                        hintStyle: GoogleFonts.quicksand(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey[400],
                            size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.grey[800],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                    
                    SizedBox(height: 20),

                // Birthday Field
                    Text(
                      'Birthday',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                TextFormField(
                  controller: _birthdayController,
                  readOnly: true,
                      enabled: !_isLoading,
                      onTap: _selectBirthday,
                  decoration: InputDecoration(
                        hintText: 'Select your birthday',
                        hintStyle: GoogleFonts.quicksand(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                        prefixIcon: Icon(
                          Icons.cake_outlined,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        suffixIcon: Icon(
                          Icons.calendar_today,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your birthday';
                    }
                    return null;
                  },
                ),
                    
                    SizedBox(height: 28),

                // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
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
                                'Create Account',
                                style: GoogleFonts.quicksand(
                            fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                ),
                    
                SizedBox(height: 20),

                // Login Link
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : widget.onLoginTap,
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                  children: [
                              TextSpan(
                                text: 'Sign In',
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                        ),
                      ),
                    ),
                    
                    Expanded(child: SizedBox(height: 20)),
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VegieConnect Home'),
        backgroundColor: Color(0xFF6CA04A),
      ),
      body: const Center(
        child: Text('Welcome to VegieConnect!'),
      ),
    );
  }
}