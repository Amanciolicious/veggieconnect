// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_state_service.dart';

class SupplierRatingDialog extends StatefulWidget {
  final String supplierId;
  final String orderId;
  final String supplierName;
  final String orderNumber;

  const SupplierRatingDialog({
    super.key,
    required this.supplierId,
    required this.orderId,
    required this.supplierName,
    required this.orderNumber,
  });

  @override
  State<SupplierRatingDialog> createState() => _SupplierRatingDialogState();
}

class _SupplierRatingDialogState extends State<SupplierRatingDialog>
    with TickerProviderStateMixin {
  final AuthStateService _authService = AuthStateService();
  final TextEditingController _feedbackController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  AuthUser? get user => _authService.currentUser;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a rating'),
          backgroundColor: const Color(0xFF6CA04A),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Check if user has already rated this order
      final existingRating = await FirebaseFirestore.instance
          .collection('order_ratings')
          .where('orderId', isEqualTo: widget.orderId)
          .where('buyerId', isEqualTo: user?.uid)
          .limit(1)
          .get();

      if (existingRating.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already rated this order')),
        );
        Navigator.pop(context);
        return;
      }

      // Save rating to Firestore
      await FirebaseFirestore.instance.collection('order_ratings').add({
        'orderId': widget.orderId,
        'supplierId': widget.supplierId,
        'buyerId': user?.uid,
        'rating': _rating,
        'feedback': _feedbackController.text.trim(),
        'orderNumber': widget.orderNumber,
        'supplierName': widget.supplierName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update order with rating status
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'hasRating': true,
        'rating': _rating,
        'ratingTimestamp': FieldValue.serverTimestamp(),
      });

      // Recalculate supplier average rating
      await _updateSupplierRating();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rating submitted successfully!'),
            backgroundColor: const Color(0xFF6CA04A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _updateSupplierRating() async {
    try {
      // Get all ratings for this supplier
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('order_ratings')
          .where('supplierId', isEqualTo: widget.supplierId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

      // Calculate average rating
      double totalRating = 0;
      int ratingCount = 0;

      for (var doc in ratingsSnapshot.docs) {
        final rating = doc['rating'] as int? ?? 0;
        if (rating > 0) {
          totalRating += rating;
          ratingCount++;
        }
      }

      if (ratingCount > 0) {
        final averageRating = totalRating / ratingCount;

        // Update supplier's average rating
        await FirebaseFirestore.instance
            .collection('suppliers')
            .doc(widget.supplierId)
            .update({
          'averageRating': averageRating,
          'ratingCount': ratingCount,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating supplier rating: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rate Experience',
                          style: GoogleFonts.quicksand(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How was your experience with ${widget.supplierName}?',
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            color: const Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = index + 1;
                      });
                      _animationController.forward().then((_) {
                        _animationController.reverse();
                      });
                    },
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: index < _rating ? _scaleAnimation.value : 1.0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: index < _rating 
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFFE0E0E0),
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
              
              if (_rating > 0) ...[
                const SizedBox(height: 16),
                Text(
                  _getRatingText(_rating),
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                      color: const Color(0xFF6CA04A),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Feedback TextField
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE9ECEF),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    color: const Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share your experience (optional)',
                    hintStyle: GoogleFonts.quicksand(
                      fontSize: 16,
                      color: const Color(0xFF9E9E9E),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5F5),
                          foregroundColor: const Color(0xFF757575),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _rating > 0 && !_isSubmitting ? _submitRating : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6CA04A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
    strokeWidth: 2.5, // adjust thickness
    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                ),
                              )
                            : Text(
                                'Submit Rating',
                                style: GoogleFonts.quicksand(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}