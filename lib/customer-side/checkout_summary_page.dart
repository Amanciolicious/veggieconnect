// ignore_for_file: deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:veggieconnect/models/promo_model.dart';
import '../services/payment_service.dart';
import 'payment_processing_page.dart';
import 'digital_receipt_page.dart';
import '../services/promo_service.dart';
import '../services/notification_service.dart';
// Added for debugPrint

class CheckoutSummaryPage extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems;
  final String? selectedPaymentMethod;
  const CheckoutSummaryPage({super.key, required this.cartItems, this.selectedPaymentMethod});

  @override
  State<CheckoutSummaryPage> createState() => _CheckoutSummaryPageState();
}

class _CheckoutSummaryPageState extends State<CheckoutSummaryPage> {
  bool isProcessing = false;
  String selectedPaymentMethod = 'cash_on_pickup';
  final PaymentService _paymentService = PaymentService();
  Map<String, String> availablePaymentMethods = {};
  bool _hasAvailablePromo = false;
  bool _applyPromo = false;
  CustomerPromo? _customerPromo;

  @override
  void initState() {
    super.initState();
    availablePaymentMethods = _paymentService.getPaymentMethods();
    _checkPromoAvailability();
    
    // Set the selected payment method from the passed parameter
    if (widget.selectedPaymentMethod != null) {
      selectedPaymentMethod = widget.selectedPaymentMethod!;
    }
  }

