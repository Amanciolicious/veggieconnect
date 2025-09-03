// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'buyer_order_history_page.dart';

class DigitalReceiptPage extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems;
  final double total;
  final String paymentMethod;
  final String orderId;
  
  const DigitalReceiptPage({
    super.key, 
    required this.cartItems, 
    required this.total,
    required this.paymentMethod,
    required this.orderId,
  });

  String _generateOrderNumber() {
    return orderId;
  }

  String _getPaymentMethodDisplayName() {
    switch (paymentMethod) {
      case 'cash_on_pickup':
        return 'Cash on Pickup';
      case 'gcash':
        return 'GCash';
      case 'paymaya':
        return 'PayMaya';
      case 'credit_card':
        return 'Credit Card';
      default:
        return 'Unknown Payment Method';
    }
  }

  String _getPaymentMethodIcon() {
    switch (paymentMethod) {
      case 'cash_on_pickup':
        return '💵';
      case 'gcash':
        return '📱';
      case 'paymaya':
        return '💳';
      case 'credit_card':
        return '💳';
      default:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final orderNumber = _generateOrderNumber();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd – kk:mm').format(now);
    final paymentMethodDisplay = _getPaymentMethodDisplayName();
    final paymentIcon = _getPaymentMethodIcon();
    final subtotal = total;
    final shipping = 0.0;
    final orderStatus = 'Order Placed';
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Order Receipt',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Color(0xFFF8FAF5),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success Header
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle, 
                      size: screenWidth * 0.18, 
                      color: Color(0xFF6CA04A),
                    ),
                    SizedBox(height: screenWidth * 0.02),
                    Text(
                      'Thank you for your purchase!', 
                      style: TextStyle(
                        fontSize: screenWidth * 0.055,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      'Your order has been placed successfully.', 
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Color(0xFF757575),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.06),
              
              // Order Details Card
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
                      'Order Details',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    _buildDetailRow('Order Number', orderNumber.substring(0, 8).toUpperCase(), screenWidth),
                    _buildDetailRow('Date & Time', dateStr, screenWidth),
                    _buildDetailRow('Status', orderStatus, screenWidth, valueColor: Color(0xFF6CA04A)),
                    _buildDetailRow('Payment Method', '$paymentIcon $paymentMethodDisplay', screenWidth),
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.06),
              
              // Items Card
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
                      'Order Items',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    ...cartItems.map((item) {
                      final data = item.data();
                      return Container(
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFF8D9773).withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? '',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '${data['quantity']} ${data['unit']} × ₱${data['price']?.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Color(0xFF757575),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '₱${((data['quantity'] ?? 0) * (data['price'] ?? 0)).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6CA04A),
                                  fontFamily: 'Poppins',
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.06),
              
              // Order Summary Card
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
                      'Order Summary',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    _buildSummaryRow('Subtotal', '₱${subtotal.toStringAsFixed(2)}', screenWidth),
                    _buildSummaryRow('Shipping', shipping == 0 ? 'Free' : '₱${shipping.toStringAsFixed(2)}', screenWidth),
                    Divider(color: Color(0xFF8D9773).withOpacity(0.2)),
                    _buildSummaryRow('Total', '₱${total.toStringAsFixed(2)}', screenWidth, isTotal: true),
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.06),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Color(0xFF6CA04A), width: 2),
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => BuyerOrderHistoryPage()),
                        );
                      },
                      child: Text(
                        'View Orders',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6CA04A),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6CA04A),
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: Text(
                        'Continue Shopping',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: screenWidth * 0.04),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, double screenWidth, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              color: Color(0xFF757575),
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, double screenWidth, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? screenWidth * 0.045 : screenWidth * 0.04,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black87 : Color(0xFF757575),
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? screenWidth * 0.045 : screenWidth * 0.04,
              fontWeight: FontWeight.bold,
              color: isTotal ? Color(0xFF6CA04A) : Colors.black87,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}