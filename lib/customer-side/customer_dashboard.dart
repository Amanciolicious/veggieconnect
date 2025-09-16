// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, library_private_types_in_public_api
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:veggieconnect/authentication/login_page.dart';
import 'package:veggieconnect/customer-side/customer_buyer_products_page.dart';
import 'package:veggieconnect/customer-side/customer_product_details_page.dart';
import 'package:veggieconnect/customer-side/customer_messages_page.dart';
import 'package:veggieconnect/customer-side/customer_cart_page.dart';
import 'package:veggieconnect/customer-side/customer_favorite_page.dart';
import 'package:veggieconnect/customer-side/customer_profile_page.dart';
import 'customer_order_history_page.dart';
import 'customer_locations_page.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/notification_center.dart';
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart';
import '../widgets/lottie_loading_widget.dart';
import '../widgets/modern_wave_drawer.dart';
import '../services/auth_state_service.dart';

// Chat and notification center removed

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthStateService _authService = AuthStateService();

  AuthUser? get user => _authService.currentUser;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await _authService.signOut();
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
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadToCloudinaryFromPath(String path) async {
    if (user == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: GroceryLoadingWidget(
            size: 100,
            showText: true,
            loadingText: 'Uploading...',
          ),
        ),
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
        builder: (context) => const Center(
          child: GroceryLoadingWidget(
            size: 100,
            showText: true,
            loadingText: 'Uploading...',
          ),
        ),
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

  void _showQuickActionModal(String title, IconData icon, Color color, String filterType) {
    showDialog(
      context: context,
      builder: (context) => QuickActionModal(
        title: title,
        icon: icon,
        color: color,
        filterType: filterType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug authentication state
    print('🔧 Dashboard: Building dashboard - user: ${user?.uid}');
    print('🔧 Dashboard: AuthService authenticated: ${_authService.isAuthenticated}');
    
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive sizing for Infinix Smart 8 (720x1612)
    final isSmallScreen = screenWidth <= 720;
    final responsiveFontSize = isSmallScreen ? screenWidth * 0.045 : 18.0;
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildModernDrawer(),
      appBar: ModernAppBar(
        title: Text(
          'VeggieConnect',
          style: GoogleFonts.quicksand(
            fontSize: responsiveFontSize,
            fontWeight: FontWeight.bold,
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
        actions: [
          StreamBuilder<int>(
            stream: NotificationService().getUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () async {
                      // Mark all notifications as read when opening notification center
                      NotificationService().markAllAsRead();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationCenter(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.notifications,
                      color: Colors.black,
                      size: responsiveFontSize * 1.2,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          CustomerFavoritePage(),
          CartPage(),
          BuyerProductsPage(),
          ProfilePage()
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
          Icon(Icons.person, size: 30, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildModernDrawer() {
    return StreamBuilder<DocumentSnapshot>(
      stream: user != null 
        ? FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots()
        : null,
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final avatarUrl = (userData?['avatarUrl'] ?? userData?['profileImageUrl']) as String?;
        final displayName = userData?['name'] ?? user?.displayName ?? 'Vegie Lover';
        final email = user?.email ?? 'vegieuser@email.com';
        
        return ModernWaveDrawer(
          selectedIndex: _selectedIndex,
          onItemTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            Navigator.pop(context);
          },
          headerName: displayName,
          headerEmail: email,
          headerAvatarUrl: avatarUrl,
          onHeaderTap: _showProfileImageOptions,
          items: [], // Empty since we're using sections
          sections: [
            DrawerSection(
              title: 'MAIN NAVIGATION',
              items: [
                DrawerItem(icon: Icons.home, title: 'Home', index: 0),
                DrawerItem(icon: Icons.favorite, title: 'Favorites', index: 1),
                DrawerItem(icon: Icons.shopping_cart, title: 'Cart', index: 2),
                DrawerItem(icon: Icons.store, title: 'Browse', index: 3),
                DrawerItem(icon: Icons.person, title: 'Profile', index: 4),
              ],
            ),
            DrawerSection(
              title: 'SERVICES',
              items: [
                DrawerItem(
                  icon: Icons.message, 
                  title: 'Messages', 
                  index: -1, 
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CustomerMessagesPage()),
                    );
                  }
                ),
                DrawerItem(
                  icon: Icons.history,
                  title: 'Order History',
                  index: -1,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BuyerOrderHistoryPage()),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.person_pin,
                  title: 'My Locations',
                  index: -1,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FarmLocationsPage()),
                    );
                  },
                ),
              ],
            ),
            DrawerSection(
              title: 'ACCOUNT',
              items: [
                DrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  index: -1,
                  isDestructive: true,
                  onTap: _logout,
                ),
              ],
            ),
          ],
        );
      },
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
                        style: GoogleFonts.quicksand(
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 3 : 5),
                      Text(
                        'Shop Now',
                        style: GoogleFonts.quicksand(
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.w500,
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 14,
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
        
        // Quick Actions Hub Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveMargin),
          child: Text(
            'Quick Actions', 
            style: GoogleFonts.quicksand(
              fontSize: isSmallScreen ? screenWidth * 0.045 : 18,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 15),
        
        // Quick Actions Grid
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
              _buildQuickActionCard(
                'Cash on Pickup',
                Icons.local_shipping,
                const Color(0xFF4CAF50),
                () => _showQuickActionModal('Cash on Pickup', Icons.local_shipping, const Color(0xFF4CAF50), 'cashOnPickup'),
                isSmallScreen,
                _buildCashOnPickupBadge(),
              ),
              _buildQuickActionCard(
                'Fresh Today',
                Icons.schedule,
                const Color(0xFF2196F3),
                () => _showQuickActionModal('Fresh Today', Icons.schedule, const Color(0xFF2196F3), 'freshToday'),
                isSmallScreen,
                _buildFreshTodayBadge(),
              ),
              _buildQuickActionCard(
                'Top Rated',
                Icons.star,
                const Color(0xFFFF9800),
                () => _showQuickActionModal('Top Rated', Icons.star, const Color(0xFFFF9800), 'topRated'),
                isSmallScreen,
                _buildTopRatedBadge(),
              ),
              _buildQuickActionCard(
                'Near Me',
                Icons.location_on,
                const Color(0xFF9C27B0),
                () => _showQuickActionModal('Near Me', Icons.location_on, const Color(0xFF9C27B0), 'nearMe'),
                isSmallScreen,
                _buildNearMeBadge(),
              ),
              _buildQuickActionCard(
                'Best Deals',
                Icons.local_offer,
                const Color(0xFFF44336),
                () => _showQuickActionModal('Best Deals', Icons.local_offer, const Color(0xFFF44336), 'bestDeals'),
                isSmallScreen,
                _buildBestDealsBadge(),
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
            style: GoogleFonts.quicksand(
              fontSize: isSmallScreen ? screenWidth * 0.045 : 18,
              fontWeight: FontWeight.w400,
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
                .limit(50) // Increased limit to get more products for filtering
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: GroceryLoadingWidget(
                    size: 120,
                    showText: true,
                    loadingText: 'Loading products...',
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
                        style: GoogleFonts.quicksand(
                          fontSize: isSmallScreen ? screenWidth * 0.04 : 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Text(
                        'Check back later for fresh produce!',
                        style: GoogleFonts.quicksand(
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 14,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              
              // Filter products with favorites and sort by popularity
              final sortedDocs = snapshot.data!.docs
                  .where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Check if product is active (default to true if field doesn't exist)
                    final isActive = data['isActive'] ?? true;
                    if (!isActive) return false;
                    
                    // Check favorite count (default to 0 if field doesn't exist)
                    final favoriteCount = (data['favoriteCount'] ?? 0) as num;
                    return favoriteCount > 0;
                  })
                  .toList()
                ..sort((a, b) {
                  final ap = ((a.data() as Map<String, dynamic>)['favoriteCount'] ?? 0) as num;
                  final bp = ((b.data() as Map<String, dynamic>)['favoriteCount'] ?? 0) as num;
                  return bp.compareTo(ap);
                });

              // If no popular products found, show all approved products instead
              if (sortedDocs.isEmpty) {
                final allProducts = snapshot.data!.docs
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isActive = data['isActive'] ?? true;
                      return isActive;
                    })
                    .toList();
                
                if (allProducts.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: isSmallScreen ? 40 : 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),
                        Text(
                          'No popular products yet.',
                          style: GoogleFonts.quicksand(
                            fontSize: isSmallScreen ? screenWidth * 0.04 : 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Text(
                          'Start favoriting products to see them here!',
                          style: GoogleFonts.quicksand(
                            fontSize: isSmallScreen ? screenWidth * 0.035 : 14,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                // Show recent products if no popular ones exist
                sortedDocs.addAll(allProducts.take(6));
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
                itemCount: sortedDocs.length > 6 ? 6 : sortedDocs.length,
                itemBuilder: (context, index) {
                  final doc = sortedDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final productId = doc.id;
                  final favoriteCount = (data['favoriteCount'] ?? 0) as num;
                  
                  
                  return GestureDetector(
                    onTap: () => _navigateToProductDetails(doc.id, data),
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
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1.4,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(isSmallScreen ? 12 : 16),
                                      topRight: Radius.circular(isSmallScreen ? 12 : 16),
                                    ),
                                  ),
                                  child: data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(isSmallScreen ? 12 : 16),
                                            topRight: Radius.circular(isSmallScreen ? 12 : 16),
                                          ),
                                          child: Image.network(
                                            data['imageUrl'],
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey[400],
                                          size: isSmallScreen ? 35.0 : 40.0,
                                        ),
                                ),
                              ),
                              Padding(
                              padding: EdgeInsets.all(isSmallScreen ? screenWidth * 0.025 : 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    data['name'] ?? 'Unknown Product',
                                    style: GoogleFonts.quicksand(
                                      fontSize: isSmallScreen ? screenWidth * 0.032 : 14.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '₱${(data['price'] ?? 0).toStringAsFixed(2)}/${data['unit'] ?? 'kg'}',
                                          style: GoogleFonts.quicksand(
                                            fontSize: isSmallScreen ? screenWidth * 0.03 : 13.0,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF4CAF50),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Favorite count indicator (only show if > 0)
                                      if (favoriteCount > 0)
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.favorite,
                                                color: Colors.red,
                                                size: isSmallScreen ? 10 : 12,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                '$favoriteCount',
                                                style: GoogleFonts.quicksand(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isSmallScreen ? screenWidth * 0.025 : 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              ),
                          ],
                        ),
                        // Favorite button positioned over the image
                        Positioned(
                          top: 8,
                          right: 8,
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: user != null 
                              ? FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots()
                              : null,
                            builder: (context, userSnap) {
                              if (!userSnap.hasData) {
                                return const SizedBox.shrink();
                              }
                              final userData = userSnap.data!.data() as Map<String, dynamic>?;
                              final favorites = List<String>.from(userData?['favorites'] ?? []);
                              final isFavorite = favorites.contains(productId);
                              
                              return GestureDetector(
                                onTap: () => _toggleFavorite(productId),
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.3),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorite ? Colors.red : Colors.grey[600],
                                    size: 16,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
            });
            },
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap, bool isSmallScreen, Widget badge) {
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
              style: GoogleFonts.quicksand(
                fontSize: responsiveFontSize,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            badge,
          ],
        ),
      ),
    );
  }

  Widget _buildCashOnPickupBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('paymentMethod', isEqualTo: 'cashOnPickup')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count+',
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  Widget _buildFreshTodayBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isFreshToday', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count+',
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  Widget _buildTopRatedBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('rating', isGreaterThanOrEqualTo: 4.5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count+',
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  Widget _buildNearMeBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('location', isEqualTo: 'nearMe')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count+',
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  Widget _buildBestDealsBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isBestDeal', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count+',
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  void _navigateToProductDetails(String productId, Map<String, dynamic> productData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(product: productData, productId: productId),
      ),
    );
  }

  Future<void> _toggleFavorite(String productId) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add favorites.')),
      );
      return;
    }

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final userData = await userDoc.get();
      
      if (!userData.exists) {
        await userDoc.set({
          'favorites': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      final favorites = List<String>.from((userData.data())?['favorites'] ?? []);
      
      if (favorites.contains(productId)) {
        // Remove from favorites
        favorites.remove(productId);
        await userDoc.update({
          'favorites': favorites,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _updateProductFavoriteCount(productId, -1);
        
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
        await _updateProductFavoriteCount(productId, 1);
        
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
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorites: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProductFavoriteCount(String productId, int change) async {
    try {
      final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productDoc = await transaction.get(productRef);
        if (productDoc.exists) {
          final currentFavoriteCount = (productDoc.data()?['favoriteCount'] ?? 0) as num;
          final nextValue = (currentFavoriteCount + change).clamp(0, double.maxFinite.toInt());
          transaction.update(productRef, {
            'favoriteCount': nextValue,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // If product doesn't exist, initialize with proper count
          if (change > 0) {
            transaction.set(productRef, {
              'favoriteCount': change.clamp(0, double.maxFinite.toInt()),
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to update product favorite count: $e');
      // If transaction fails, try a direct update as fallback
      try {
        final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
        final productDoc = await productRef.get();
        if (productDoc.exists) {
          final currentFavoriteCount = (productDoc.data()?['favoriteCount'] ?? 0) as num;
          final nextValue = (currentFavoriteCount + change).clamp(0, double.maxFinite.toInt());
          await productRef.update({
            'favoriteCount': nextValue,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else if (change > 0) {
          // Initialize product with favorite count if it doesn't exist
          await productRef.set({
            'favoriteCount': change.clamp(0, double.maxFinite.toInt()),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (fallbackError) {
        debugPrint('Fallback favorite count update also failed: $fallbackError');
      }
    }
  }
}

// Quick Action Modal Widget
class QuickActionModal extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String filterType;

  const QuickActionModal({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.filterType,
  });

  @override
  _QuickActionModalState createState() => _QuickActionModalState();
}

class _QuickActionModalState extends State<QuickActionModal> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: widget.color,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getFilteredProductsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.icon,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No ${widget.title.toLowerCase()} products found',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredDocs = _filterProducts(snapshot.data!.docs);

                  return Column(
                    children: [
                      // Count header
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${filteredDocs.length} products found',
                          style: GoogleFonts.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.color,
                          ),
                        ),
                      ),
                      // Products list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildProductCard(doc.id, data);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Footer with action button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToFullProductsPage();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'View All ${widget.title}',
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
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredProductsStream() {
    return FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .limit(20)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterProducts(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isActive = data['isActive'] ?? true;
      
      if (!isActive) return false;

      switch (widget.filterType) {
        case 'cashOnPickup':
          final paymentMethods = List<String>.from(data['paymentMethods'] ?? []);
          return paymentMethods.contains('cashOnPickup');
        
        case 'freshToday':
          return data['isFreshToday'] ?? false;
        
        case 'topRated':
          final rating = (data['rating'] ?? 0.0) as num;
          return rating >= 4.5;
        
        case 'nearMe':
          // For now, return all products. Location filtering would need user's location
          return true;
        
        case 'bestDeals':
          final price = (data['price'] ?? 0) as num;
          return price <= 50;
        
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildProductCard(String productId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty
                  ? Image.network(
                      data['imageUrls'][0],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
            ),
            const SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? 'Unknown Product',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${(data['price'] ?? 0).toStringAsFixed(2)}',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6CA04A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildProductBadge(data),
                ],
              ),
            ),
            // Action button
            IconButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(
                      product: data,
                      productId: productId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_ios),
              color: widget.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductBadge(Map<String, dynamic> data) {
    String badgeText = '';
    Color badgeColor = widget.color;

    switch (widget.filterType) {
      case 'cashOnPickup':
        badgeText = 'Cash on Pickup';
        break;
      case 'freshToday':
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final now = DateTime.now();
          final created = createdAt.toDate();
          final hoursAgo = now.difference(created).inHours;
          badgeText = '${hoursAgo}h ago';
        } else {
          badgeText = 'Fresh Today';
        }
        break;
      case 'topRated':
        final rating = (data['rating'] ?? 0.0) as num;
        badgeText = '⭐ ${rating.toStringAsFixed(1)}';
        break;
      case 'nearMe':
        badgeText = 'Nearby';
        break;
      case 'bestDeals':
        badgeText = 'Best Deal';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Text(
        badgeText,
        style: GoogleFonts.quicksand(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  void _navigateToFullProductsPage() {
    switch (widget.filterType) {
      case 'cashOnPickup':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuyerProductsPage(paymentMethodFilter: 'cashOnPickup'),
          ),
        );
        break;
      case 'freshToday':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuyerProductsPage(isFreshTodayFilter: true),
          ),
        );
        break;
      case 'topRated':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuyerProductsPage(ratingFilter: 4.5),
          ),
        );
        break;
      case 'nearMe':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuyerProductsPage(locationFilter: 'nearMe'),
          ),
        );
        break;
      case 'bestDeals':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuyerProductsPage(isBestDealFilter: true),
          ),
        );
        break;
    }
  }
}