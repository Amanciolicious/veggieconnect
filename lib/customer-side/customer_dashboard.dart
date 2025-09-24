// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, library_private_types_in_public_api
import 'dart:io';
import 'dart:async';
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

// App-wide helper to append a cache-busting query param based on last update time
String _versionedImageUrl(dynamic url, dynamic updatedAt) {
  final base = (url ?? '').toString();
  if (base.isEmpty) return base;
  int version = 0;
  try {
    if (updatedAt is Timestamp) {
      version = updatedAt.millisecondsSinceEpoch;
    } else if (updatedAt is DateTime) {
      version = updatedAt.millisecondsSinceEpoch;
    }
  } catch (_) {}
  if (version == 0) return base;
  final separator = base.contains('?') ? '&' : '?';
  return '$base${separator}v=$version';
}

// Resolve a product's primary image URL from various possible fields
String _resolveProductImageUrl(Map<String, dynamic> data) {
  final direct = (data['imageUrl'] ?? data['image'] ?? '') as String?;
  if (direct != null && direct.isNotEmpty) return direct;
  final images = data['images'];
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is String && first.isNotEmpty) return first;
    if (first is Map && first['url'] is String && (first['url'] as String).isNotEmpty) {
      return first['url'] as String;
    }
  }
  final photo = data['photoUrl'];
  if (photo is String && photo.isNotEmpty) return photo;
  return '';
}

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthStateService _authService = AuthStateService();
  late final ValueNotifier<int> _carouselIndexNotifier = ValueNotifier<int>(0);
  
  // Add PageController and Timer for auto-scroll
  late PageController _carouselPageController;
  Timer? _carouselTimer;
  final int _totalCarouselPages = 5;

  AuthUser? get user => _authService.currentUser;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    // Trigger sign out instantly (AuthStateService clears state synchronously)
    unawaited(_authService.signOut());
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
  void initState() {
    super.initState();
    _carouselPageController = PageController();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _carouselPageController.dispose();
    _carouselTimer?.cancel();
    _carouselIndexNotifier.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final idx = _carouselIndexNotifier.value;
      if (idx < _totalCarouselPages - 1) {
        _carouselPageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _carouselPageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Debug authentication state
    print('🔧 Dashboard: Building dashboard - user: ${user?.uid}');
    print('🔧 Dashboard: AuthService authenticated: ${_authService.isAuthenticated}');
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildModernDrawer(),
      appBar: _selectedIndex == 0 ? ModernAppBar(
        title: Text(
          'VeggieConnect',
          style: GoogleFonts.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
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
                      color: Color(0xFF4CAF50),
                      size: 24
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
      ) : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          const CustomerFavoritePage(),
          const CartPage(),
          BuyerProductsPage(),
          const ProfilePage()
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Color(0xFF4CAF50),
        color: Colors.white,
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        items: [
          const Icon(Icons.home, size: 30, color: Colors.green),
          const Icon(Icons.favorite, size: 30, color: Colors.green),
          _buildCartNavIcon(),
          const Icon(Icons.search, size: 30, color: Colors.green),
          const Icon(Icons.person, size: 30, color: Colors.green),
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

  // Real-time cart count for bottom navigation badge
  Stream<int> _cartItemCountStream() {
    if (user == null) {
      return Stream.value(0);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final quantity = (data['quantity'] ?? 1) as num;
        total += quantity.toInt();
      }
      return total;
    });
  }

  Widget _buildCartNavIcon() {
    return StreamBuilder<int>(
      stream: _cartItemCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_cart, size: 30, color: Colors.green),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 99 ? '99+' : '$count',
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
                  size: 28
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get 40% discount on your first order from app.',
                        style: GoogleFonts.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Shop Now',
                        style: GoogleFonts.quicksand(
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.eco, 
                  color: const Color(0xFF4CAF50), 
                  size: 32
                ),
              ],
            ),
          ),
        ),      
        SizedBox(height: 20),
        // Smart Shopping Carousel
        Container(
          margin: EdgeInsets.all(responsiveMargin),
          height: isSmallScreen ? 120 : 140,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _carouselPageController,
                  onPageChanged: (index) {
                    // Avoid rebuilding the whole page; notify only listeners of index
                    _carouselIndexNotifier.value = index;
                  },
                  children: [
                    _buildSmartCard('Personalized for You', '40% off your favorites', Icons.person_outline, const Color(0xFF4CAF50), isSmallScreen, screenWidth),
                    _buildSmartCard('Fresh Today', 'Just harvested produce', Icons.eco, const Color(0xFF2196F3), isSmallScreen, screenWidth),
                    _buildSmartCard('Trending Now', "Everyone's buying", Icons.trending_up, const Color(0xFF9C27B0), isSmallScreen, screenWidth),
                    _buildSmartCard('Flash Sale', 'Limited time deals', Icons.flash_on, const Color(0xFFFF5722), isSmallScreen, screenWidth),
                    _buildSmartCard('Community Choice', 'Most loved items', Icons.favorite, const Color(0xFFE91E63), isSmallScreen, screenWidth),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: _carouselIndexNotifier,
                builder: (_, value, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: value == index ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: value == index
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Quick Actions moved below the carousel for standard layout
        SizedBox(height: isSmallScreen ? 20 : 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveMargin),
          child: Text(
            'Quick Actions',
            style: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 15),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveMargin),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isSmallScreen ? 3 : 4,
            crossAxisSpacing: isSmallScreen ? 10 : 12,
            mainAxisSpacing: isSmallScreen ? 10 : 12,
            childAspectRatio: isSmallScreen ? 1.1 : 1.25,
            children: [
              _buildQuickActionCard(
                'Cash on Pickup',
                Icons.handshake,
                const Color(0xFF4CAF50),
                () => _showQuickActionModal('Cash on Pickup', Icons.handshake, const Color(0xFF4CAF50), 'cashOnPickup'),
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
              _buildQuickActionCard(
                'Popular Products',
                Icons.favorite,
                const Color(0xFFE91E63),
                () => _showQuickActionModal('Popular Products', Icons.favorite, const Color(0xFFE91E63), 'popular'),
                isSmallScreen,
                _buildPopularBadge(),
              ),
            ],
          ),
        ),

        SizedBox(height: isSmallScreen ? 25 : 30),

        // Popular Products (favoriteCount > 0, ranked desc, hide when empty)
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('status', isEqualTo: 'approved')
              .where('isActive', isEqualTo: true)
              .where('favoriteCount', isGreaterThan: 0)
              .orderBy('favoriteCount', descending: true)
              .limit(6)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            final docs = snapshot.data!.docs;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: responsiveMargin),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: isSmallScreen ? 12 : 15,
                      mainAxisSpacing: isSmallScreen ? 12 : 15,
                      childAspectRatio: isSmallScreen ? 0.75 : 0.8,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final productId = doc.id;
                      final favoriteCount = (data['favoriteCount'] ?? 0) as num;
                     return GestureDetector(
  onTap: () => _navigateToProductDetails(productId, data),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Stack(
      children: [
        // Product Image
        ClipRRect(
          borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
          child: (() {
                final img = _resolveProductImageUrl(data);
                if (img.isNotEmpty) {
                  return Image.network(
                    _versionedImageUrl(img, data['updatedAt']),
                    key: ValueKey(_versionedImageUrl(img, data['updatedAt'])),
                    width: double.infinity,
                    height: isSmallScreen ? screenWidth * 0.3 : 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  );
                }
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.grey),
                );
              })()
        ),
        // Favorite Count Badge
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$favoriteCount♥',
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontSize: isSmallScreen ? 10 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Product Info Overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(isSmallScreen ? 8 : 10),
                bottomRight: Radius.circular(isSmallScreen ? 8 : 10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Unknown Product',
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${(data['price'] ?? 0).toStringAsFixed(2)}',
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
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
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // New method for Smart Shopping Carousel
  Widget _buildSmartCard(String title, String subtitle, IconData icon, Color color, bool isSmallScreen, double screenWidth) {
    return GestureDetector(
      onTap: () => _handleSmartCardTap(title),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(icon, size: 60, color: Colors.white.withOpacity(0.1)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<String>(
                          stream: _getSmartSubtitle(title),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.data ?? subtitle,
                              style: GoogleFonts.quicksand(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.8), size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated method for Smart Shopping Carousel
  void _handleSmartCardTap(String title) {
    if (title.contains('Fresh')) {
      _showQuickActionModal('Fresh Today', Icons.schedule, const Color(0xFF2196F3), 'freshToday');
    } else if (title.contains('Trending')) {
      // Navigate directly to the most sold product's details
      _navigateToMostSoldProduct();
    } else if (title.contains('Flash')) {
      _showQuickActionModal('Best Deals', Icons.local_offer, const Color(0xFFFF5722), 'bestDeals');
    } else if (title.contains('Community')) {
      // Navigate to Popular Products (sorted by favoriteCount)
      _showQuickActionModal('Popular Products', Icons.favorite, const Color(0xFFE91E63), 'popular');
    } else {
      _showQuickActionModal('Best Deals', Icons.local_offer, const Color(0xFF4CAF50), 'bestDeals');
    }
  }

  // Updated method for Smart Shopping Carousel
  Stream<String> _getSmartSubtitle(String title) {
    if (title.contains('Fresh')) {
      return FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .where('isFreshToday', isEqualTo: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final name = data['name'] ?? 'Fresh produce';
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final hoursAgo = DateTime.now().difference(createdAt.toDate()).inHours;
            return 'Fresh $name - ${hoursAgo}h ago';
          }
          return 'Fresh $name available now';
        }
        return 'Fresh produce available daily';
      }).asBroadcastStream();
    } else if (title.contains('Trending')) {
      return FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .orderBy('soldCount', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final name = data['name'] ?? 'Popular item';
          final soldCount = (data['soldCount'] ?? 0) as num;
          return "$name - $soldCount sold";
        }
        return "Check trending products";
      }).asBroadcastStream();
    } else if (title.contains('Flash')) {
      return FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .where('price', isLessThanOrEqualTo: 50)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final name = data['name'] ?? 'Great deal';
          final price = (data['price'] ?? 0) as num;
          return 'Limited: ₱${price.toStringAsFixed(2)} $name';
        }
        return 'Amazing deals available';
      }).asBroadcastStream();
    } else if (title.contains('Community')) {
      return FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .where('favoriteCount', isGreaterThan: 0)
          .orderBy('favoriteCount', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final name = data['name'] ?? 'Popular choice';
          final favoriteCount = (data['favoriteCount'] ?? 0) as num;
          return 'Most loved: $name ($favoriteCount♥)';
        }
        return 'Discover favorites';
      }).asBroadcastStream();
    }
    return Stream<String>.value('Personalized deals for you').asBroadcastStream();
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap, bool isSmallScreen, Widget badge) {
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = isSmallScreen ? screenWidth * 0.02 : 10.0;
    final responsiveIconSize = isSmallScreen ? screenWidth * 0.05 : 24.0;
    final responsiveFontSize = isSmallScreen ? screenWidth * 0.028 : 12.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(responsivePadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
          border: Border.all(color: color.withOpacity(0.18), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              spreadRadius: 0.5,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
              ),
              child: Icon(
                icon,
                color: color,
                size: responsiveIconSize,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
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
          .where('isActive', isEqualTo: true)
          .where('paymentMethods', arrayContains: 'cashOnPickup')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count+',
          style: GoogleFonts.quicksand(
            fontSize: 10,
            fontWeight: FontWeight.w600,
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
          .where('isActive', isEqualTo: true)
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
            fontSize: 10,
            fontWeight: FontWeight.w600,
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
          .where('isActive', isEqualTo: true)
          .where('totalRatings', isGreaterThan: 0)
          .where('averageRating', isGreaterThanOrEqualTo: 4.5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count+',
          style: GoogleFonts.quicksand(
            fontSize: 10,
            fontWeight: FontWeight.w600,
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
          .where('isActive', isEqualTo: true)
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
            fontSize: 10,
            fontWeight: FontWeight.w600,
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
          .where('isActive', isEqualTo: true)
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
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  Widget _buildPopularBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .where('favoriteCount', isGreaterThan: 0)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count+',
          style: GoogleFonts.quicksand(
            fontSize: 10,
            fontWeight: FontWeight.w600,
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

  // Navigate to the most sold product's details page
  Future<void> _navigateToMostSoldProduct() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: GroceryLoadingWidget(
            size: 100,
            showText: true,
            loadingText: 'Finding trending product...',
          ),
        ),
      );

      // Query for the most sold product
      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .orderBy('soldCount', descending: true)
          .limit(1)
          .get();

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (querySnapshot.docs.isNotEmpty) {
        final mostSoldDoc = querySnapshot.docs.first;
        final productData = mostSoldDoc.data();
        final productId = mostSoldDoc.id;
        
        // Navigate to product details
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                product: productData,
                productId: productId,
              ),
            ),
          );
        }
      } else {
        // No products found, show message and navigate to products page
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No trending products found. Browse all products instead.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BuyerProductsPage(),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding trending product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Removed unused _toggleFavorite; favorites are handled elsewhere

  // Product favoriteCount is now maintained by Cloud Functions
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
  void initState() {
    super.initState();
    // Sync favorites when Popular Products modal is opened
    if (widget.filterType == 'popular') {
      _syncUserFavorites();
      _debugUserFavorites();
    }
  }

  // Debug method to check user's favorites
  Future<void> _debugUserFavorites() async {
    final authService = AuthStateService();
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      debugPrint('Popular Products: No user logged in');
      return;
    }
    
    try {
      // Check array favorites
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final favoritesArray = List<String>.from(userData['favorites'] ?? []);
        debugPrint('Popular Products: User favorites array: $favoritesArray');
      }
      
      // Check subcollection favorites
      final subcollectionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('favorites')
          .get();
      
      final subcollectionIds = subcollectionSnapshot.docs.map((doc) => doc.id).toList();
      debugPrint('Popular Products: User favorites subcollection: $subcollectionIds');
      
    } catch (e) {
      debugPrint('Popular Products: Error debugging favorites: $e');
    }
  }

  // Utility method to sync favorites between array and subcollection
  Future<void> _syncUserFavorites() async {
    final authService = AuthStateService();
    final currentUser = authService.currentUser;
    
    if (currentUser == null) return;
    
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final favoritesArray = List<String>.from(userData['favorites'] ?? []);
      
      // Get subcollection favorites
      final subcollectionSnapshot = await userRef.collection('favorites').get();
      final subcollectionIds = subcollectionSnapshot.docs.map((doc) => doc.id).toList();
      
      // If arrays don't match, sync them
      if (favoritesArray.length != subcollectionIds.length || 
          !favoritesArray.every((id) => subcollectionIds.contains(id))) {
        
        debugPrint('Syncing favorites: Array has ${favoritesArray.length}, Subcollection has ${subcollectionIds.length}');
        
        // Update subcollection to match array
        final batch = FirebaseFirestore.instance.batch();
        
        // Remove items not in array
        for (final doc in subcollectionSnapshot.docs) {
          if (!favoritesArray.contains(doc.id)) {
            batch.delete(doc.reference);
          }
        }
        
        // Add items from array not in subcollection
        for (final productId in favoritesArray) {
          if (!subcollectionIds.contains(productId)) {
            batch.set(userRef.collection('favorites').doc(productId), {
              'productId': productId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
        
        await batch.commit();
        debugPrint('Favorites synced successfully');
      }
    } catch (e) {
      debugPrint('Error syncing favorites: $e');
    }
  }

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.quicksand(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.color,
                          ),
                        ),
                        if (widget.filterType == 'popular')
                          Text(
                            'Your favorites with community counts',
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              color: widget.color.withOpacity(0.7),
                            ),
                          ),
                      ],
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
                            widget.filterType == 'popular' ? Icons.favorite_border : widget.icon,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.filterType == 'popular' 
                                ? 'No favorite products yet'
                                : widget.filterType == 'topRated'
                                    ? 'No rated products found'
                                    : 'No ${widget.title.toLowerCase()} products found',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (widget.filterType == 'popular') ...[
                            const SizedBox(height: 8),
                            Text(
                              'Add products to your favorites to see them here',
                              style: GoogleFonts.quicksand(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Go to Browse Products and tap the heart icon on products you like',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You\'ll see how many other customers also favorited each product',
                              style: GoogleFonts.quicksand(
                                fontSize: 11,
                                color: Colors.grey[300],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (widget.filterType == 'topRated') ...[
                            const SizedBox(height: 8),
                            Text(
                              'Products need customer reviews to appear here',
                              style: GoogleFonts.quicksand(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
            // Footer removed: redundant "View All" quick action
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredProductsStream() {
    if (widget.filterType == 'popular') {
      // Get current user's favorites and fetch those products
      final authService = AuthStateService();
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        // Return empty stream if no user
        return Stream<QuerySnapshot>.empty();
      }
      
      // First get the user's favorite product IDs from the subcollection
      return FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('favorites')
          .snapshots()
          .asyncMap((favoritesSnapshot) async {
            debugPrint('Popular Products: Found ${favoritesSnapshot.docs.length} favorites in subcollection');
            
            if (favoritesSnapshot.docs.isEmpty) {
              // Also check the legacy array as fallback
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
              
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                final favoritesArray = List<String>.from(userData['favorites'] ?? []);
                debugPrint('Popular Products: Found ${favoritesArray.length} favorites in array');
                
                if (favoritesArray.isEmpty) {
                  // Return empty query result
                  return await FirebaseFirestore.instance
                      .collection('products')
                      .where('status', isEqualTo: 'nonexistent')
                      .limit(0)
                      .get();
                }
                
                // Use array favorites as fallback
                final productsQuery = await FirebaseFirestore.instance
                    .collection('products')
                    .where('status', isEqualTo: 'approved')
                    .where('isActive', isEqualTo: true)
                    .where(FieldPath.documentId, whereIn: favoritesArray)
                    .limit(12)
                    .get();
                
                debugPrint('Popular Products: Found ${productsQuery.docs.length} products from array fallback');
                
                // If still no products with strict criteria, try relaxed
                if (productsQuery.docs.isEmpty) {
                  debugPrint('Popular Products: Array fallback with strict criteria failed, trying relaxed...');
                  
                  final relaxedArrayQuery = await FirebaseFirestore.instance
                      .collection('products')
                      .where(FieldPath.documentId, whereIn: favoritesArray)
                      .get();
                  
                  debugPrint('Popular Products: Relaxed array query found ${relaxedArrayQuery.docs.length} products');
                  
                  // Log details about each product for debugging
                  for (final doc in relaxedArrayQuery.docs) {
                    final data = doc.data();
                    debugPrint('Array Product ${doc.id}: status=${data['status']}, isActive=${data['isActive']}, name=${data['name']}');
                  }
                  
                  return relaxedArrayQuery;
                }
                
                return productsQuery;
              }
              
              // Return empty query result
              return await FirebaseFirestore.instance
                  .collection('products')
                  .where('status', isEqualTo: 'nonexistent')
                  .limit(0)
                  .get();
            }
            
            // Get product IDs from favorites subcollection
            final productIds = favoritesSnapshot.docs.map((doc) => doc.id).toList();
            debugPrint('Popular Products: Product IDs from subcollection: $productIds');
            
            // Fetch products that are in the user's favorites
            final productsQuery = await FirebaseFirestore.instance
                .collection('products')
                .where('status', isEqualTo: 'approved')
                .where('isActive', isEqualTo: true)
                .where(FieldPath.documentId, whereIn: productIds)
                .limit(12)
                .get();
            
            debugPrint('Popular Products: Found ${productsQuery.docs.length} products from subcollection');
            
            // If no products found with strict criteria, try with relaxed criteria
            if (productsQuery.docs.isEmpty) {
              debugPrint('Popular Products: No products found with strict criteria, trying relaxed criteria...');
              
              final relaxedQuery = await FirebaseFirestore.instance
                  .collection('products')
                  .where(FieldPath.documentId, whereIn: productIds)
                  .get();
              
              debugPrint('Popular Products: Relaxed query found ${relaxedQuery.docs.length} products');
              
              // Log details about each product for debugging
              for (final doc in relaxedQuery.docs) {
                final data = doc.data();
                debugPrint('Product ${doc.id}: status=${data['status']}, isActive=${data['isActive']}, name=${data['name']}');
              }
              
              return relaxedQuery;
            }
            
            return productsQuery;
          });
    } else if (widget.filterType == 'topRated') {
      // Fetch products that have ratings and are well-rated (3.5+ stars)
      debugPrint('Top Rated: Starting query for top rated products...');
      return FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .where('totalRatings', isGreaterThan: 0)
          .where('averageRating', isGreaterThanOrEqualTo: 3.5)
          .orderBy('averageRating', descending: true)
          .orderBy('totalRatings', descending: true)
          .limit(20)
          .snapshots()
          .asyncMap((snapshot) async {
            debugPrint('Top Rated: Found ${snapshot.docs.length} products with ratings >= 3.5');
            
            // If no products found with strict criteria, try more relaxed criteria
            if (snapshot.docs.isEmpty) {
              debugPrint('Top Rated: No products with strict criteria, trying relaxed criteria...');
              
              final relaxedSnapshot = await FirebaseFirestore.instance
                  .collection('products')
                  .where('status', isEqualTo: 'approved')
                  .where('isActive', isEqualTo: true)
                  .where('totalRatings', isGreaterThan: 0)
                  .where('averageRating', isGreaterThan: 0.0) // Ensure rating is actually greater than 0
                  .orderBy('averageRating', descending: true)
                  .orderBy('totalRatings', descending: true)
                  .limit(20)
                  .get();
              
              debugPrint('Top Rated: Relaxed query found ${relaxedSnapshot.docs.length} products');
              
              for (final doc in relaxedSnapshot.docs) {
                final data = doc.data();
                final rating = (data['averageRating'] ?? 0.0) as num;
                final totalRatings = (data['totalRatings'] ?? 0) as num;
                debugPrint('Top Rated Product (relaxed): ${data['name']} - Rating: $rating, Total: $totalRatings');
              }
              
              // If still no products found, return empty result instead of fallback
              if (relaxedSnapshot.docs.isEmpty) {
                debugPrint('Top Rated: No products with any ratings found');
                // Return the empty snapshot as is - the UI will handle the empty state
                return relaxedSnapshot;
              }
              
              return relaxedSnapshot;
            }
            
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final rating = (data['averageRating'] ?? 0.0) as num;
              final totalRatings = (data['totalRatings'] ?? 0) as num;
              debugPrint('Top Rated Product: ${data['name']} - Rating: $rating, Total: $totalRatings');
            }
            return snapshot;
          });
    }
    return FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
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
          final avg = (data['averageRating'] ?? 0.0) as num;
          final totalRatings = (data['totalRatings'] ?? 0) as num;
          // Show products that have ratings and are well-rated (3.5+ stars)
          return totalRatings > 0 && avg >= 3.5;
        case 'nearMe':
          // For now, return all products. Location filtering would need user's location
          return true;
        case 'bestDeals':
          final price = (data['price'] ?? 0) as num;
          return price <= 50;
        case 'popular':
          // For popular products (user's favorites), show all products regardless of favoriteCount
          // since we're showing the user's personal favorites
          return true;
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
              child: (() {
                final img = _resolveProductImageUrl(data);
                if (img.isNotEmpty) {
                  return Image.network(
                    _versionedImageUrl(img, data['updatedAt']),
                    key: ValueKey(_versionedImageUrl(img, data['updatedAt'])),
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
                  );
                }
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image),
                );
              })(),
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

  String _versionedImageUrl(dynamic url, dynamic updatedAt) {
    final base = (url ?? '').toString();
    if (base.isEmpty) return base;
    int version = 0;
    try {
      if (updatedAt is Timestamp) {
        version = updatedAt.millisecondsSinceEpoch;
      } else if (updatedAt is DateTime) {
        version = updatedAt.millisecondsSinceEpoch;
      }
    } catch (_) {}
    if (version == 0) return base;
    final separator = base.contains('?') ? '&' : '?';
    return '$base${separator}v=$version';
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
        final rating = (data['averageRating'] ?? 0.0) as num;
        badgeText = '⭐ ${rating.toStringAsFixed(1)}';
        break;
      case 'nearMe':
        badgeText = 'Nearby';
        break;
      case 'bestDeals':
        badgeText = 'Best Deal';
        break;
      case 'popular':
        final favoriteCount = (data['favoriteCount'] ?? 0) as num;
        debugPrint('Popular Products Badge: Product ${data['name']} has favoriteCount: $favoriteCount');
        // If favoriteCount is 0 but this product is in user's favorites, show 1
        final displayCount = favoriteCount > 0 ? favoriteCount : 1;
        badgeText = '❤️ $displayCount favorites';
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

}