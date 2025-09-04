// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_types_as_parameter_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veggieconnect/services/supplier_report_service.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/star_rating_widget.dart';
import 'package:flutter/material.dart';
import 'buyer_chat_page.dart';

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final String productId;
  
  const ProductDetailsPage({
    super.key, 
    required this.product, 
    required this.productId,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int _qty = 1;
  bool _readMore = false;
  final user = FirebaseAuth.instance.currentUser;

  void _addToCart() async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add to cart.')),
      );
      return;
    }
    try {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('cart');
      // Check if product already in cart
      final existing = await cartRef
          .where('productId', isEqualTo: widget.productId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        // Update quantity with stock validation
        final doc = existing.docs.first;
        final currentCartQty = doc['quantity'] ?? 1;
        final newTotalQty = currentCartQty + _qty;
        final availableStock = widget.product['quantity'] ?? 0;
        
        if (newTotalQty > availableStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot add more. Only $availableStock items available in stock.')),
          );
          return;
        }
        
        await cartRef.doc(doc.id).update({
          'quantity': newTotalQty,
        });
      } else {
        // Check stock for new cart item
        final availableStock = widget.product['quantity'] ?? 0;
        if (_qty > availableStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot add $_qty items. Only $availableStock items available in stock.')),
          );
          return;
        }
        
        await cartRef.add({
          'productId': widget.productId,
          'sellerId': widget.product['sellerId'],
          'name': widget.product['name'],
          'imageUrl': widget.product['imageUrl'],
          'quantity': _qty,
          'unit': widget.product['unit'],
          'price': widget.product['price'],
          'supplierName': widget.product['supplierName'],
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding to cart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final product = widget.product;
    final desc = product['description'] ?? 'No description available';
    final showReadMore = desc.length > 90;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        elevation: 0,
        title: Text(
          'Product Details',
          style: TextStyle(
            fontSize: screenWidth * 0.055,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                margin: EdgeInsets.only(top: screenWidth * 0.08, left: screenWidth * 0.04, right: screenWidth * 0.04),
                padding: EdgeInsets.only(top: screenWidth * 0.15, bottom: screenWidth * 0.06),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(screenWidth * 0.05),
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
                    Center(
                      child: ProductImageWidget(
                        imagePath: product['imageUrl'] ?? '',
                        width: screenWidth * 0.5,
                        height: screenWidth * 0.5,
                        placeholder: Icon(Icons.shopping_basket, size: screenWidth * 0.18, color: Color(0xFF6CA04A)),
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.03),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Unknown Product',
                            style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.015),
                          Row(
                            children: [
                              Icon(Icons.store, color: Color(0xFF6CA04A), size: screenWidth * 0.05),
                              SizedBox(width: screenWidth * 0.02),
                              Text(
                                product['supplierName'] ?? 'Unknown Supplier',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Color(0xFF757575),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.02),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('ratings')
                                    .where('supplierId', isEqualTo: product['sellerId'])
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return Row(
                                      children: [
                                        StarRatingDisplay(rating: 0, size: screenWidth * 0.035),
                                        SizedBox(width: screenWidth * 0.01),
                                        Text(
                                          '(0)',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.032,
                                            color: Color(0xFF757575),
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  final docs = snapshot.data!.docs;
                                  if (docs.isEmpty) {
                                    return Row(
                                      children: [
                                        StarRatingDisplay(rating: 0, size: screenWidth * 0.035),
                                        SizedBox(width: screenWidth * 0.01),
                                        Text(
                                          '(0)',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.032,
                                            color: Color(0xFF757575),
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  final totalRating = docs.fold<double>(0, (sum, d) => sum + ((d['rating'] ?? 0) as num).toDouble());
                                  final average = totalRating / docs.length;
                                  return Row(
                                    children: [
                                      StarRatingDisplay(rating: average, size: screenWidth * 0.035),
                                      SizedBox(width: screenWidth * 0.01),
                                      Text(
                                        '(${docs.length})',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.032,
                                          color: Color(0xFF757575),
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              // Report icon - only show for customers viewing other suppliers' products
                              if (user != null && user!.uid != (widget.product['sellerId'] ?? ''))
                                IconButton(
                                  icon: const Icon(Icons.report_problem, color: Colors.red),
                                  onPressed: () => _showReportDialog(context),
                                ),
                            ],
                          ),
                          
                          // Real-time Rating Percentage Display
                          SizedBox(height: screenWidth * 0.02),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('ratings')
                                .where('supplierId', isEqualTo: product['sellerId'])
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_border, color: Colors.grey, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'No ratings yet',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.032,
                                          color: Colors.grey[600],
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              final docs = snapshot.data!.docs;
                              final totalRating = docs.fold<double>(0, (sum, d) => sum + ((d['rating'] ?? 0) as num).toDouble());
                              final average = totalRating / docs.length;
                              final percentage = (average / 5.0) * 100;
                              
                              // Calculate rating distribution
                              final counts = List<int>.filled(6, 0);
                              for (final d in docs) {
                                final r = (d['rating'] ?? 0) as int;
                                if (r >= 1 && r <= 5) counts[r]++;
                              }
                              final total = docs.length;
                              final fiveStarCount = counts[5];
                              final fourStarCount = counts[4];
                              final highRatingCount = fiveStarCount + fourStarCount;
                              final highRatingPercentage = total > 0 ? (highRatingCount * 100.0 / total) : 0.0;
                              
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6CA04A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Color(0xFF6CA04A).withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, color: Color(0xFF6CA04A), size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      '${percentage.toStringAsFixed(0)}% Satisfaction',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.032,
                                        color: Color(0xFF6CA04A),
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF6CA04A),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${highRatingPercentage.toStringAsFixed(0)}% 4-5★',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.028,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          SizedBox(height: screenWidth * 0.02),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('ratings')
                                .where('supplierId', isEqualTo: product['sellerId'])
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final docs = snapshot.data!.docs;
                              final counts = List<int>.filled(6, 0);
                              for (final d in docs) {
                                final r = (d['rating'] ?? 0) as int;
                                if (r >= 1 && r <= 5) counts[r]++;
                              }
                              final total = docs.length;
                              Widget buildBar(int stars) {
                                final count = counts[stars];
                                final pct = total > 0 ? (count * 100.0 / total) : 0.0;
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.005),
                                  child: Row(
                                    children: [
                                      Text('$stars★', style: TextStyle(fontSize: screenWidth * 0.032, fontFamily: 'Poppins', color: Color(0xFF757575))),
                                      SizedBox(width: screenWidth * 0.02),
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Container(
                                              height: 6,
                                              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                                            ),
                                            FractionallySizedBox(
                                              widthFactor: (pct / 100).clamp(0.0, 1.0),
                                              child: Container(
                                                height: 6,
                                                decoration: BoxDecoration(color: Color(0xFF6CA04A), borderRadius: BorderRadius.circular(4)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.02),
                                      Text('${pct.toStringAsFixed(0)}% ($count)', style: TextStyle(fontSize: screenWidth * 0.03, fontFamily: 'Poppins', color: Color(0xFF757575))),
                                    ],
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildBar(5),
                                  buildBar(4),
                                  buildBar(3),
                                  buildBar(2),
                                  buildBar(1),
                                ],
                              );
                            },
                          ),
                        
                          SizedBox(height: screenWidth * 0.02),
                          Row(
                            children: [
                              Text(
                                '\u20b1${product['price']?.toStringAsFixed(2) ?? '0.00'}/${product['unit'] ?? 'unit'}',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.055,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6CA04A),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const Spacer(),
                              // Only show quantity selector for customers (not suppliers)
                              if (user == null || product['sellerId'] != user?.uid)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6CA04A).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(screenWidth * 0.07),
                                    border: Border.all(
                                      color: Color(0xFF6CA04A).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.remove, size: screenWidth * 0.06),
                                        onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                                      ),
                                      Text(
                                        '$_qty ${product['unit'] ?? 'unit'}',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.045,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add, size: screenWidth * 0.06),
                                        onPressed: () => setState(() => _qty++),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Row(
                            children: [
                              Icon(Icons.inventory, color: Color(0xFF6CA04A), size: screenWidth * 0.05),
                              SizedBox(width: screenWidth * 0.02),
                              Text(
                                'Stock: ${product['quantity'] ?? 0} ${product['unit'] ?? 'units'}',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Color(0xFF757575),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.04),
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text(
                            showReadMore && !_readMore ? '${desc.substring(0, 90)}...' : desc,
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              color: Color(0xFF757575),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (showReadMore)
                            GestureDetector(
                              onTap: () => setState(() => _readMore = !_readMore),
                              child: Text(
                                _readMore ? 'Read Less' : 'Read More',
                                style: TextStyle(
                                  color: Color(0xFF6CA04A),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenWidth * 0.2), // Space for bottom buttons
            ],
          ),
          // Bottom action buttons
          if (user != null && product['sellerId'] != user?.uid)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
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
                child: Row(
                  children: [
                    // Chat button
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          final supplierId = product['sellerId'] as String?;
                          final supplierName = product['supplierName'] as String? ?? 'Supplier';
                          if (supplierId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Unable to start chat: Supplier information not available')),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BuyerChatPage(
                                supplierId: supplierId,
                                supplierName: supplierName,
                                buyerId: user!.uid,
                                buyerName: user!.displayName ?? 'Customer',
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble, color: Colors.white, size: screenWidth * 0.05),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              'Chat',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    // Add to cart button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6CA04A),
                          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _addToCart,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart, color: Colors.white, size: screenWidth * 0.05),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) async {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Report Supplier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please provide a reason for reporting this supplier:', 
                   style: TextStyle(fontSize: 14, color: Color(0xFF757575), fontFamily: 'Poppins')),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for report...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(fontSize: 12, fontFamily: 'Poppins', backgroundColor: Colors.grey, color: Colors.green)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason for the report')),
                  );
                  return;
                }
                
                try {
                  await SupplierReportService.submitReport(
                    supplierId: widget.product['sellerId'] ?? '',
                    reporterId: user!.uid,
                    productId: widget.productId,
                    reason: reasonController.text.trim(),
                    productName: widget.product['name'],
                    supplierName: widget.product['supplierName'],
                  );
                  
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted successfully')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to submit report: $e')),
                  );
                }
              },
              child: Text('Submit Report', style: TextStyle(fontSize: 12, backgroundColor: Colors.red, color: Colors.white, fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
  }
}