  Future<void> _checkPromoAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final hasPromo = await PromoService.hasAvailableFirstTimePromo(user.uid);
      final customerPromo = await PromoService.getCustomerPromo(user.uid);
      setState(() {
        _hasAvailablePromo = hasPromo;
        _customerPromo = customerPromo;
      });
    }
  }

  double _calculateTotal() {
    double total = 0;
    for (final doc in widget.cartItems) {
      final data = doc.data();
      total += (data['price'] ?? 0) * (data['quantity'] ?? 1);
    }
    return total;
  }

  double _calculateDiscountAmount() {
    if (!_applyPromo || !_hasAvailablePromo) return 0.0;
    final total = _calculateTotal();
    return total * 0.4; // 40% discount
  }

  double _calculateFinalTotal() {
    final total = _calculateTotal();
    final discount = _calculateDiscountAmount();
    return total - discount;
  }

  String _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'cash_on_pickup':
        return '';
      case 'gcash':
        return '';
      default:
        return '';
    }
  }

  String _getPaymentMethodDisplayName(String method) {
    switch (method) {
      case 'cash_on_pickup':
        return 'Cash on Pickup';
      case 'gcash':
        return 'GCash';
      default:
        return 'Unknown Method';
    }
  }

  String _getPaymentMethodSubtitle(String method) {
    switch (method) {
      case 'cash_on_pickup':
        return 'Pay on Pickup';
      case 'gcash':
        return 'Secure Online Payment';
      default:
        return 'Payment Method';
    }
  }

  Future<String?> _showPaymentMethodDialog() async {
    String tempMethod = selectedPaymentMethod;
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Payment Method'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cash on Pickup Option
              RadioListTile<String>(
                value: 'cash_on_pickup',
                groupValue: tempMethod,
                onChanged: (val) => setState(() => tempMethod = val!),
                title: Row(
                  children: [
                    Text('💵', style: GoogleFonts.quicksand(fontSize: 20)),
                    const SizedBox(width: 8),
                    const Text('Cash on Pickup'),
                  ],
                ),
                subtitle: Text(
                  'Pay on Pickup',
                  style: GoogleFonts.quicksand(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
              
              // GCash Option
              RadioListTile<String>(
                value: 'gcash',
                groupValue: tempMethod,
                onChanged: (val) => setState(() => tempMethod = val!),
                title: Row(
                  children: [
                    Text('💳', style: GoogleFonts.quicksand(fontSize: 20)),
                    const SizedBox(width: 8),
                    const Text('GCash'),
                  ],
                ),
                subtitle: Text(
                  'Pay with GCash',
                  style: GoogleFonts.quicksand(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, tempMethod);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    // Debug entrypoint
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing order...')),
      );
    }
    // Confirm before placing order to avoid misclicks
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place Order?'),
        content: const Text('Do you want to place this order now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Place Order')),
        ],
      ),
    );
    if (confirm != true) return;
    if (isProcessing) return;

    setState(() => isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      // Resolve buyer name for supplier views
      String buyerName = user.displayName ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          buyerName = (userDoc.data() as Map<String, dynamic>)['name'] ?? buyerName;
        }
      } catch (_) {}

      final total = _calculateTotal();
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      // Calculate discount if promo is applied
      double finalAmount = total;
      double discountAmount = 0;
      if (_applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo) {
        final promoDiscount = PromoService.calculateFirstTimeDiscount(total, true);
        if (promoDiscount != null) {
          finalAmount = promoDiscount.finalAmount;
          discountAmount = promoDiscount.discountAmount;
        }
      }

      // Handle payment based on method
      if (selectedPaymentMethod == 'gcash') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Redirecting to GCash...')),
          );
        }
        // For GCash, navigate to payment processing page WITHOUT creating orders yet
        // Orders will be created by webhook after successful payment
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentProcessingPage(
              cartItems: widget.cartItems,
              total: finalAmount,
              paymentMethod: selectedPaymentMethod,
              orderId: orderId,
              discountAmount: discountAmount,
              originalAmount: total,
              hasPromoApplied: _applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo,
              promoType: (_applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo) ? 'First Time Customer' : null,
            ),
          ),
        );
        return;
      }

      // For cash_on_pickup, create orders immediately since no online payment is required
      // Create orders in Firestore
      final batch = FirebaseFirestore.instance.batch();
      final ordersRef = FirebaseFirestore.instance.collection('orders');

      for (final doc in widget.cartItems) {
        final data = doc.data();
        final orderDoc = ordersRef.doc();
        final itemTotal = (data['price'] ?? 0) * (data['quantity'] ?? 1);

        batch.set(orderDoc, {
          'buyerId': user.uid,
          'buyerName': buyerName,
          'productId': data['productId'],
          'sellerId': data['sellerId'],
          'productName': data['name'],
          'quantity': data['quantity'],
          'unit': data['unit'],
          'price': data['price'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'paymentMethod': selectedPaymentMethod,
          'paymentStatus': 'pending', // Cash on pickup is always pending
          'paymentAmount': finalAmount,
          'originalAmount': total,
          'discountAmount': discountAmount,
          'hasPromoApplied': _applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo,
          'promoType': (_applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo) ? 'First Time Customer' : null,
          'paymentDate': FieldValue.serverTimestamp(),
          'imageUrl': data['imageUrl'],
          'supplierName': data['supplierName'],
          'orderId': orderId,
          'totalAmount': finalAmount,
        });
      }

      // Commit the batch to create all orders
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully')), 
        );
      }

      // Send notifications to suppliers about new orders
      final notificationService = NotificationService();
      final suppliers = <String, String>{}; // supplierId -> supplierName
      
      for (final doc in widget.cartItems) {
        final data = doc.data();
        final supplierId = data['sellerId'] as String?;
        final supplierName = data['supplierName'] as String?;
        
        if (supplierId != null && supplierName != null) {
          suppliers[supplierId] = supplierName;
        }
      }
      
      // Send notification to each supplier
      for (final entry in suppliers.entries) {
        await notificationService.sendFCMNotification(
          recipientId: entry.key,
          title: 'New Order Received',
          body: 'You have received a new order #$orderId',
          type: 'order_update',
          data: {
            'orderId': orderId,
            'status': 'pending',
            'screen': 'orders',
          },
        );
      }

      // For all methods, finalize: mark promo used, clear cart, and go back to cart page
      {
        // Mark first-time promo as used if it was applied
        if (_applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo) {
          try {
            await PromoService.markFirstTimePromoAsUsed(user.uid);
            print('First-time promo marked as used for customer: ${user.uid}');
            
            // Send promo usage notification
            await notificationService.sendFCMNotification(
              recipientId: user.uid,
              title: 'Promo Applied Successfully',
              body: 'Your first-time customer discount has been applied to this order',
              type: 'promo',
              data: {
                'orderId': orderId,
                'promoType': 'first_time_customer',
                'screen': 'order_details',
              },
            );
          } catch (e) {
            print('Failed to mark promo as used: $e');
            // Don't fail the entire order if promo marking fails
          }
        }

        // Send order confirmation notification to customer
        await notificationService.sendFCMNotification(
          recipientId: user.uid,
          title: 'Order Placed',
          body: 'Your order #$orderId has been placed successfully',
          type: 'order_update',
          data: {
            'orderId': orderId,
            'status': 'pending',
            'screen': 'order_details',
          },
        );

        // Clear cart
        final cartBatch = FirebaseFirestore.instance.batch();
        for (final doc in widget.cartItems) {
          cartBatch.delete(FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('cart')
              .doc(doc.id));
        }

        await cartBatch.commit();

        if (mounted) {
          // Navigate to digital receipt page instead of showing modal
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DigitalReceiptPage(
                cartItems: widget.cartItems,
                total: finalAmount,
                paymentMethod: selectedPaymentMethod,
                orderId: orderId,
                discountAmount: discountAmount,
                originalAmount: total,
                hasPromoApplied: _applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo,
                promoType: (_applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo) ? 'First Time Customer' : null,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final total = _calculateTotal();
    final discount = _calculateDiscountAmount();
    final finalTotal = _calculateFinalTotal();

    return HeroMode(
      enabled: false,
      child: Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Order Summary',
          style: GoogleFonts.quicksand(
            fontSize: screenWidth * 0.055,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Items Section
            Container(
              margin: EdgeInsets.only(bottom: screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
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
                    SizedBox(height: screenWidth * 0.03),
                    ...widget.cartItems.map((doc) {
                      final data = doc.data();
                      final itemTotal = (data['price'] ?? 0) * (data['quantity'] ?? 1);
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: screenWidth * 0.03),
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        decoration: BoxDecoration(
                          color: Color(0xFF6CA04A).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: screenWidth * 0.15,
                              height: screenWidth * 0.15,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[100],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: data['imageUrl'] != null && data['imageUrl'].isNotEmpty
                                    ? Image.network(
                                        data['imageUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.shopping_basket,
                                            color: Color(0xFF6CA04A),
                                            size: screenWidth * 0.06,
                                          );
                                        },
                                      )
                                    : Icon(
                                        Icons.shopping_basket,
                                        color: Color(0xFF6CA04A),
                                        size: screenWidth * 0.06,
                                      ),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? 'Unknown Product',
                                    style: GoogleFonts.quicksand(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  SizedBox(height: screenWidth * 0.01),
                                  Text(
                                    '₱${data['price']?.toStringAsFixed(2) ?? '0.00'} × ${data['quantity'] ?? 1}',
                                    style: GoogleFonts.quicksand(
                                      fontSize: screenWidth * 0.035,
                                      color: Color(0xFF757575),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₱${itemTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.quicksand(
                                fontSize: screenWidth * 0.04,
                                color: Color(0xFF6CA04A),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // First Time User Discount Section
            if (_customerPromo != null) ...[
              Container(
                margin: EdgeInsets.only(bottom: screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _customerPromo!.hasUsedFirstTimePromo ? Icons.check_circle : Icons.local_offer,
                          color: _customerPromo!.hasUsedFirstTimePromo ? Colors.grey : Colors.orange,
                          size: screenWidth * 0.06,
                        ),
                        SizedBox(width: screenWidth * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _customerPromo!.hasUsedFirstTimePromo 
                                  ? 'First Time User Discount - Used'
                                  : 'First Time User Discount',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.04,
                                  color: _customerPromo!.hasUsedFirstTimePromo ? Colors.grey : Colors.orange,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                _customerPromo!.hasUsedFirstTimePromo 
                                  ? 'Promo Used'
                                  : 'Get 40% off your first order!',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.035,
                                  color: _customerPromo!.hasUsedFirstTimePromo ? Colors.grey : Colors.orange,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_customerPromo!.hasUsedFirstTimePromo)
                          Switch(
                            value: _applyPromo,
                            onChanged: (value) {
                              setState(() {
                                _applyPromo = value;
                              });
                            },
                            activeColor: Colors.orange,
                          )
                        else
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenWidth * 0.015,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Used',
                              style: GoogleFonts.quicksand(
                                fontSize: screenWidth * 0.03,
                                color: Colors.grey,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            )],

            // Payment Method Section
            Container(
              margin: EdgeInsets.only(bottom: screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.03),
                    GestureDetector(
                      onTap: () async {
                        final newMethod = await _showPaymentMethodDialog();
                        if (newMethod != null) {
                          setState(() {
                            selectedPaymentMethod = newMethod;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: Color(0xFF6CA04A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(0xFF6CA04A).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _getPaymentMethodIcon(selectedPaymentMethod),
                              style: GoogleFonts.quicksand(fontSize: screenWidth * 0.06),
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPaymentMethodDisplayName(selectedPaymentMethod),
                                    style: GoogleFonts.quicksand(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    _getPaymentMethodSubtitle(selectedPaymentMethod),
                                    style: GoogleFonts.quicksand(
                                      fontSize: screenWidth * 0.035,
                                      color: Color(0xFF757575),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.edit,
                              color: Color(0xFF6CA04A),
                              size: screenWidth * 0.05,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Order Summary Section
            Container(
              margin: EdgeInsets.only(bottom: screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
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
                    SizedBox(height: screenWidth * 0.03),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal:',
                          style: GoogleFonts.quicksand(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '₱${total.toStringAsFixed(2)}',
                          style: GoogleFonts.quicksand(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    if (_applyPromo && discount > 0) ...[
                      SizedBox(height: screenWidth * 0.02),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount (40%):',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.04,
                              color: Colors.orange,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            '-₱${discount.toStringAsFixed(2)}',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.04,
                              color: Colors.orange,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                    Divider(height: screenWidth * 0.06),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: GoogleFonts.quicksand(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '₱${finalTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.quicksand(
                            fontSize: screenWidth * 0.05,
                            color: Color(0xFF6CA04A),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6CA04A),
              padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: isProcessing ? null : _processPayment,
            child: isProcessing
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color?>(Colors.white),
                    ),
                  )
                : Text(
                    'Place Order',
                    style: GoogleFonts.quicksand(
                      fontSize: screenWidth * 0.045,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ),
        ),
      ),
    ));
  }
}