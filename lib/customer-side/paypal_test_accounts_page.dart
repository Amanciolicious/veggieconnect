// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/paypal_sandbox_service.dart';

class PayPalTestAccountsPage extends StatelessWidget {
  const PayPalTestAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 720;
    final testAccounts = PayPalSandboxService.getTestAccountInfo();

    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'PayPal Test Accounts',
          style: GoogleFonts.quicksand(
            fontSize: isSmallScreen ? screenWidth * 0.045 : screenWidth * 0.05,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: screenWidth * 0.06),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Text(
                      'Use these PayPal Sandbox test accounts to simulate payments',
                      style: GoogleFonts.quicksand(
                        fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: screenWidth * 0.04),
            
            // Test Account Information
            Text(
              'Test Account Credentials',
              style: GoogleFonts.quicksand(
                fontSize: isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.055,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
            
            SizedBox(height: screenWidth * 0.03),
            
            // Buyer Account
            _buildAccountCard(
              'Buyer Account',
              testAccounts['Buyer Email']!,
              testAccounts['Password']!,
              Icons.person,
              Colors.green,
              screenWidth,
              isSmallScreen,
              context,
            ),
            
            SizedBox(height: screenWidth * 0.03),
            
            // Seller Account
            _buildAccountCard(
              'Seller Account',
              testAccounts['Seller Email']!,
              testAccounts['Password']!,
              Icons.store,
              Colors.orange,
              screenWidth,
              isSmallScreen,
              context,
            ),
            
            SizedBox(height: screenWidth * 0.04),
            
            // Instructions
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.grey[700]),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        'How to Test Payments',
                        style: GoogleFonts.quicksand(
                          fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  _buildInstructionStep(
                    '1',
                    'Select "Pay with GCash" or "Pay with PayMaya" in checkout',
                    screenWidth,
                    isSmallScreen,
                  ),
                  _buildInstructionStep(
                    '2',
                    'PayPal Sandbox checkout page will open in your browser',
                    screenWidth,
                    isSmallScreen,
                  ),
                  _buildInstructionStep(
                    '3',
                    'Use the buyer account credentials to log in',
                    screenWidth,
                    isSmallScreen,
                  ),
                  _buildInstructionStep(
                    '4',
                    'Complete the payment (use demo balance)',
                    screenWidth,
                    isSmallScreen,
                  ),
                  _buildInstructionStep(
                    '5',
                    'Return to app and confirm payment completion',
                    screenWidth,
                    isSmallScreen,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: screenWidth * 0.04),
            
            // Demo Balance Info
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.green),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        'Demo Balance',
                        style: GoogleFonts.quicksand(
                          fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                          fontWeight: FontWeight.w400,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  Text(
                    'Both test accounts have unlimited demo balance for testing purposes. No real money is involved in sandbox transactions.',
                    style: GoogleFonts.quicksand(
                      fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
                      fontWeight: FontWeight.w400,
                      color: Colors.green[700],
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

  Widget _buildAccountCard(
    String title,
    String email,
    String password,
    IconData icon,
    Color color,
    double screenWidth,
    bool isSmallScreen,
    BuildContext context,
  ) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: screenWidth * 0.05),
              SizedBox(width: screenWidth * 0.03),
              Text(
                title,
                style: GoogleFonts.quicksand(
                  fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.03),
          _buildCredentialField(
            'Email',
            email,
            screenWidth,
            isSmallScreen,
            context,
          ),
          SizedBox(height: screenWidth * 0.02),
          _buildCredentialField(
            'Password',
            password,
            screenWidth,
            isSmallScreen,
            context,
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialField(
    String label,
    String value,
    double screenWidth,
    bool isSmallScreen,
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: GoogleFonts.quicksand(
              fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
              fontWeight: FontWeight.w400,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.03,
              vertical: screenWidth * 0.02,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: GoogleFonts.quicksand(
                fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        SizedBox(width: screenWidth * 0.02),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied to clipboard'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.02),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.copy,
              size: screenWidth * 0.04,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(
    String stepNumber,
    String instruction,
    double screenWidth,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenWidth * 0.02),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: screenWidth * 0.06,
            height: screenWidth * 0.06,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Text(
              instruction,
              style: GoogleFonts.quicksand(
                fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
                fontWeight: FontWeight.w400,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
