// ignore_for_file: deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/star_rating_widget.dart';
import '../widgets/lottie_loading_widget.dart';

class RatingDialog extends StatefulWidget {
  final String orderId;
  final String supplierId;
  final String supplierName;
  final List<Map<String, dynamic>> products;

  const RatingDialog({
    super.key,
    required this.orderId,
    required this.supplierId,
    required this.supplierName,
    required this.products,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Prevent duplicate rating submission for the same order by the same buyer
      final existing = await FirebaseFirestore.instance
          .collection('order_ratings')
          .where('orderId', isEqualTo: widget.orderId)
          .where('buyerId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already rated this order'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(false);
        return;
      }

      // Create rating document for order_ratings collection
      final orderRatingData = {
        'orderId': widget.orderId,
        'buyerId': user.uid,
        'buyerName': user.displayName ?? 'Customer',
        'supplierId': widget.supplierId,
        'supplierName': widget.supplierName,
        'rating': _rating,
        'feedback': _feedbackController.text.trim(),
        'products': widget.products,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('order_ratings')
          .add(orderRatingData);

      // Create corresponding entries in product_ratings collection for real-time sync
      // This ensures ratings appear in product details and supplier order management
      final batch = FirebaseFirestore.instance.batch();
      
      for (final product in widget.products) {
        final productId = product['productId']?.toString();
        if (productId != null && productId.isNotEmpty) {
          // Check if user already rated this specific product
          final existingProductRating = await FirebaseFirestore.instance
              .collection('product_ratings')
              .where('productId', isEqualTo: productId)
              .where('buyerId', isEqualTo: user.uid)
              .limit(1)
              .get();
          
          // Only create product rating if it doesn't exist
          if (existingProductRating.docs.isEmpty) {
            final productRatingRef = FirebaseFirestore.instance
                .collection('product_ratings')
                .doc();
            
            final productRatingData = {
              'productId': productId,
              'supplierId': widget.supplierId,
              'buyerId': user.uid,
              'buyerName': user.displayName ?? 'Customer',
              'rating': _rating,
              'feedback': _feedbackController.text.trim(),
              'productName': product['name'] ?? 'Unknown Product',
              'supplierName': widget.supplierName,
              'orderId': widget.orderId, // Link back to original order
              'timestamp': FieldValue.serverTimestamp(),
            };
            
            batch.set(productRatingRef, productRatingData);
          }
        }
      }
      
      // Commit product ratings batch
      await batch.commit();

      // Update order documents to mark as rated
      // Note: orders are stored with auto-generated doc IDs; `orderId` is a field shared by all
      // item-level order docs created at checkout. We need to update all matching docs.
      final ordersQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: widget.orderId)
          .where('buyerId', isEqualTo: user.uid)
          .get();

      if (ordersQuery.docs.isNotEmpty) {
        final orderBatch = FirebaseFirestore.instance.batch();
        for (final doc in ordersQuery.docs) {
          orderBatch.update(doc.reference, {'hasRating': true});
        }
        await orderBatch.commit();
      }

      // Update product documents with new average ratings for real-time display
      for (final product in widget.products) {
        final productId = product['productId']?.toString();
        if (productId != null && productId.isNotEmpty) {
          await _updateProductAverageRating(productId);
        }
      }

      if (!mounted) return;
      
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thank you for your feedback!'),
          backgroundColor: Color(0xFF6CA04A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting rating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Update product document with new average rating for real-time display
  Future<void> _updateProductAverageRating(String productId) async {
    try {
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('product_ratings')
          .where('productId', isEqualTo: productId)
          .get();

      if (ratingsSnapshot.docs.isNotEmpty) {
        final ratings = ratingsSnapshot.docs.map((doc) => doc['rating'] as int).toList();
        final totalRatings = ratings.length;
        final averageRating = ratings.reduce((a, b) => a + b) / totalRatings;

        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update({
          'averageRating': averageRating,
          'totalRatings': totalRatings,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating product average rating: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Rate Your Experience',
        style: GoogleFonts.quicksand(
          fontSize: screenWidth * 0.05,
          fontWeight: FontWeight.w400,
          color: Color(0xFF2E2E2E),
        ),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Supplier info
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Color(0xFF6CA04A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.store,
                    color: Color(0xFF6CA04A),
                    size: screenWidth * 0.06,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Text(
                      widget.supplierName,
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6CA04A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: screenWidth * 0.06),
            
            // Rating stars
            Text(
              'How was your experience?',
              style: GoogleFonts.quicksand(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w400,
                color: Color(0xFF757575),
              ),
            ),
            SizedBox(height: screenWidth * 0.04),
            
            StarRatingWidget(
              rating: _rating,
              onRatingChanged: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
              size: screenWidth * 0.08,
            ),
            
            SizedBox(height: screenWidth * 0.06),
            
            // Feedback text field
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your feedback (optional)',
                hintStyle: GoogleFonts.quicksand(
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w400,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF8D9773).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF6CA04A), width: 2),
                ),
                contentPadding: EdgeInsets.all(16),
              ),
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.w400,
                fontSize: screenWidth * 0.04,
              ),
            ),
            
            SizedBox(height: screenWidth * 0.06),
            
            // Products list
            if (widget.products.isNotEmpty) ...[
              Text(
                'Products ordered:',
                style: GoogleFonts.quicksand(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: screenWidth * 0.02),
              ...widget.products.map((product) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${product['name']} (${product['quantity']}x)',
                  style: GoogleFonts.quicksand(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF757575),
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.quicksand(
              fontSize: screenWidth * 0.04,
              color: Color(0xFF757575),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6CA04A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.06,
              vertical: screenWidth * 0.03,
            ),
          ),
          onPressed: _isSubmitting ? null : _submitRating,
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: LottieLoadingWidget(
                    assetPath: 'assets/lottie-loading-json/Grocery shopping bag pickup and delivery.json',
                    width: 24,
                    height: 24,
                  ),
                )
              : Text(
                  'Submit Rating',
                  style: GoogleFonts.quicksand(
                    fontSize: screenWidth * 0.04,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
        ),
      ],
    );
  }
}
