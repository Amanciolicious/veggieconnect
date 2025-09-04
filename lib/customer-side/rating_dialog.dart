// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/star_rating_widget.dart';

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

      // Create rating document
      final ratingData = {
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
          .add(ratingData);

      // Update order documents to mark as rated
      // Note: orders are stored with auto-generated doc IDs; `orderId` is a field shared by all
      // item-level order docs created at checkout. We need to update all matching docs.
      final ordersQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: widget.orderId)
          .where('buyerId', isEqualTo: user.uid)
          .get();

      if (ordersQuery.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in ordersQuery.docs) {
          batch.update(doc.reference, {'hasRating': true});
        }
        await batch.commit();
      } else {
        // No matching order docs found; log but don't fail the rating creation
        // You may want to report this to analytics/logging.
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
        style: TextStyle(
          fontSize: screenWidth * 0.05,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
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
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
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
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontFamily: 'Poppins',
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
                hintStyle: TextStyle(
                  color: Color(0xFF757575),
                  fontFamily: 'Poppins',
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
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: screenWidth * 0.04,
              ),
            ),
            
            SizedBox(height: screenWidth * 0.06),
            
            // Products list
            if (widget.products.isNotEmpty) ...[
              Text(
                'Products ordered:',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: screenWidth * 0.02),
              ...widget.products.map((product) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${product['name']} (${product['quantity']}x)',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontFamily: 'Poppins',
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
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w600,
              color: Color(0xFF757575),
              fontFamily: 'Poppins',
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
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color?>(Colors.white),
                  ),
                )
              : Text(
                  'Submit Rating',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
        ),
      ],
    );
  }
}
