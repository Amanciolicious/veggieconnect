// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'star_rating_widget.dart';

class ProductFeedbackModal extends StatefulWidget {
  final String productId;
  final String supplierId;
  final String productName;

  const ProductFeedbackModal({
    super.key,
    required this.productId,
    required this.supplierId,
    required this.productName,
  });

  @override
  State<ProductFeedbackModal> createState() => _ProductFeedbackModalState();
}

class _ProductFeedbackModalState extends State<ProductFeedbackModal> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                      'Customer Reviews',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
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
                    child: Text(
                      widget.productName,
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(height: 1, color: Colors.grey[300]),
            
            // Reviews List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('order_ratings')
                    .where('products', arrayContains: {
                      'productId': widget.productId,
                    })
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
                        ),
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star_border,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Be the first to review this product!',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Colors.grey[500],
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  final reviews = snapshot.data!.docs;
                  
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index].data() as Map<String, dynamic>;
                      final rating = review['rating'] ?? 0;
                      final feedback = review['feedback'] ?? '';
                      final buyerName = review['buyerName'] ?? 'Anonymous';
                      final timestamp = review['timestamp'] as Timestamp?;
                      final dateStr = timestamp != null 
                        ? _formatDate(timestamp.toDate())
                        : 'Unknown date';
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: screenWidth * 0.04),
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with name, rating, and date
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: screenWidth * 0.04,
                                  backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                                  child: Text(
                                    buyerName.isNotEmpty ? buyerName[0].toUpperCase() : 'A',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6CA04A),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        buyerName,
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF333333),
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.032,
                                          color: Colors.grey[600],
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StarRatingDisplay(
                                  rating: rating.toDouble(),
                                  size: screenWidth * 0.04,
                                  showRatingText: false,
                                ),
                              ],
                            ),
                            
                            SizedBox(height: screenWidth * 0.03),
                            
                            // Rating stars
                            StarRatingDisplay(
                              rating: rating.toDouble(),
                              size: screenWidth * 0.045,
                              showRatingText: true,
                            ),
                            
                            // Feedback text
                            if (feedback.isNotEmpty) ...[
                              SizedBox(height: screenWidth * 0.03),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  feedback,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Color(0xFF555555),
                                    fontFamily: 'Poppins',
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
