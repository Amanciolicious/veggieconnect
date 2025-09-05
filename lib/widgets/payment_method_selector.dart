// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class PaymentMethodSelector extends StatefulWidget {
  final String? selectedMethod;
  final Function(String) onMethodSelected;

  const PaymentMethodSelector({
    super.key,
    this.selectedMethod,
    required this.onMethodSelected,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  String? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.selectedMethod;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            fontSize: isSmallScreen ? screenWidth * 0.045 : screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
            color: Colors.black87,
          ),
        ),
        SizedBox(height: screenWidth * 0.03),
        
        // Cash on Pickup
        _buildPaymentOption(
          'cash_on_pickup',
          'Cash on Pickup',
          'Pay when you collect your order',
          Icons.money,
          Colors.green,
          screenWidth,
          isSmallScreen,
        ),
        
        SizedBox(height: screenWidth * 0.02),
        
        // PayPal Sandbox
        _buildPaymentOption(
          'paypal_sandbox',
          'PayPal Sandbox',
          'Pay using PayPal Sandbox for testing',
          Icons.payment,
          Colors.blue,
          screenWidth,
          isSmallScreen,
        ),
      ],
    );
  }

  Widget _buildPaymentOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    double screenWidth,
    bool isSmallScreen,
  ) {
    final isSelected = _selectedMethod == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = value;
        });
        widget.onMethodSelected(value);
      },
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.05),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.06,
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
                      color: Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.06,
              ),
          ],
        ),
      ),
    );
  }
}
