// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import '../authentication/pin_verify_page.dart';
import 'package:flutter/material.dart';

class ContactInfoPage extends StatefulWidget {
  final String userId;
  const ContactInfoPage({super.key, required this.userId});

  @override
  State<ContactInfoPage> createState() => _ContactInfoPageState();
}

class _ContactInfoPageState extends State<ContactInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _postalController = TextEditingController();
  final _streetController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _postalController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _saveContactInfo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'country': _countryController.text.trim(),
        'city': _cityController.text.trim(),
        'province': _provinceController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'postalCodeAlt': _postalController.text.trim(),
        'streetAddress': _streetController.text.trim(),
      });
      setState(() {
        _successMessage = 'Contact information saved! Redirecting to verification...';
        _isLoading = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      // Fetch email from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final email = userDoc.data()?['email'] ?? '';
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => PinVerifyPage(userId: widget.userId, email: email)),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save contact info.';
        _isLoading = false;
      });
    }
  }

  Future<void> _skipContactInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch email from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final email = userDoc.data()?['email'] ?? '';
      
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => PinVerifyPage(userId: widget.userId, email: email)),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to skip contact info.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Contact Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.06),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(0xFF8D9773).withOpacity(0.08),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      screenWidth: screenWidth,
                      validator: (value) => value?.isEmpty == true ? 'Full name is required' : null,
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: 'Enter your phone number',
                      screenWidth: screenWidth,
                      keyboardType: TextInputType.phone,
                      validator: (value) => value?.isEmpty == true ? 'Phone number is required' : null,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.06),
              
              Container(
                padding: EdgeInsets.all(screenWidth * 0.06),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(0xFF8D9773).withOpacity(0.08),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Address Information',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    _buildTextField(
                      controller: _streetController,
                      label: 'Street Address',
                      hint: 'Enter your street address',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City',
                            hint: 'Enter city',
                            screenWidth: screenWidth,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: _buildTextField(
                            controller: _provinceController,
                            label: 'Province',
                            hint: 'Enter province',
                            screenWidth: screenWidth,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _countryController,
                            label: 'Country',
                            hint: 'Enter country',
                            screenWidth: screenWidth,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: _buildTextField(
                            controller: _postalCodeController,
                            label: 'Postal Code',
                            hint: 'Enter postal code',
                            screenWidth: screenWidth,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    _buildTextField(
                      controller: _addressController,
                      label: 'Complete Address',
                      hint: 'Enter your complete address',
                      screenWidth: screenWidth,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.06),
              
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  margin: EdgeInsets.only(bottom: screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              
              if (_successMessage != null)
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  margin: EdgeInsets.only(bottom: screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Color(0xFF6CA04A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF6CA04A).withOpacity(0.3)),
                  ),
                  child: Text(
                    _successMessage!,
                    style: TextStyle(
                      color: Color(0xFF6CA04A),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6CA04A),
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _saveContactInfo,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color?>(Colors.white),
                          ),
                        )
                      : Text(
                          'Save & Continue',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                ),
              ),
              
              SizedBox(height: screenWidth * 0.04),
              
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : _skipContactInfo,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Color(0xFF757575),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required double screenWidth,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFF8FAF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFF8D9773).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: hint,
              hintStyle: TextStyle(
                color: Color(0xFF757575),
                fontFamily: 'Poppins',
              ),
            ),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.04,
            ),
          ),
        ),
      ],
    );
  }
}