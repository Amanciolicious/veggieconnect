// ignore_for_file: deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'star_rating_widget.dart';
import '../services/product_rating_service.dart';
import '../services/auth_state_service.dart';
import './lottie_loading_widget.dart';

class ProductRatingDialog extends StatefulWidget {
  final String productId;
  final String supplierId;
  final String productName;
  final String supplierName;

  const ProductRatingDialog({
    super.key,
    required this.productId,
    required this.supplierId,
    required this.productName,
    required this.supplierName,
  });

  @override
  State<ProductRatingDialog> createState() => _ProductRatingDialogState();
}

class _ProductRatingDialogState extends State<ProductRatingDialog> {
  final AuthStateService _authService = AuthStateService();
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  AuthUser? get user => _authService.currentUser;

  @override
  void initState() {
    super.initState();
    _checkExistingRating();
  }

  Future<void> _checkExistingRating() async {
    try {
      final existingRating = await ProductRatingService.getUserProductRating(widget.productId);
      if (existingRating != null) {
        setState(() {
          _rating = existingRating['rating'] ?? 0;
          _feedbackController.text = existingRating['feedback'] ?? '';
        });
      }
    } catch (e) {
      print('Error checking existing rating: $e');
    }
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

    setState(() => _isSubmitting = true);

    try {
      if (user == null) return;

      // Check if user has already rated this product
      final existingRating = await ProductRatingService.getUserProductRating(widget.productId);
      
      bool success;
      if (existingRating != null) {
        // Update existing rating
        success = await ProductRatingService.updateProductRating(
          ratingId: existingRating['id'],
          rating: _rating,
          feedback: _feedbackController.text.trim(),
        );
      } else {
        // Submit new rating
        success = await ProductRatingService.submitProductRating(
          productId: widget.productId,
          supplierId: widget.supplierId,
          rating: _rating,
          feedback: _feedbackController.text.trim(),
          productName: widget.productName,
          supplierName: widget.supplierName,
        );
      }

      if (success) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingRating != null 
                ? 'Rating updated successfully!' 
                : 'Thank you for your feedback!'),
            backgroundColor: const Color(0xFF6CA04A),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit rating. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(screenWidth * 0.05),
              decoration: BoxDecoration(
                color: Color(0xFF6CA04A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.white,
                    size: screenWidth * 0.06,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Text(
                      'Rate Product',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: screenWidth * 0.06,
                    ),
                  ),
                ],
              ),
            ),
            
            // Product Info
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_basket,
                    color: Color(0xFF6CA04A),
                    size: screenWidth * 0.05,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        Text(
                          'by ${widget.supplierName}',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(height: 1, color: Colors.grey[300]),
            
            // Rating Section
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How would you rate this product?',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  Center(
                    child: StarRatingWidget(
                      rating: _rating,
                      onRatingChanged: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                      size: screenWidth * 0.08,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.04),
                  
                  // Feedback Section
                  Text(
                    'Share your experience (optional)',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tell others about your experience with this product...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF6CA04A), width: 2),
                      ),
                      contentPadding: EdgeInsets.all(screenWidth * 0.04),
                    ),
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6CA04A),
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: LottieLoadingWidget(
                                assetPath: 'assets/lottie-loading-json/loading.json',
                                width: 24,
                                height: 24,
                                showText: false,
                              ),
                            )
                          : Text(
                              'Submit Rating',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
