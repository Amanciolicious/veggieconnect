// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veggieconnect/models/promo_model.dart';
import 'digital_receipt_page.dart';
import '../services/payment_service.dart';
import '../services/promo_service.dart';
import '../services/notification_service.dart';
import '../widgets/payment_status_checker.dart';
// Added for debugPrint

class CheckoutSummaryPage extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems;
  const CheckoutSummaryPage({super.key, required this.cartItems});

  @override
  State<CheckoutSummaryPage> createState() => _CheckoutSummaryPageState();
}

class _CheckoutSummaryPageState extends State<CheckoutSummaryPage> {
  bool isProcessing = false;
  String selectedPaymentMethod = 'cash_on_pickup';
  String selectedOnlineMethod = 'gcash'; // Default online payment method
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
      case 'paymaya':
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
        return 'Online Payment - GCash';
      case 'paymaya':
        return 'Online Payment - PayMaya';
      default:
        return 'Unknown Method';
    }
  }

  String _getPaymentMethodSubtitle(String method) {
    switch (method) {
      case 'cash_on_pickup':
        return 'Pay on Pickup';
      case 'gcash':
      case 'paymaya':
        return 'Secure Online Payment';
      default:
        return 'Payment Method';
    }
  }

  Future<String?> _showPaymentMethodDialog() async {
    String tempMethod = selectedPaymentMethod;
    String tempOnlineMethod = selectedOnlineMethod;
    
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
                    Text('', style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    const Text('Cash on Pickup'),
                  ],
                ),
                subtitle: const Text(
                  'Pay on Pickup',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
              
              // Online Payment Option
              RadioListTile<String>(
                value: 'online_payment',
                groupValue: tempMethod,
                onChanged: (val) => setState(() => tempMethod = val!),
                title: Row(
                  children: [
                    Text('', style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    const Text('Online Payment'),
                  ],
                ),
                subtitle: const Text(
                  'Secure Online Payment',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ),
              
              // Online Payment Method Dropdown (only show if online payment is selected)
              if (tempMethod == 'online_payment') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Online Payment Method:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: tempOnlineMethod,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'gcash',
                            child: Row(
                              children: [
                                Text('', style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                const Text('GCash'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'paymaya',
                            child: Row(
                              children: [
                                Text('', style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                const Text('PayMaya'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => tempOnlineMethod = value!),
                      ),
                    ],
                  ),
                ),
              ],
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
              // Return the appropriate payment method
              String finalMethod = tempMethod;
              if (tempMethod == 'online_payment') {
                finalMethod = tempOnlineMethod;
              }
              Navigator.pop(context, finalMethod);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (isProcessing) return;

    setState(() => isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final total = _calculateTotal();
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create orders in Firestore
      final batch = FirebaseFirestore.instance.batch();
      final ordersRef = FirebaseFirestore.instance.collection('orders');

      for (final doc in widget.cartItems) {
        final data = doc.data();
        final orderDoc = ordersRef.doc();
        final itemTotal = (data['price'] ?? 0) * (data['quantity'] ?? 1);
        
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

        batch.set(orderDoc, {
          'buyerId': user.uid,
          'productId': data['productId'],
          'sellerId': data['sellerId'],
          'productName': data['name'],
          'quantity': data['quantity'],
          'unit': data['unit'],
          'price': data['price'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'paymentMethod': selectedPaymentMethod,
          'paymentStatus': selectedPaymentMethod == 'cash_on_pickup' ? 'pending' : 'unpaid',
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

      // Commit the batch first to create all orders
      await batch.commit();

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

      // Process payment based on method
      Map<String, dynamic> paymentResult;

      if (selectedPaymentMethod == 'cash_on_pickup') {
        // For cash on pickup, orders are already created with payment info
        // Just return success since no additional processing is needed
        paymentResult = {
          'success': true,
          'payment_method': 'cash_on_pickup',
          'payment_status': 'pending',
          'order_id': orderId,
        };
      } else {
        // Process online payment (GCash/PayMaya) with external browser
        try {
          // Get user information for payment
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          
          final userData = userDoc.data() ?? {};
          final customerName = userData['name'] ?? 'Customer';
          final customerEmail = userData['email'] ?? 'customer@example.com';

          // Use the new external payment method for GCash/PayMaya
          if (_paymentService.requiresExternalBrowser(selectedPaymentMethod)) {
            // Test Paymongo connection first
            debugPrint('Testing Paymongo connection before creating payment...');
            final connectionTest = await _paymentService.testPaymongoConnection();
            
            debugPrint('Connection test result: $connectionTest');
            debugPrint('Connection test success: ${connectionTest['success']}');
            
            if (!connectionTest['success']) {
              debugPrint('Paymongo connection failed: ${connectionTest['error']}');
              // Show connection error and fallback to cash on pickup
              if (mounted) {
                final shouldFallback = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Payment Service Unavailable'),
                    content: Text(
                      'Online payment service is currently unavailable.\n\n'
                      'Error: ${connectionTest['error']}\n'
                      'Details: ${connectionTest['details']}\n\n'
                      'Would you like to proceed with Cash on Pickup instead?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Use Cash on Pickup'),
                      ),
                    ],
                  ),
                );

                if (shouldFallback == true) {
                  selectedPaymentMethod = 'cash_on_pickup';
                  paymentResult = {
                    'success': true,
                    'payment_method': 'cash_on_pickup',
                    'payment_status': 'pending',
                    'order_id': orderId,
                  };
                  
                } else {
                  throw Exception('Payment cancelled by user');
                }
              }
            }

            debugPrint('Paymongo connection successful, creating external payment intent...');
            
            // Calculate final amount with promo discount
            double finalAmount = _calculateTotal();
            if (_applyPromo && _hasAvailablePromo && _customerPromo != null && !_customerPromo!.hasUsedFirstTimePromo) {
              final promoDiscount = PromoService.calculateFirstTimeDiscount(_calculateTotal(), true);
              if (promoDiscount != null) {
                finalAmount = promoDiscount.finalAmount;
              }
            }

            paymentResult = await _paymentService.createExternalPaymentIntent(
            amount: finalAmount,
            currency: 'PHP',
            paymentMethod: selectedPaymentMethod,
            orderId: orderId,
            customerEmail: customerEmail,
            customerName: customerName,
            metadata: {
              'buyer_id': user.uid,
              'order_type': 'cart_checkout',
            },
          );

            if (paymentResult['success'] && paymentResult['redirect_url'] != null) {
              // Show confirmation dialog for external browser redirect
              if (mounted) {
                final shouldRedirect = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: Text('Complete Payment with ${_getPaymentMethodDisplayName(selectedPaymentMethod)}'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You will be redirected to ${_getPaymentMethodDisplayName(selectedPaymentMethod)} in your browser to complete the payment.',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment Details:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Amount: ₱${_calculateFinalTotal().toStringAsFixed(2)}'),
                              Text('Order ID: $orderId'),
                              Text('Payment Method: ${_getPaymentMethodDisplayName(selectedPaymentMethod)}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '⚠️ Important: Please complete the payment in your browser and return to the app.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.payment),
                        label: Text('Pay with ${_getPaymentMethodDisplayName(selectedPaymentMethod)}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldRedirect == true) {
                  // Launch external browser for payment
                  final launchResult = await _paymentService.launchExternalPayment(
                    redirectUrl: paymentResult['redirect_url'],
                    orderId: orderId,
                    paymentMethod: selectedPaymentMethod,
                  );

                  if (launchResult['success']) {
                    // Show success message and instructions
                    if (mounted) {
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: const Text('Payment Gateway Opened'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your payment gateway has been opened in your browser.',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Next Steps:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 8),
                                    Text('1. Complete payment in your browser'),
                                    Text('2. Return to this app'),
                                    Text('3. Check your order status'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Update payment result to indicate external redirect
                  paymentResult = {
                    'success': true,
                    'payment_method': selectedPaymentMethod,
                    'payment_status': 'pending',
                    'order_id': orderId,
                      'payment_intent_id': paymentResult['payment_intent_id'],
                      'external_redirect': true,
                      'message': 'Payment gateway opened in external browser',
                  };
                  } else {
                    throw Exception(launchResult['error']);
                  }
                } else {
                  throw Exception('Payment cancelled by user');
                }
              }
            } else {
              throw Exception(paymentResult['error']);
            }
          } else {
            // Fallback to legacy payment method for other payment types
            paymentResult = await _paymentService.processOnlinePayment(
              amount: _calculateFinalTotal(),
              currency: 'PHP',
              paymentMethod: selectedPaymentMethod,
              orderId: orderId,
              customerEmail: customerEmail,
              customerName: customerName,
              metadata: {
                'buyer_id': user.uid,
                'order_type': 'cart_checkout',
              },
            );
          }
        } catch (e) {
            // If online payment fails, fall back to cash on pickup
            if (mounted) {
              final shouldFallback = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Payment Method Unavailable'),
                  content: Text(
                    'Online payment (${_getPaymentMethodDisplayName(selectedPaymentMethod)}) is currently unavailable. '
                  'Would you like to proceed with Cash on Pickup instead?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Use Cash on Pickup'),
                  ),
                ],
              ),
            );

            if (shouldFallback == true) {
              // Update the payment method to cash on pickup
              selectedPaymentMethod = 'cash_on_pickup';
              paymentResult = {
                'success': true,
                'payment_method': 'cash_on_pickup',
                'payment_status': 'pending',
                'order_id': orderId,
              };
            } else {
              throw Exception('Payment failed: $e');
            }
          } else {
            throw Exception('Payment failed: $e');
          }
        }
      }

      if (paymentResult['success']) {
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

        // Send payment confirmation notification to customer
        await notificationService.sendFCMNotification(
          recipientId: user.uid,
          title: 'Order Confirmed',
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
          // Check if this was an external browser payment
          if (paymentResult['external_redirect'] == true) {
            // Show payment status checker for external payments
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Payment Initiated'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your payment has been initiated in your browser. Please complete the payment and return to check the status.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    PaymentStatusChecker(
                      orderId: orderId,
                      sourceId: paymentResult['payment_intent_id'],
                      onStatusUpdated: () {
                        // Refresh the page or show updated status
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DigitalReceiptPage(
                            cartItems: widget.cartItems,
                            total: _calculateFinalTotal(),
                            paymentMethod: selectedPaymentMethod,
                            orderId: orderId,
                          ),
                        ),
                      );
                    },
                    child: const Text('View Receipt'),
                  ),
                ],
              ),
            );
          } else {
            // For cash on pickup or other immediate payments, go directly to receipt
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DigitalReceiptPage(
                cartItems: widget.cartItems,
                total: _calculateFinalTotal(),
                paymentMethod: selectedPaymentMethod,
                orderId: orderId,
              ),
            ),
          );
          }
        }
      } else {
        throw Exception(paymentResult['error']);
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

    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Order Summary',
          style: TextStyle(
            fontSize: screenWidth * 0.055,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
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
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
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
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: screenWidth * 0.01),
                                  Text(
                                    '₱${data['price']?.toStringAsFixed(2) ?? '0.00'} × ${data['quantity'] ?? 1}',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Color(0xFF757575),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₱${itemTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6CA04A),
                                fontFamily: 'Poppins',
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
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                  color: _customerPromo!.hasUsedFirstTimePromo ? Colors.grey : Colors.orange,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                _customerPromo!.hasUsedFirstTimePromo 
                                  ? 'Promo Used'
                                  : 'Get 40% off your first order!',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: _customerPromo!.hasUsedFirstTimePromo ? Colors.grey : Colors.orange,
                                  fontFamily: 'Poppins',
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
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
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
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
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
                              _getPaymentMethodIcon(selectedPaymentMethod == 'online_payment' ? selectedOnlineMethod : selectedPaymentMethod),
                              style: TextStyle(fontSize: screenWidth * 0.06),
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPaymentMethodDisplayName(selectedPaymentMethod == 'online_payment' ? selectedOnlineMethod : selectedPaymentMethod),
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  Text(
                                    _getPaymentMethodSubtitle(selectedPaymentMethod == 'online_payment' ? selectedOnlineMethod : selectedPaymentMethod),
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Color(0xFF757575),
                                      fontFamily: 'Poppins',
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
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.03),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal:',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          '₱${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontFamily: 'Poppins',
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
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              color: Colors.orange,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          Text(
                            '-₱${discount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              color: Colors.orange,
                              fontFamily: 'Poppins',
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
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          '₱${finalTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6CA04A),
                            fontFamily: 'Poppins',
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Place Order',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}