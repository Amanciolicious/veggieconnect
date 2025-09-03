// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:veggieconnect/authentication/login_page.dart';
import 'package:veggieconnect/customer-side/buyer_products_page.dart';
import 'package:veggieconnect/customer-side/customer_messages_page.dart';
import 'package:veggieconnect/customer-side/cart_page.dart';
import 'package:veggieconnect/customer-side/favorite_page.dart';
import 'buyer_order_history_page.dart';
import 'farm_locations_page.dart';
import '../widgets/modern_app_bar.dart';
import '../services/cloudinary_service.dart';

// Chat and notification center removed

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  User? get user => FirebaseAuth.instance.currentUser;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showProfileImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Update Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildImageOption(
                  icon: Icons.cloud_upload,
                  label: 'Upload via Cloudinary',
                  onTap: () async {
                    Navigator.pop(context);
                    if (kIsWeb) {
                      await _uploadViaCloudinaryWeb();
                    } else {
                      await _uploadViaCloudinaryMobile();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF6CA04A).withOpacity(0.1),
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
            child: Icon(icon, size: 40, color: Color(0xFF6CA04A)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (image != null && user != null) {
        // Reuse picker for mobile -> upload to Cloudinary instead of local storage
        await _uploadToCloudinaryFromPath(image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadToCloudinaryFromPath(String path) async {
    if (user == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final url = await CloudinaryService.uploadFile(File(path));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'avatarUrl': url});
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile picture updated successfully!'),
          backgroundColor: Color(0xFF6CA04A),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadViaCloudinaryWeb() async {
    if (user == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final bytes = await CloudinaryService.pickImageFromWeb();
      if (bytes == null) {
        Navigator.pop(context);
        return;
      }
      final url = await CloudinaryService.uploadBytes(bytes, fileName: 'avatar_${user!.uid}.jpg');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'avatarUrl': url});
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile picture updated successfully!'),
          backgroundColor: Color(0xFF6CA04A),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadViaCloudinaryMobile() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);
    if (image == null) return;
    await _uploadToCloudinaryFromPath(image.path);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    // Responsive sizing for Infinix Smart 8 (720x1612)
    final isSmallScreen = screenWidth <= 720;
    final responsiveFontSize = isSmallScreen ? screenWidth * 0.045 : 18.0;
    final responsivePadding = isSmallScreen ? screenWidth * 0.03 : 20.0;
    final responsiveMargin = isSmallScreen ? screenWidth * 0.025 : 15.0;
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildModernDrawer(),
      appBar: ModernAppBar(
        title: Text(
          'VeggieConnect',
          style: TextStyle(
            fontSize: responsiveFontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
            color: Colors.black,
          ),
        ),
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onSearchTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BuyerProductsPage(),
            ),
          );
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          FavoritePage(),
          CartPage(),
          BuyerProductsPage(),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF4CAF50),
        color: Colors.white,
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        items: const [
          Icon(Icons.home, size: 30, color: Colors.green),
          Icon(Icons.favorite, size: 30, color: Colors.green),
          Icon(Icons.shopping_cart, size: 30, color: Colors.green),
          Icon(Icons.search, size: 30, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildModernDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
              ),
            ),
            child: DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: StreamBuilder<DocumentSnapshot>(
                stream: user != null 
                  ? FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots()
                  : null,
                builder: (context, snapshot) {
                  final userData = snapshot.data?.data() as Map<String, dynamic>?;
                  final avatarUrl = (userData?['avatarUrl'] ?? userData?['profileImageUrl']) as String?;
                  final displayName = userData?['name'] ?? user?.displayName ?? 'Vegie Lover';
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _showProfileImageOptions,
                        child: Stack(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.white,
                                backgroundImage: avatarUrl != null 
                                  ? NetworkImage(avatarUrl) 
                                  : null,
                                child: avatarUrl == null 
                                  ? const Icon(Icons.person, size: 32, color: Color(0xFF4CAF50))
                                  : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'vegieuser@email.com',
                        style: GoogleFonts.inter(
                          color: Colors.white70, 
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          _buildDrawerItem(Icons.home, 'Home', () {
            Navigator.pop(context);
            setState(() => _selectedIndex = 0);
          }),
          _buildDrawerItem(Icons.favorite_border, 'Favorites', () {
            Navigator.pop(context);
            setState(() => _selectedIndex = 1);
          }),
          _buildDrawerItem(Icons.shopping_cart_outlined, 'Cart', () {
            Navigator.pop(context);
            setState(() => _selectedIndex = 2);
          }),
          _buildDrawerItem(Icons.chat_bubble_outline, 'Messages', () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CustomerMessagesPage()),
            );
          }),
          _buildDrawerItem(Icons.store, 'Browse Products', () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BuyerProductsPage()),
            );
          }),
          _buildDrawerItem(Icons.history, 'Order History', () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BuyerOrderHistoryPage()),
            );
          }),
          _buildDrawerItem(Icons.person_pin, 'Supplier Locations', () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FarmLocationsPage()),
            );
          }),
          const Divider(height: 32),
          _buildDrawerItem(Icons.logout, 'Logout', _logout, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(
        icon, 
        color: isDestructive ? Colors.red : const Color(0xFF4CAF50),
        size: 24,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildHomeTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 720;
    final responsivePadding = isSmallScreen ? screenWidth * 0.03 : 20.0;
    final responsiveMargin = isSmallScreen ? screenWidth * 0.025 : 20.0;
    
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Promotional Banner (responsive sizing)
        Container(
          margin: EdgeInsets.all(responsiveMargin),
          padding: EdgeInsets.all(responsivePadding),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.15),
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BuyerProductsPage(),
                ),
              );
            },
            child: Row(
              children: [
                Icon(
                  Icons.local_offer, 
                  color: const Color(0xFF4CAF50), 
                  size: isSmallScreen ? 20 : 24
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get 40% discount on your first order from app.',
                        style: TextStyle(
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 3 : 5),
                      Text(
                        'Shop Now',
                        style: TextStyle(
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.w500,
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.eco, 
                  color: const Color(0xFF4CAF50), 
                  size: isSmallScreen ? 28 : 32
                ),
              ],
            ),
          ),
        ),
        
        // Categories Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveMargin),
          child: Text(
            'Categories', 
            style: TextStyle(
              fontSize: isSmallScreen ? screenWidth * 0.045 : 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 15),
        
        // Categories Grid
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveMargin),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: isSmallScreen ? 12 : 15,
            mainAxisSpacing: isSmallScreen ? 12 : 15,
            childAspectRatio: isSmallScreen ? 1.1 : 1.2,
            children: [
              _buildCategoryCard(
                'Leafy Greens',
                Icons.eco,
                const Color(0xFF4CAF50),
                () => _navigateToCategory('Leafy Greens'),
                isSmallScreen,
              ),
              _buildCategoryCard(
                'Root Vegetables',
                Icons.grass,
                const Color(0xFF8BC34A),
                () => _navigateToCategory('Root Vegetables'),
                isSmallScreen,
              ),
              _buildCategoryCard(
                'Fruits',
                Icons.apple,
                const Color(0xFFFF9800),
                () => _navigateToCategory('Fruits'),
                isSmallScreen,
              ),
              _buildCategoryCard(
                'Herbs & Spices',
                Icons.local_florist,
                const Color(0xFF9C27B0),
                () => _navigateToCategory('Herbs & Spices'),
                isSmallScreen,
              ),
              _buildCategoryCard(
                'Organic',
                Icons.verified,
                const Color(0xFF2196F3),
                () => _navigateToCategory('Organic'),
                isSmallScreen,
              ),
              _buildCategoryCard(
                'Seasonal',
                Icons.wb_sunny,
                const Color(0xFFFFC107),
                () => _navigateToCategory('Seasonal'),
                isSmallScreen,
              ),
            ],
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 25 : 30),
        
        // Popular Products Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveMargin),
          child: Text(
            'Popular Products', 
            style: TextStyle(
              fontSize: isSmallScreen ? screenWidth * 0.045 : 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 15),
        
        // Popular Products Stream
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveMargin),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('status', isEqualTo: 'approved')
                .where('isVerified', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .limit(6)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                  ),
                );
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_basket_outlined,
                        size: isSmallScreen ? 40 : 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: isSmallScreen ? 10 : 12),
                      Text(
                        'No products available yet.',
                        style: TextStyle(
                          fontSize: isSmallScreen ? screenWidth * 0.04 : 16,
                          color: Colors.grey[600],
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Text(
                        'Check back later for fresh produce!',
                        style: TextStyle(
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 14,
                          color: Colors.grey[500],
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: isSmallScreen ? 12 : 15,
                  mainAxisSpacing: isSmallScreen ? 12 : 15,
                  childAspectRatio: isSmallScreen ? 0.75 : 0.8,
                ),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return _buildProductCard(
                    data['name'] ?? 'Unknown Product',
                    data['price']?.toString() ?? '0',
                    data['imageUrl'] ?? '',
                    data['unit'] ?? 'kg',
                    () => _navigateToProductDetails(doc.id, data),
                    isSmallScreen,
                  );
                },
              );
            },
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color, VoidCallback onTap, bool isSmallScreen) {
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = isSmallScreen ? screenWidth * 0.03 : 16.0;
    final responsiveIconSize = isSmallScreen ? screenWidth * 0.06 : 28.0;
    final responsiveFontSize = isSmallScreen ? screenWidth * 0.032 : 14.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(responsivePadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              ),
              child: Icon(
                icon,
                color: color,
                size: responsiveIconSize,
              ),
            ),
            SizedBox(height: isSmallScreen ? 10 : 12),
            Text(
              title,
              style: TextStyle(
                fontSize: responsiveFontSize,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(String name, String price, String imageUrl, String unit, VoidCallback onTap, bool isSmallScreen) {
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = isSmallScreen ? screenWidth * 0.025 : 12.0;
    final responsiveFontSize = isSmallScreen ? screenWidth * 0.032 : 14.0;
    final responsivePriceFontSize = isSmallScreen ? screenWidth * 0.03 : 13.0;
    final responsiveIconSize = isSmallScreen ? 18.0 : 20.0;
    final responsiveImageIconSize = isSmallScreen ? 35.0 : 40.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isSmallScreen ? 12 : 16),
                    topRight: Radius.circular(isSmallScreen ? 12 : 16),
                  ),
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isSmallScreen ? 12 : 16),
                          topRight: Radius.circular(isSmallScreen ? 12 : 16),
                        ),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[400],
                              size: responsiveImageIconSize,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                        size: responsiveImageIconSize,
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(responsivePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: responsiveFontSize,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '₱$price/$unit',
                            style: TextStyle(
                              fontSize: responsivePriceFontSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4CAF50),
                              fontFamily: 'Poppins',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.add_circle,
                          color: const Color(0xFF4CAF50),
                          size: responsiveIconSize,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerProductsPage(categoryFilter: category),
      ),
    );
  }

  void _navigateToProductDetails(String productId, Map<String, dynamic> productData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerProductsPage(),
      ),
    );
  }
}

class _VeggieCard extends StatelessWidget {
  final String name;
  final IconData image;
  const _VeggieCard({required this.name, required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(image, color: const Color(0xFF4CAF50), size: 24),
          const SizedBox(height: 10),
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
          const SizedBox(height: 6),
          Icon(Icons.favorite_border, color: Colors.black26),
        ],
      ),
    );
  }
}

// Placeholder tab widgets
class _AddTab extends StatelessWidget {
  const _AddTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 64,
            color: Color(0xFF4CAF50),
          ),
          SizedBox(height: 16),
          Text(
            'Add New Item',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create new content or listings',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 64,
            color: Color(0xFF4CAF50),
          ),
          SizedBox(height: 16),
          Text(
            'Notifications',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Stay updated with latest alerts',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: Color(0xFF4CAF50),
          ),
          SizedBox(height: 16),
          Text(
            'Profile',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manage your account settings',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}