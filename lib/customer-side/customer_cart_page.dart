// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:veggieconnect/customer-side/customer_checkout_summary_page.dart'; // Added import for CheckoutSummaryPage
import '../widgets/lottie_loading_widget.dart';
import '../authentication/login_page.dart';
import '../services/auth_state_service.dart';
import '../widgets/role_page_header.dart';
import 'customer_dashboard.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final AuthStateService _authService = AuthStateService();
  
  // Use custom auth service instead of Firebase Auth directly
  AuthUser? get user => _authService.currentUser;
  
  late CollectionReference<Map<String, dynamic>> _cartRef;
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'cash_on_pickup';

  @override
  void initState() {
    super.initState();
    
    // Check if user is authenticated
    if (user != null) {
      _cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart');
    } else {
      // User is not authenticated, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToLogin();
      });
    }
  }

  void _redirectToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Future<void> _updateQuantity(String docId, int newQty, {int? maxQty}) async {
    int clampedQty = newQty;
    if (maxQty != null) {
      clampedQty = newQty.clamp(1, maxQty);
    }
    if (clampedQty > 0) {
      await _cartRef.doc(docId).update({'quantity': clampedQty});
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
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Payment Method', style: GoogleFonts.quicksand(fontSize: 12),),
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
                    Text('', style: GoogleFonts.quicksand(fontSize: 16)),
                    const SizedBox(width: 8),
                    const Text('Cash on Pickup'),
                  ],
                ),
                subtitle: Text(
                  '  Pay on Pickup',
                  style: GoogleFonts.quicksand(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
              
              // Online Payment (generalized)
              RadioListTile<String>(
                value: 'online_payment',
                groupValue: tempMethod,
                onChanged: (val) => setState(() => tempMethod = val!),
                title: Row(
                  children: [
                    Text('', style: GoogleFonts.quicksand(fontSize: 16)),
                    const SizedBox(width: 8),
                    const Text('Online Payment'),
                  ],
                ),
                subtitle: Text(
                  '  Pay online',
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: RolePageHeader(
        title: 'My Cart',
        onBackTap: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CustomerHomePage()),
            );
          }
        },
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
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.06,
                        color: Color(0xFF6CA04A),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.02),
                    Text(
                      'You need to be logged in to view your cart',
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.04,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
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
                    child: const GroceryLoadingWidget(
                      size: 120,
                      showText: true,
                      loadingText: 'Loading your cart...',
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
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.06,
                              color: Color(0xFF6CA04A),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text(
                            'Add some products to get started',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.04,
                              color: Color(0xFF757575),
                              fontWeight: FontWeight.w400,
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
                                          style: GoogleFonts.quicksand(
                                            fontSize: screenWidth * 0.045,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: screenWidth * 0.01),
                                        Text(
                                          '₱${data['price']?.toStringAsFixed(2) ?? '0.00'}',
                                          style: GoogleFonts.quicksand(
                                            fontSize: screenWidth * 0.04,
                                            color: Color(0xFF6CA04A),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        SizedBox(height: screenWidth * 0.02),
                                        Row(
                                          children: [
                                            // Quantity Controls (stock-aware)
                                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('products')
                                                  .doc((data['productId'] ?? '').toString())
                                                  .snapshots(),
                                              builder: (context, productSnap) {
                                                final int currentQty = (data['quantity'] ?? 1) is int
                                                    ? data['quantity'] as int
                                                    : int.tryParse('${data['quantity']}') ?? 1;
                                                final int availableStock = productSnap.hasData && productSnap.data?.data() != null
                                                    ? (((productSnap.data!.data()!['quantity']) ?? 0) as num).toInt()
                                                    : 0;
                                                final bool canDecrease = currentQty > 1;
                                                final bool canIncrease = currentQty < availableStock;

                                                final Color enabledColor = Color(0xFF6CA04A);
                                                final Color disabledColor = Colors.grey;

                                                return Container(
                                                  decoration: BoxDecoration(
                                                    color: (canIncrease || canDecrease)
                                                        ? Color(0xFF6CA04A).withOpacity(0.1)
                                                        : Colors.grey.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      GestureDetector(
                                                        onTap: canDecrease
                                                            ? () => _updateQuantity(doc.id, currentQty - 1, maxQty: availableStock)
                                                            : null,
                                                        child: Container(
                                                          padding: EdgeInsets.all(8),
                                                          child: Icon(
                                                            Icons.remove,
                                                            size: 16,
                                                            color: canDecrease ? enabledColor : disabledColor,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        child: Text(
                                                          '$currentQty',
                                                          style: GoogleFonts.quicksand(
                                                            fontWeight: FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: canIncrease
                                                            ? () => _updateQuantity(doc.id, currentQty + 1, maxQty: availableStock)
                                                            : null,
                                                        child: Container(
                                                          padding: EdgeInsets.all(8),
                                                          child: Icon(
                                                            Icons.add,
                                                            size: 16,
                                                            color: canIncrease ? enabledColor : disabledColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
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
                                          style: GoogleFonts.quicksand(
                                            fontSize: screenWidth * 0.035,
                                            color: Color(0xFF6CA04A),
                                            fontWeight: FontWeight.w400,
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
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.05,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.05,
                                  color: Color(0xFF6CA04A),
                                  fontWeight: FontWeight.w400,
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
                                          selectedPaymentMethod: paymentMethod,
                                        ),
                                      ),
                                    );
                                  } finally {
                                    setState(() => _isProcessing = false);
                                  }
                                }
                              },
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 28,
                                      width: 28,
                                      child: GroceryLoadingWidget(
                                        size: 28,
                                        showText: false,
                                      ),
                                    )
                                  : Text(
                                      'Proceed to Checkout',
                                      style: GoogleFonts.quicksand(
                                        fontSize: screenWidth * 0.045,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w400,
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