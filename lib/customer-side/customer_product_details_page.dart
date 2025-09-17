// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_types_as_parameter_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:veggieconnect/widgets/star_rating_widget.dart';
import '../widgets/product_image_widget.dart';
import 'package:flutter/material.dart';
import 'customer_chat_page.dart';
import 'customer_dashboard.dart';
import '../services/auth_state_service.dart';

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
  final AuthStateService _authService = AuthStateService();
  AuthUser? get user => _authService.currentUser;

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

  Widget _buildRelatedProductsSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: widget.product['category'])
          .where('productId', isNotEqualTo: widget.productId)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final products = snapshot.data!.docs;
        
        return SizedBox(
          height: screenWidth * 0.35,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index].data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailsPage(
                        product: product,
                        productId: products[index].id,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(right: screenWidth * 0.04),
                  width: screenWidth * 0.25,
                  child: Column(
                    children: [
                      ProductImageWidget(
                        imagePath: product['imageUrl'] ?? '',
                        width: screenWidth * 0.25,
                        height: screenWidth * 0.25,
                        placeholder: Icon(Icons.shopping_basket, size: screenWidth * 0.1, color: Color(0xFF6CA04A)),
                      ),
                      SizedBox(height: screenWidth * 0.02),
                      Text(
                        product['name'] ?? 'Unknown Product',
                        style: GoogleFonts.quicksand(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenWidth * 0.01),
                      Text(
                        '\u20b1${product['price']?.toStringAsFixed(2) ?? '0.00'}/${product['unit'] ?? 'unit'}',
                        style: GoogleFonts.quicksand(
                          fontSize: screenWidth * 0.035,
                          color: Color(0xFF6CA04A),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CustomerHomePage()),
            );
          },
        ),
        elevation: 0,
        title: Text(
          'Product Details',
          style: GoogleFonts.quicksand(
            fontSize: screenWidth * 0.055,
            color: Colors.white,
            fontWeight: FontWeight.w400,
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
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.015),
                          Row(
                            children: [
                              Icon(Icons.store, color: Color(0xFF6CA04A), size: screenWidth * 0.05),
                              SizedBox(width: screenWidth * 0.02),
                              Text(
                                product['supplierName'] ?? 'Unknown Supplier',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.04,
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.01),
                          // Product rating indicator (text only) below supplier name
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('product_ratings')
                                .where('productId', isEqualTo: widget.productId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Text(
                                  'No ratings yet',
                                  style: GoogleFonts.quicksand(
                                    fontSize: screenWidth * 0.032,
                                    color: Color(0xFF9E9E9E),
                                    fontWeight: FontWeight.w400,
                                  ),
                                );
                              }
                              final docs = snapshot.data!.docs;
                              final totalRating = docs.fold<double>(0, (sum, d) => sum + ((d['rating'] ?? 0) as num).toDouble());
                              final average = totalRating / docs.length;
                              return Text(
                                'Rated ${average.toStringAsFixed(1)} (${docs.length})',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.032,
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.w400,
                                ),
                              );
                            },
                          ),
                          
                          // Real-time Rating Percentage Display
                          SizedBox(height: screenWidth * 0.02),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('product_ratings')
                                .where('productId', isEqualTo: widget.productId)
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
                                      Icon(Icons.star_border, color: Colors.grey, size: 14),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'No ratings yet',
                                          style: GoogleFonts.quicksand(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w400,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6CA04A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Color(0xFF6CA04A).withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, color: Color(0xFF6CA04A), size: 14),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${percentage.toStringAsFixed(0)}% Satisfaction',
                                        style: GoogleFonts.quicksand(
                                          fontSize: 11,
                                          color: Color(0xFF6CA04A),
                                          fontWeight: FontWeight.w400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF6CA04A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${highRatingPercentage.toStringAsFixed(0)}% 4-5★',
                                        style: GoogleFonts.quicksand(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          // Real-time Rating Distribution Display
                          SizedBox(height: screenWidth * 0.02),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('product_ratings')
                                .where('productId', isEqualTo: widget.productId)
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
                                      Text('$stars★', style: GoogleFonts.quicksand(fontSize: screenWidth * 0.032, fontWeight: FontWeight.w400, color: Color(0xFF757575))),
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
                                      Text('${pct.toStringAsFixed(0)}% ($count)', style: GoogleFonts.quicksand(fontSize: screenWidth * 0.03, fontWeight: FontWeight.w400, color: Color(0xFF757575))),
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
                          
                          // Customer Reviews Section
                          SizedBox(height: screenWidth * 0.04),
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFF8D9773).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_rate,
                                      color: Color(0xFF6CA04A),
                                      size: screenWidth * 0.05,
                                    ),
                                    SizedBox(width: screenWidth * 0.02),
                                    Text(
                                      'Customer Reviews',
                                      style: GoogleFonts.quicksand(
                                        fontSize: screenWidth * 0.036,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    Spacer(),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('product_ratings')
                                          .where('productId', isEqualTo: widget.productId)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                          return Text(
                                            'No reviews yet',
                                            style: GoogleFonts.quicksand(
                                              fontSize: screenWidth * 0.033,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w400,
                                            ),
                                          );
                                        }
                                        
                                        final reviews = snapshot.data!.docs;
                                        final totalRating = reviews.fold<double>(0, (sum, d) => 
                                          sum + ((d['rating'] ?? 0) as num).toDouble());
                                        final average = totalRating / reviews.length;
                                        
                                        return Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Row(
                                              children: [
                                                StarRatingDisplay(
                                                  rating: average,
                                                  size: screenWidth * 0.034,
                                                  showRatingText: true,
                                                ),
                                                SizedBox(width: screenWidth * 0.012),
                                                Text(
                                                  '(${reviews.length})',
                                                  style: GoogleFonts.quicksand(
                                                    fontSize: screenWidth * 0.03,
                                                    color: Color(0xFF757575),
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: screenWidth * 0.04),
                                
                                // Individual Reviews List
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('product_ratings')
                                      .where('productId', isEqualTo: widget.productId)
                                      .orderBy('timestamp', descending: true)
                                      .limit(10) // Show latest 10 reviews
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return Container(
                                        padding: EdgeInsets.all(screenWidth * 0.04),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey[200]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.rate_review_outlined, color: Colors.grey[400], size: screenWidth * 0.05),
                                            SizedBox(width: screenWidth * 0.03),
                                            Expanded(
                                              child: Text(
                                                'No reviews yet. Be the first!',
                                                style: GoogleFonts.quicksand(
                                                  fontSize: screenWidth * 0.032,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    
                                    final reviews = snapshot.data!.docs;
                                    
                                    return Column(
                                      children: reviews.map((reviewDoc) {
                                        final reviewData = reviewDoc.data() as Map<String, dynamic>;
                                        final rating = reviewData['rating'] ?? 0;
                                        final feedback = reviewData['feedback'] ?? '';
                                        final buyerName = reviewData['buyerName'] ?? 'Anonymous Customer';
                                        final timestamp = reviewData['timestamp'] as Timestamp?;
                                        final supplierName = reviewData['supplierName'] ?? 'Unknown Supplier';
                                        
                                        // Format date
                                        String formattedDate = 'Recently';
                                        if (timestamp != null) {
                                          final date = timestamp.toDate();
                                          final now = DateTime.now();
                                          final difference = now.difference(date);
                                          
                                          if (difference.inDays > 0) {
                                            formattedDate = '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
                                          } else if (difference.inHours > 0) {
                                            formattedDate = '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
                                          } else if (difference.inMinutes > 0) {
                                            formattedDate = '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
                                          } else {
                                            formattedDate = 'Just now';
                                          }
                                        }
                                        
                                        return Container(
                                          margin: EdgeInsets.only(bottom: screenWidth * 0.03),
                                          padding: EdgeInsets.all(screenWidth * 0.035),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Color(0xFF8D9773).withOpacity(0.15),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.08),
                                                spreadRadius: 1,
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Header with customer name and rating
                                              Row(
                                                children: [
                                                  // Customer avatar
                                                  Container(
                                                    width: screenWidth * 0.08,
                                                    height: screenWidth * 0.08,
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFF6CA04A).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                                                      border: Border.all(
                                                        color: Color(0xFF6CA04A).withOpacity(0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Color(0xFF6CA04A),
                                                      size: screenWidth * 0.045,
                                                    ),
                                                  ),
                                                  SizedBox(width: screenWidth * 0.03),
                                                  
                                                  // Customer name and supplier info
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment.centerLeft,
                                                          child: Text(
                                                            buyerName,
                                                            style: GoogleFonts.quicksand(
                                                              fontSize: screenWidth * 0.036,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF333333),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          'Purchased from $supplierName',
                                                          style: GoogleFonts.quicksand(
                                                            fontSize: screenWidth * 0.03,
                                                            color: Color(0xFF757575),
                                                            fontWeight: FontWeight.w400,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  
                                                  // Date and rating
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      StarRatingDisplay(
                                                        rating: rating.toDouble(),
                                                        size: screenWidth * 0.032,
                                                        showRatingText: false,
                                                      ),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        formattedDate,
                                                        style: GoogleFonts.quicksand(
                                                          fontSize: screenWidth * 0.028,
                                                          color: Color(0xFF9E9E9E),
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              
                                              // Review comment
                                              if (feedback.isNotEmpty) ...[
                                                SizedBox(height: screenWidth * 0.025),
                                                Container(
                                                  padding: EdgeInsets.all(screenWidth * 0.03),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFFF8FAF5),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: Color(0xFF8D9773).withOpacity(0.1),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    feedback,
                                                    style: GoogleFonts.quicksand(
                                                      fontSize: screenWidth * 0.033,
                                                      color: Color(0xFF555555),
                                                      fontWeight: FontWeight.w400,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        
                          SizedBox(height: screenWidth * 0.02),
                          Row(
                            children: [
                              Text(
                                '\u20b1${product['price']?.toStringAsFixed(2) ?? '0.00'}/${product['unit'] ?? 'unit'}',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.055,
                                  color: Color(0xFF6CA04A),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const Spacer(),
                              // Only show quantity selector for customers (not suppliers)
                              if (user == null || product['sellerId'] != user?.uid)
                                Container(
                                  width: 140, // Fixed width to prevent overflow
                                  height: 40, // Fixed height for consistent appearance
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6CA04A).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Color(0xFF6CA04A).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(Icons.remove, size: 18),
                                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '$_qty ${(product['unit'] ?? 'unit').toString().length > 6 ? (product['unit'] ?? 'unit').toString().substring(0, 6) : product['unit'] ?? 'unit'}',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.quicksand(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(Icons.add, size: 18),
                                          onPressed: () => setState(() => _qty++),
                                        ),
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
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.04,
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.015),
                          // Real-time Sold Counter
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('products')
                                .doc(widget.productId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return SizedBox.shrink();
                              }
                              
                              final productData = snapshot.data!.data() as Map<String, dynamic>?;
                              final soldCount = productData?['soldCount'] ?? 0;
                              
                              return Row(
                                children: [
                                  Icon(Icons.trending_up, color: Color(0xFF6CA04A), size: screenWidth * 0.05),
                                  SizedBox(width: screenWidth * 0.02),
                                  Text(
                                    '$soldCount sold',
                                    style: GoogleFonts.quicksand(
                                      fontSize: screenWidth * 0.04,
                                      color: Color(0xFF6CA04A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.02),
                                  // Add a small badge for visual appeal
                                  if (soldCount > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: screenWidth * 0.02,
                                        vertical: screenWidth * 0.01,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF6CA04A).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Color(0xFF6CA04A).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.local_fire_department,
                                            color: Color(0xFF6CA04A),
                                            size: screenWidth * 0.035,
                                          ),
                                          SizedBox(width: screenWidth * 0.01),
                                          Text(
                                            soldCount >= 10 ? 'Popular' : 'Selling',
                                            style: GoogleFonts.quicksand(
                                              fontSize: screenWidth * 0.03,
                                              color: Color(0xFF6CA04A),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: screenWidth * 0.04),
                          Text(
                            'Related Products',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF222222),
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.03),
                          _buildRelatedProductsSection(),
                          
                          SizedBox(height: screenWidth * 0.04),
                          Text(
                            'Description',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text(
                            showReadMore && !_readMore ? '${desc.substring(0, 90)}...' : desc,
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.04,
                              color: Color(0xFF757575),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (showReadMore)
                            GestureDetector(
                              onTap: () => setState(() => _readMore = !_readMore),
                              child: Text(
                                _readMore ? 'Read Less' : 'Read More',
                                style: GoogleFonts.quicksand(
                                  color: Color(0xFF6CA04A),
                                  fontWeight: FontWeight.w400,
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
                              style: GoogleFonts.quicksand(
                                fontSize: screenWidth * 0.04,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
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
                              style: GoogleFonts.quicksand(
                                fontSize: screenWidth * 0.04,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
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

  // Report functionality removed - customers can only report after completing orders
}