// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'buyer_order_history_page.dart';

class DigitalReceiptPage extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems;
  final double total;
  final String paymentMethod;
  final String orderId;
  final double? discountAmount;
  final double? originalAmount;
  final bool? hasPromoApplied;
  final String? promoType;
  
  const DigitalReceiptPage({
    super.key, 
    required this.cartItems, 
    required this.total,
    required this.paymentMethod,
    required this.orderId,
    this.discountAmount,
    this.originalAmount,
    this.hasPromoApplied,
    this.promoType,
  });

  @override
  State<DigitalReceiptPage> createState() => _DigitalReceiptPageState();
}

class _DigitalReceiptPageState extends State<DigitalReceiptPage> {
  final ScreenshotController _screenshotController = ScreenshotController();

  String _generateOrderNumber() {
    return widget.orderId;
  }

  String _getPaymentMethodDisplayName() {
    switch (widget.paymentMethod.toLowerCase()) {
      case 'cash_on_pickup':
        return 'Cash on Pickup';
      case 'gcash':
        return 'GCash';
      case 'grab_pay':
        return 'GrabPay';
      case 'paymaya':
        return 'PayMaya';
      case 'card':
        return 'Credit/Debit Card';
      case 'online_payment':
        return 'Online Payment';
      default:
        return 'Online Payment';
    }
  }

  String _getPaymentMethodIcon() {
    switch (widget.paymentMethod.toLowerCase()) {
      case 'cash_on_pickup':
        return '💵';
      case 'gcash':
        return '💚';
      case 'grab_pay':
        return '🚗';
      case 'paymaya':
        return '💙';
      case 'card':
        return '💳';
      case 'online_payment':
        return '💳';
      default:
        return '💳';
    }
  }

  Future<void> _downloadReceipt() async {
    try {
      // Request storage permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
      
      // Check if any storage permission is granted
      bool hasStoragePermission = statuses[Permission.storage]?.isGranted == true ||
                                 statuses[Permission.manageExternalStorage]?.isGranted == true;
      
      if (!hasStoragePermission) {
        // Show dialog to guide user to settings
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Storage Permission Required'),
              content: Text(
                'To save receipts, please grant storage permission in your device settings.\n\n'
                'Go to Settings > Apps > VeggieConnect > Permissions > Storage and enable it.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Capture screenshot
      final image = await _screenshotController.capture();
      if (image == null) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture receipt'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get downloads directory
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to access downloads directory'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Generate filename
      final now = DateTime.now();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
      final filename = 'VeggieConnect_Receipt_${widget.orderId.substring(0, 8)}_$timestamp.png';
      final filePath = path.join(directory.path, filename);

      // Save file
      final file = File(filePath);
      await file.writeAsBytes(image);

      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt saved to Downloads: $filename'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
    final subtotal = widget.total;
    final shipping = 0.0;
    final orderStatus = 'Order Placed';
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Order Receipt',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Color(0xFFF8FAF5),
      body: Screenshot(
        controller: _screenshotController,
        child: SingleChildScrollView(
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
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.055,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      'Your order has been placed successfully.', 
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.04,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
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
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.w400,
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
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    ...widget.cartItems.map((item) {
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
                                    style: GoogleFonts.quicksand(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '${data['quantity']} ${data['unit']} × ₱${data['price']?.toStringAsFixed(2)}',
                                    style: GoogleFonts.quicksand(
                                      fontSize: screenWidth * 0.035,
                                      color: Color(0xFF757575),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '₱${((data['quantity'] ?? 0) * (data['price'] ?? 0)).toStringAsFixed(2)}',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.04,
                                  color: Color(0xFF6CA04A),
                                  fontWeight: FontWeight.w400,
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
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    _buildSummaryRow('Subtotal', '₱${(widget.originalAmount ?? widget.total).toStringAsFixed(2)}', screenWidth),
                    if (widget.hasPromoApplied == true && widget.discountAmount != null && widget.discountAmount! > 0) ...[
                      _buildSummaryRow('Discount (${widget.promoType ?? "Promo"})', '-₱${widget.discountAmount!.toStringAsFixed(2)}', screenWidth, valueColor: Colors.red),
                    ],
                    _buildSummaryRow('Shipping', shipping == 0 ? 'Free' : '₱${shipping.toStringAsFixed(2)}', screenWidth),
                    Divider(color: Color(0xFF8D9773).withOpacity(0.2)),
                    _buildSummaryRow('Total', '₱${widget.total.toStringAsFixed(2)}', screenWidth, isTotal: true),
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.06),
              
              // Action Buttons
              SizedBox(
                width: double.infinity,
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
                    style: GoogleFonts.quicksand(
                      fontSize: screenWidth * 0.04,
                      color: Color(0xFF6CA04A),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: screenWidth * 0.04),
              
              // Download Receipt Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _downloadReceipt,
                  icon: Icon(
                    Icons.download,
                    color: Colors.white,
                    size: screenWidth * 0.045,
                  ),
                  label: Text(
                    'Download Receipt',
                    style: GoogleFonts.quicksand(
                      fontSize: screenWidth * 0.04,

                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: screenWidth * 0.04),
              
              // Continue Shopping Button - appears after receipt generation
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
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text(
                    'Continue Shopping',
                    style: GoogleFonts.quicksand(
                      fontSize: screenWidth * 0.04,

                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: screenWidth * 0.04),
            ],
          ),
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
            style: GoogleFonts.quicksand(
              fontSize: screenWidth * 0.04,
              color: Color(0xFF757575),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.quicksand(
              fontSize: screenWidth * 0.04,
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, double screenWidth, {bool isTotal = false, Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.quicksand(
              fontSize: isTotal ? screenWidth * 0.045 : screenWidth * 0.04,
              color: isTotal ? Colors.black87 : Color(0xFF757575),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.quicksand(
              fontSize: isTotal ? screenWidth * 0.045 : screenWidth * 0.04,
              color: valueColor ?? (isTotal ? Color(0xFF6CA04A) : Colors.black87),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}