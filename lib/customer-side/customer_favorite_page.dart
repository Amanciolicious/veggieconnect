// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/product_image_widget.dart';
import 'customer_product_details_page.dart';
import '../widgets/lottie_loading_widget.dart';
import 'package:flutter/material.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'My Favorites',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        elevation: 0,
      ),
      body: user == null
          ? Center(
              child: Container(
                margin: EdgeInsets.all(screenWidth * 0.08),
                padding: EdgeInsets.all(screenWidth * 0.08),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                      Icons.favorite_border,
                      size: screenWidth * 0.15,
                      color: Color(0xFF6CA04A),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    Text(
                      'Please log in to view favorites',
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.06,
                        color: Color(0xFF6CA04A),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: GroceryLoadingWidget(
                      size: 120,
                      showText: true,
                      loadingText: 'Loading favorites...',
                    ),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildEmptyFavorites(screenWidth);
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final favorites = List<String>.from(userData['favorites'] ?? []);

                if (favorites.isEmpty) {
                  return _buildEmptyFavorites(screenWidth);
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .where(FieldPath.documentId, whereIn: favorites)
                      .where('isVerified', isEqualTo: true)
                      .snapshots(),
                  builder: (context, productsSnapshot) {
                    if (productsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: GroceryLoadingWidget(
                          size: 120,
                          showText: true,
                          loadingText: 'Loading products...',
                        ),
                      );
                    }

                    if (!productsSnapshot.hasData || productsSnapshot.data!.docs.isEmpty) {
                      return _buildEmptyFavorites(screenWidth);
                    }

                    final products = productsSnapshot.data!.docs;
                    return Padding(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Favorite Products',
                            style: GoogleFonts.quicksand(
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 20),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.6,
                              ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index].data() as Map<String, dynamic>;
                                final productId = products[index].id;
                                
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductDetailsPage(
                                          product: product,
                                          productId: productId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                                  color: Color(0xFFF8FAF5),
                                                ),
                                                child: ProductImageWidget(
                                                  imagePath: product['imageUrl'] ?? '',
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  placeholder: Icon(
                                                    Icons.shopping_basket,
                                                    size: screenWidth * 0.12,
                                                    color: Color(0xFF6CA04A),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: GestureDetector(
                                                  onTap: () => _toggleFavorite(productId),
                                                  child: Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.grey.withOpacity(0.2),
                                                          spreadRadius: 1,
                                                          blurRadius: 3,
                                                          offset: Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      Icons.favorite,
                                                      color: Colors.red,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product['name'] ?? 'Unknown Product',
                                                  style: GoogleFonts.quicksand(
                                                    fontSize: screenWidth * 0.04,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  product['supplierName'] ?? 'Unknown Supplier',
                                                  style: GoogleFonts.quicksand(
                                                    fontSize: screenWidth * 0.032,
                                                    color: Color(0xFF757575),
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Spacer(),
                                                Text(
                                                  '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}/${product['unit'] ?? 'unit'}',
                                                  style: GoogleFonts.quicksand(
                                                    fontSize: screenWidth * 0.04,
                                                    color: Color(0xFF6CA04A),
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
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyFavorites(double screenWidth) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(screenWidth * 0.08),
        padding: EdgeInsets.all(screenWidth * 0.08),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
              Icons.favorite_border,
              size: screenWidth * 0.15,
              color: Color(0xFF6CA04A),
            ),
            SizedBox(height: screenWidth * 0.04),
            Text(
              'No favorites yet',
              style: GoogleFonts.quicksand(
                fontSize: screenWidth * 0.06,
                color: Color(0xFF6CA04A),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenWidth * 0.02),
            Text(
              'Start browsing products and add them to your favorites!',
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

  Future<void> _toggleFavorite(String productId) async {
    if (user == null) return;
    
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final userData = await userDoc.get();
      final favorites = List<String>.from(userData.data()?['favorites'] ?? []);
      
      if (favorites.contains(productId)) {
        // Remove from favorites
        favorites.remove(productId);
        await userDoc.update({
          'favorites': favorites,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _updateProductPopularity(productId, -1);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Add to favorites
        favorites.add(productId);
        await userDoc.update({
          'favorites': favorites,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _updateProductPopularity(productId, 1);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites'),
              backgroundColor: Color(0xFF6CA04A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProductPopularity(String productId, int change) async {
    try {
      final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productDoc = await transaction.get(productRef);
        if (productDoc.exists) {
          final currentPopularity = (productDoc.data()?['popularity'] ?? 0) as num;
          final nextValue = (currentPopularity + change).clamp(0, 1 << 31);
          transaction.update(productRef, {
            'popularity': nextValue,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('Failed to update product popularity: $e');
      // If transaction fails, try a direct update as fallback
      try {
        final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
        final productDoc = await productRef.get();
        if (productDoc.exists) {
          final currentPopularity = (productDoc.data()?['popularity'] ?? 0) as num;
          final nextValue = (currentPopularity + change).clamp(0, 1 << 31);
          await productRef.update({
            'popularity': nextValue,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      } catch (fallbackError) {
        debugPrint('Fallback popularity update also failed: $fallbackError');
      }
    }
  }
}