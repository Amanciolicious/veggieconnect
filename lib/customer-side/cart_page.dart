// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:veggieconnect/customer-side/buyer_products_page.dart';
import 'package:veggieconnect/customer-side/checkout_summary_page.dart'; // Added import for CheckoutSummaryPage

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? get user => _auth.currentUser;
  late CollectionReference<Map<String, dynamic>> _cartRef;
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'cash_on_pickup';
  String _selectedOnlineMethod = 'gcash'; // Default online payment method

  @override
  void initState() {
    super.initState();
    _cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart');
  }

  Future<void> _updateQuantity(String docId, int newQty) async {
    if (newQty > 0) {
      await _cartRef.doc(docId).update({'quantity': newQty});
    } else {
      await _cartRef.doc(docId).delete();
    }
  }

  Future<void> _removeItem(String docId) async {
    await _cartRef.doc(docId).delete();
  }

  double _calculateTotal(List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems) {
    double total = 0;
    for (final doc in cartItems) {
      final data = doc.data();
      total += (data['price'] ?? 0) * (data['quantity'] ?? 1);
    }
    return total;
  }

  Future<String?> _showPaymentMethodDialog() async {
    String tempMethod = _selectedPaymentMethod;
    String tempOnlineMethod = _selectedOnlineMethod;
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Payment Method', style: TextStyle(fontSize: 12),),
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
                    Text('💵', style: const TextStyle(fontSize: 20)),
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
                    Text('💳', style: const TextStyle(fontSize: 20)),
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
                                Text('📱', style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                const Text('GCash'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'paymaya',
                            child: Row(
                              children: [
                                Text('💳', style: const TextStyle(fontSize: 16)),
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

  Future<void> _checkout(List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems) async {
    if (cartItems.isEmpty || _isProcessing) return;
    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;
    setState(() {
      _isProcessing = true;
      _selectedPaymentMethod = paymentMethod;
      // Update the online method if it's an online payment
      if (paymentMethod == 'gcash' || paymentMethod == 'paymaya') {
        _selectedOnlineMethod = paymentMethod;
      }
    });
    // Confirm before placing order to avoid misclicks
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place Order?'),
        content: const Text('Do you want to place the order for all items in your cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Place Order')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      // Resolve buyer name for supplier views
      String buyerName = user!.displayName ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        if (userDoc.exists) {
          buyerName = (userDoc.data() as Map<String, dynamic>)['name'] ?? buyerName;
        }
      } catch (_) {}
      final ordersRef = FirebaseFirestore.instance.collection('orders');
      for (final doc in cartItems) {
        final data = doc.data();
        batch.set(ordersRef.doc(), {
          'buyerId': user!.uid,
          'buyerName': buyerName,
          'productId': data['productId'],
          'sellerId': data['sellerId'],
          'productName': data['name'],
          'quantity': data['quantity'],
          'unit': data['unit'],
          'price': data['price'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'paymentMethod': paymentMethod,
          'paymentStatus': paymentMethod == 'cash_on_pickup' ? 'pending' : 'unpaid',
        });
        batch.delete(_cartRef.doc(doc.id));
      }
      await batch.commit();
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Order placed!'),
            content: Text('Payment method: ${_getPaymentMethodDisplayName(paymentMethod)}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Stay on cart
                },
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => BuyerProductsPage()),
                    (route) => false,
                  );
                },
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'My Cart',
          style: TextStyle(
            fontSize: screenWidth * 0.055,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        elevation: 0,
      ),
      body: user == null
          ? Center(
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.08),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      size: screenWidth * 0.15,
                      color: Color(0xFF6CA04A),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    Text(
                      'Please Login',
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6CA04A),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.02),
                    Text(
                      'You need to be logged in to view your cart',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Color(0xFF757575),
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _cartRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color?>(Color(0xFF6CA04A)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.all(screenWidth * 0.08),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: screenWidth * 0.15,
                            color: Color(0xFF6CA04A),
                          ),
                          SizedBox(height: screenWidth * 0.04),
                          Text(
                            'Your Cart is Empty',
                            style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6CA04A),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text(
                            'Add some products to get started',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              color: Color(0xFF757575),
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final cartItems = snapshot.data!.docs;
                final total = _calculateTotal(cartItems);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final doc = cartItems[index];
                          final data = doc.data();
                          final itemTotal = (data['price'] ?? 0) * (data['quantity'] ?? 1);

                          return Container(
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
                              child: Row(
                                children: [
                                  // Product Image
                                  Container(
                                    width: screenWidth * 0.2,
                                    height: screenWidth * 0.2,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey[100],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: data['imageUrl'] != null && data['imageUrl'].isNotEmpty
                                          ? Image.network(
                                              data['imageUrl'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.shopping_basket,
                                                  color: Color(0xFF6CA04A),
                                                  size: screenWidth * 0.08,
                                                );
                                              },
                                            )
                                          : Icon(
                                              Icons.shopping_basket,
                                              color: Color(0xFF6CA04A),
                                              size: screenWidth * 0.08,
                                            ),
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.04),
                                  // Product Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? 'Unknown Product',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.045,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Poppins',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: screenWidth * 0.01),
                                        Text(
                                          '₱${data['price']?.toStringAsFixed(2) ?? '0.00'}',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.04,
                                            color: Color(0xFF6CA04A),
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        SizedBox(height: screenWidth * 0.02),
                                        Row(
                                          children: [
                                            // Quantity Controls
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Color(0xFF6CA04A).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _updateQuantity(doc.id, (data['quantity'] ?? 1) - 1),
                                                    child: Container(
                                                      padding: EdgeInsets.all(8),
                                                      child: Icon(
                                                        Icons.remove,
                                                        size: 16,
                                                        color: Color(0xFF6CA04A),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    child: Text(
                                                      '${data['quantity'] ?? 1}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'Poppins',
                                                      ),
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () => _updateQuantity(doc.id, (data['quantity'] ?? 1) + 1),
                                                    child: Container(
                                                      padding: EdgeInsets.all(8),
                                                      child: Icon(
                                                        Icons.add,
                                                        size: 16,
                                                        color: Color(0xFF6CA04A),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Spacer(),
                                            // Remove Button
                                            GestureDetector(
                                              onTap: () => _removeItem(doc.id),
                                              child: Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: screenWidth * 0.01),
                                        Text(
                                          'Total: ₱${itemTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.035,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6CA04A),
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Checkout Section
                    Container(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
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
                                '₱${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.05,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6CA04A),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.04),
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
                              onPressed: _isProcessing ? null : () async {
                                final paymentMethod = await _showPaymentMethodDialog();
                                if (paymentMethod != null) {
                                  setState(() {
                                    _selectedPaymentMethod = paymentMethod;
                                    _isProcessing = true;
                                  });

                                  try {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CheckoutSummaryPage(
                                          cartItems: cartItems,
                                        ),
                                      ),
                                    );
                                  } finally {
                                    setState(() => _isProcessing = false);
                                  }
                                }
                              },
                              child: _isProcessing
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Proceed to Checkout',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.045,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}