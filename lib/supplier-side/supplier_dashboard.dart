// ignore_for_file: deprecated_member_use, use_build_context_synchronously, library_private_types_in_public_api, avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:veggieconnect/authentication/login_page.dart';
import 'package:veggieconnect/supplier-side/supplier_add_product_page.dart';
import 'package:veggieconnect/supplier-side/supplier_orders_page.dart';
import 'package:veggieconnect/supplier-side/supplier_chat_list_page.dart';
import 'package:veggieconnect/supplier-side/supplier_map_page.dart';
import 'package:veggieconnect/widgets/modern_app_bar.dart';
import 'package:veggieconnect/widgets/role_page_header.dart';
import '../widgets/modern_wave_drawer.dart';
import '../services/cloudinary_service.dart';
import '../services/auth_state_service.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:veggieconnect/services/revenue_service.dart';
import 'package:veggieconnect/services/notification_service.dart';
import 'package:veggieconnect/widgets/notification_center.dart';
import 'package:veggieconnect/widgets/lottie_loading_widget.dart';
import 'package:veggieconnect/services/supplier_verification_service.dart';
import 'package:veggieconnect/widgets/id_camera_widget.dart';

class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String? _localProfileImagePath;
  bool _showVerificationNotification = false;
  late Ticker _ticker;
  late ValueNotifier<DateTime> _nowNotifier;

  final AuthStateService _authService = AuthStateService();
  final NotificationService _notificationService = NotificationService();

  AuthUser? get user => _authService.currentUser;

  @override
  void initState() {
    super.initState();
    _nowNotifier = ValueNotifier<DateTime>(DateTime.now());
    _ticker = createTicker((elapsed) {
      _nowNotifier.value = DateTime.now();
    });
    _ticker.start();
    
    // Initialize notification service
    _notificationService.initialize();
    
    _loadLocalProfileImage();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isVerified = userData['isVerified'] ?? false;
          
          setState(() {
            _showVerificationNotification = !isVerified;
          });
          
          // Show notification after a short delay to ensure UI is ready
          if (!isVerified) {
            Future.delayed(Duration(milliseconds: 1500), () {
              if (mounted && _showVerificationNotification) {
                _showFloatingVerificationNotification();
              }
            });
          }
        }
      } catch (e) {
        print('Error checking verification status: $e');
      }
    }
  }

  void _showFloatingVerificationNotification() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            // Navigate to profile tab and show verification modal
            setState(() {
              _selectedIndex = 4; // Profile tab index
            });
            // Small delay to ensure tab switch completes
            Future.delayed(Duration(milliseconds: 300), () {
              _showVerificationDialog();
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Get Verified Now!',
                        style: GoogleFonts.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Verify your account to unlock all features. Tap to get started.',
                        style: GoogleFonts.quicksand(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Color(0xFF6CA04A),
        duration: Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _loadLocalProfileImage() async {
    final user = _authService.currentUser;
    if (user != null) {
      final localPath = await CloudinaryService.getProfileImage(user.uid);
      if (localPath != null) {
        setState(() {
          _localProfileImagePath = localPath;
        });
      }
    }
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
                fontSize: 22,
                color: Color(0xFF222222),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildImageOption(
                  icon: Icons.cloud_upload,
                  label: 'Cloudinary',
                  onTap: _uploadViaCloudinary,
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
              color: Color(0xFF222222),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadViaCloudinary() async {
    Navigator.pop(context);
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      if (kIsWeb) {
        // Pick bytes on web
        final Uint8List? bytes = await CloudinaryService.pickImageFromWeb();
        if (bytes == null) return;
        await _uploadToCloudinaryAndSave(bytes: bytes);
      } else {
        // Pick from gallery on mobile as default
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 75,
        );
        if (image != null) {
          await _uploadToCloudinaryAndSave(file: File(image.path));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cloudinary upload failed: $e'),
          backgroundColor: Color(0xFFE57373),
        ),
      );
    }
  }

  Future<void> _uploadToCloudinaryAndSave({File? file, Uint8List? bytes}) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      String imageUrl;
      if (kIsWeb) {
        if (bytes == null) throw ArgumentError('bytes must not be null on web');
        imageUrl = await CloudinaryService.uploadBytes(bytes, folder: 'vegieconnect/avatars/${user.uid}');
      } else {
        if (file == null) throw ArgumentError('file must not be null on mobile');
        imageUrl = await CloudinaryService.uploadFile(file, folder: 'vegieconnect/avatars/${user.uid}');
      }

      // Save URL to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'avatarUrl': imageUrl},
        SetOptions(merge: true),
      );

      setState(() {
        // Clear local path to force using network image
        _localProfileImagePath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile picture updated successfully!'),
          backgroundColor: Color(0xFF6CA04A),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Color(0xFFE57373),
        ),
      );
    }
  }

  ImageProvider? _getSupplierProfileImage(Map<String, dynamic>? userData) {
    // Priority: Cloudinary avatarUrl > legacy profileImageUrl > local image
    final avatarUrl = userData?['avatarUrl'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    }

    final profileImageUrl = userData?['profileImageUrl'] as String?;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return NetworkImage(profileImageUrl);
    }

    if (_localProfileImagePath != null) {
      final file = CloudinaryService.loadImageFromPath(_localProfileImagePath!);
      if (file != null) {
        return FileImage(file);
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(20);
    return WillPopScope(
      onWillPop: () async {
        // Prevent the app from closing when back button is pressed
        // Keep the dashboard open
        return false;
      },
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFF8FAF5),
      appBar: _selectedIndex == 0 ? ModernAppBar(
        title: Text(
          'Supplier Dashboard',
          style: GoogleFonts.quicksand(
            fontSize: 20,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () async {
                      // Mark all notifications as read when opening notification center
                      _notificationService.markAllAsRead();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationCenter(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications,
                      color: Color(0xFF4CAF50),
                      size: 24,
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
                          style:  GoogleFonts.quicksand(
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
      drawer: StreamBuilder<DocumentSnapshot>(
        stream: _authService.currentUser != null 
          ? FirebaseFirestore.instance.collection('users').doc(_authService.currentUser!.uid).snapshots()
          : null,
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final displayName = userData?['name'] ?? _authService.currentUser?.displayName ?? 'Supplier';
          final email = _authService.currentUser?.email ?? 'supplier@email.com';
          final profileImageUrl = userData?['profileImageUrl'] as String?;
          
          return ModernWaveDrawer(
            key: ValueKey(_selectedIndex), // Force rebuild when selectedIndex changes
            selectedIndex: _selectedIndex,
            onItemTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
              Navigator.pop(context);
            },
            headerName: displayName,
            headerEmail: email,
            headerAvatarUrl: profileImageUrl,
            onHeaderTap: _showProfileImageOptions,
            items: [], // Empty since we're using sections
            sections: [
              DrawerSection(
                title: 'MAIN NAVIGATION',
                items: [
                  DrawerItem(icon: Icons.dashboard, title: 'Overview', index: 0),
                  DrawerItem(icon: Icons.spa, title: 'Manage Products', index: 1),
                  DrawerItem(icon: Icons.inventory_2, title: 'Stock Management', index: 2),
                  DrawerItem(icon: Icons.person, title: 'Profile', index: 4),
                ],
              ),
              DrawerSection(
                title: 'BUSINESS TOOLS',
                items: [
                  DrawerItem(
                    icon: Icons.shopping_cart,
                    title: 'Orders Management',
                    index: -1,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SupplierOrdersPage()),
                      );
                    },
                  ),
                  DrawerItem(
                    icon: Icons.person_pin,
                    title: 'My Location',
                    index: -1,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SupplierLocationPage()),
                      );
                    },
                  ),
                  DrawerItem(
                    icon: Icons.message,
                    title: 'Messages',
                    index: -1,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SupplierChatListPage()),
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
                    onTap: () async {
                      // Non-blocking logout for instant UX
                      unawaited(_authService.signOut());
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildOverviewTab(cardRadius),
          _buildProductsTab(),
          _buildStockManagementTab(),
          SupplierOrdersPage(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Color(0xFF4CAF50),
        color: Colors.white,
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        items: const [
          Icon(Icons.home, size: 30, color: Colors.green,),
          Icon(Icons.spa, size: 30, color: Colors.green,),
          Icon(Icons.inventory_2, size: 30, color: Colors.green,),
          Icon(Icons.shopping_cart, size: 30, color: Colors.green,),
          Icon(Icons.person, size: 30, color: Colors.green,),
        ],
      ),
      ),
    );
  }

  Widget _buildOverviewTab(BorderRadius cardRadius) {
  
    
    if (_authService.currentUser == null) {
      return const Center(child: Text('Not logged in.'));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Overview',
            style: GoogleFonts.quicksand(
              fontSize: 20,
              color: Color(0xFF222222),
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              // Total Products
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('sellerId', isEqualTo: _authService.currentUser!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _buildStatCard(cardRadius, 'Total Products', '$count', Icons.grass, Colors.blue);
                },
              ),
              // Active Orders
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('sellerId', isEqualTo: _authService.currentUser!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return _buildStatCard(cardRadius, 'Active Orders', '0', Icons.shopping_cart, Colors.green);
                  
                  final activeOrders = snapshot.data!.docs.where((doc) {
                    final status = doc['status'] as String?;
                    return status != 'completed' && status != 'cancelled';
                  }).length;
                  
                  return _buildStatCard(cardRadius, 'Active Orders', '$activeOrders', Icons.shopping_cart, Colors.green);
                },
              ),

              
              // Revenue
              StreamBuilder<double>(
                stream: RevenueService.getCurrentUserRevenueStream(),
                builder: (context, snapshot) {
                  final revenue = snapshot.data ?? 0.0;
                  return _buildStatCard(
                    cardRadius, 
                    'Revenue', 
                    RevenueService.formatCurrency(revenue), 
                    Icons.text_fields, // Will be replaced with ₱ symbol 
                    Colors.green
                  );
                },
              ),
              // Total Orders
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('sellerId', isEqualTo: _authService.currentUser!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _buildStatCard(cardRadius, 'Total Orders', '$count', Icons.receipt_long, Colors.orange);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Quick stock summary
          _buildQuickStockSummary(),
        ],
      ),
    );
  }

  Widget _buildQuickStockSummary() {
    final user = _authService.currentUser;
    
    if (user == null) {
      return const SizedBox.shrink();
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildStandardCard(
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: const Color(0xFF757575),
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'No products yet',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    color: const Color(0xFF757575),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first product to get started',
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: const Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddProductPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    'Add Product',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }
        
        int lowStockProducts = 0;
        int outOfStockProducts = 0;
        
        for (var doc in snapshot.data!.docs) {
          final product = doc.data() as Map<String, dynamic>;
          final quantity = product['quantity'] ?? 0;
          
          if (quantity <= 0) {
            outOfStockProducts++;
          } else if (quantity <= 5) {
            lowStockProducts++;
          }
        }
        
        return _buildStandardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: const Color(0xFF4CAF50),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Stock Summary',
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 2; // Switch to Stock Management tab
                      });
                    },
                    child: Text(
                      'Manage',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: const Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickStatItem(
                      'Low Stock',
                      '$lowStockProducts',
                      Colors.orange,
                      Icons.warning,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuickStatItem(
                      'Out of Stock',
                      '$outOfStockProducts',
                      Colors.red,
                      Icons.remove_shopping_cart,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStatItem(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to create standard cards that match application design
  Widget _buildStandardCard({required Widget child, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8D9773).withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  // Helper method to create stat cards that match application design (replaces StatCard widget)
  Widget _buildStatCardWidget({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        // Scale sizes based on available width to avoid overflow on small screens
        final double iconSize = w * 0.16; // smaller icons to prevent overflow
        final double trendSize = w * 0.12;
        final double titleSize = w * 0.08;  // Reduced from 0.10
        final double valueSize = w * 0.12;  // Reduced from 0.16
        final double gapLarge = w * 0.06;   // tighter spacing
        final double gapSmall = w * 0.02;

        return _buildStandardCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(w * 0.08),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildPesoIcon(icon, color, iconSize.clamp(16, 24)),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.trending_up,
                    color: color,
                    size: trendSize.clamp(12, 18),
                  ),
                ],
              ),
              SizedBox(height: gapLarge.clamp(8, 14)),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.quicksand(
                  fontSize: titleSize.clamp(8, 10),
                  color: const Color(0xFF757575),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: gapSmall.clamp(2, 6)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.quicksand(
                    fontSize: valueSize.clamp(10, 14),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(BorderRadius cardRadius, String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double iconSize = (w * 0.16).clamp(16, 24);
        final double trendSize = (w * 0.13).clamp(12, 18);
        final double titleSize = (w * 0.10).clamp(10, 13);
        final double valueSize = (w * 0.18).clamp(14, 18);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: cardRadius,
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
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildPesoIcon(icon, color, iconSize),
                    const Spacer(),
                    Icon(Icons.trending_up, color: color, size: trendSize),
                  ],
                ),
                SizedBox(height: (w * 0.08).clamp(6, 10)),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    fontSize: titleSize,
                    color: Color(0xFF757575),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: (w * 0.02).clamp(2, 4)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.quicksand(
                      fontSize: valueSize,
                      color: color,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    return Scaffold(
      appBar: RolePageHeader(
        title: 'Manage Products',
        onBackTap: () {
          setState(() { _selectedIndex = 0; });
        },
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddProductPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6CA04A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: Text('Add', style: GoogleFonts.quicksand(fontSize: 16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status toggle chips
            _buildStatusToggle(),
            SizedBox(height: 12),
            _buildProductList(),
          ],
        ),
      ),
    );
  }

  String _productStatusFilter = 'All';

  Widget _buildStatusToggle() {
    final statuses = ['All', 'approved', 'pending', 'rejected', 'active', 'inactive'];
    return Wrap(
      spacing: 8,
      children: statuses.map((s) {
        final bool selected = _productStatusFilter == s;
        return ChoiceChip(
          label: Text(s.toUpperCase()),
          selected: selected,
          onSelected: (_) => setState(() => _productStatusFilter = s),
          selectedColor: const Color(0xFF6CA04A),
          labelStyle: GoogleFonts.quicksand(color: selected ? Colors.white : const Color(0xFF222222)),
        );
      }).toList(),
    );
  }

  Widget _buildProductList() {
    final user = _authService.currentUser;
    
    Query baseQuery = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: user?.uid)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: baseQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: GroceryLoadingWidget(
              size: 100,
              showText: true,
              loadingText: 'Loading orders...',
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No products yet',
              style: GoogleFonts.quicksand(fontSize: 16),
            ),
          );
        }
        
        var products = snapshot.data!.docs;
        // Local filter by status or active/inactive
        if (_productStatusFilter != 'All') {
          if (_productStatusFilter == 'active') {
            // Filter by isActive = true
            products = products.where((d) => ((d.data() as Map<String, dynamic>)['isActive'] ?? false) == true).toList();
          } else if (_productStatusFilter == 'inactive') {
            // Filter by isActive = false
            products = products.where((d) => ((d.data() as Map<String, dynamic>)['isActive'] ?? false) == false).toList();
          } else {
            // Filter by status field (approved, pending, rejected)
            products = products.where((d) => ((d.data() as Map<String, dynamic>)['status'] ?? 'pending') == _productStatusFilter).toList();
          }
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index].data() as Map<String, dynamic>;
            final docId = products[index].id;
            
            return GestureDetector(
              onTap: () {
                // Navigate to product details or edit page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddProductPage(
                      product: product,
                      docId: docId,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Product Image
                        if (product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty)
                          Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(product['imageUrl']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'] ?? 'Product',
                                style: GoogleFonts.quicksand(
                                  fontSize: 16,
                                  color: Color(0xFF222222),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Price: ₱${product['price'] ?? 0}',
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  color: Color(0xFF6CA04A),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Stock: ${product['quantity'] ?? 0}',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  StockIndicator(quantity: product['quantity'] ?? 0),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
  children: [
    Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(product['status']).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        (product['status'] ?? 'pending').toString().toUpperCase(),
        style: GoogleFonts.quicksand(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(product['status']),
        ),
      ),
    ),
    SizedBox(height: 8),
    // Delete Button for ALL products
    IconButton(
      onPressed: () => _deleteProduct(docId, product['name'] ?? 'Product'),
      icon: Icon(Icons.delete, color: Colors.red, size: 20),
      tooltip: 'Delete Product',
    ),
    // Add Rejection Reason button for rejected products
    if (product['status'] == 'rejected') ...[
      ElevatedButton(
        onPressed: () => _showRejectionReasonModal(context, product),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red.shade700,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size(0, 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: Colors.red.shade200),
          ),
          elevation: 0,
        ),
        child: Text(
          'Rejection Reason',
          style: GoogleFonts.quicksand(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  ],
),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _showRejectionReasonModal(BuildContext context, Map<String, dynamic> product) {
    final rejectionReason = product['rejectionReason'] ?? 'No reason provided';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 24),
            SizedBox(width: 8),
            Text(
              'Rejection Reason',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product: ${product['name'] ?? 'Unknown Product'}',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rejectionReason,
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Colors.red.shade800,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'You can edit and resubmit this product for review.',
              style: GoogleFonts.quicksand(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.quicksand(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to edit product page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddProductPage(
                    product: product,
                    docId: product['id'],
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6CA04A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Edit Product',
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockManagementTab() {
    return Scaffold(
      appBar: RolePageHeader(title: 'Stock Management',
      onBackTap: () {
          setState(() { _selectedIndex = 0; });
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock overview section
            Text(
              'Stock Overview',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            _buildStockOverview(),
            const SizedBox(height: 24),
            // Stock list section
            Text(
              'Manage Products',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            _buildStockList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStockOverview() {
    final user = _authService.currentUser;
    
    if (user == null) {
      return const Center(
        child: Text(
          'Not logged in.',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF757575),
          ),
        ),
      );
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: GroceryLoadingWidget(
              size: 100,
              showText: true,
              loadingText: 'Loading stock overview...',
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: _buildStandardCard(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
              'Error loading data',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        int lowStockProducts = 0;
        int outOfStockProducts = 0;
        double totalValue = 0;
        int totalProducts = snapshot.data!.docs.length;
        
        for (var doc in snapshot.data!.docs) {
          final product = doc.data() as Map<String, dynamic>;
          final quantity = product['quantity'] ?? 0;
          final price = product['price'] ?? 0;
          
          if (quantity <= 0) {
            outOfStockProducts++;
          } else if (quantity <= 5) {
            lowStockProducts++;
          }
          
          totalValue += quantity * price;
        }
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildStatCardWidget(
              title: 'Total Products',
              value: '$totalProducts',
              icon: Icons.inventory_2,
              color: const Color(0xFF4CAF50),
            ),
            _buildStatCardWidget(
              title: 'Low Stock',
              value: '$lowStockProducts',
              icon: Icons.warning,
              color: Colors.orange,
            ),
            _buildStatCardWidget(
              title: 'Out of Stock',
              value: '$outOfStockProducts',
              icon: Icons.remove_shopping_cart,
              color: Colors.red,
            ),
            _buildStatCardWidget(
              title: 'Total Value',
              value: '₱${totalValue.toStringAsFixed(2)}',
              icon: Icons.text_fields, // Will be replaced with ₱ symbol
              color: const Color(0xFF6CA04A),
            ),
          ],
        );
        
      },
    );
    
  }

  Widget _buildPesoIcon(IconData icon, Color color, double size) {
    // Check if this is a money-related icon that should be replaced with ₱
    if (icon == Icons.text_fields) { // Our placeholder for money icons
      return Text(
        '₱',
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Icon(icon, color: color, size: size);
  }

  Widget _buildStockList() {
    final user = _authService.currentUser;
    
    if (user == null) {
      return Center(
        child: _buildStandardCard(
          child: Column(
            children: [
              Icon(
                Icons.person_off,
                color: const Color(0xFF757575),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Not logged in',
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  color: const Color(0xFF757575),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user.uid)
          .orderBy('quantity')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: GroceryLoadingWidget(
              size: 100,
              showText: true,
              loadingText: 'Loading products...',
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: _buildStandardCard(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading products',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: _buildStandardCard(
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: const Color(0xFF757575),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No products yet',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      color: const Color(0xFF757575),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first product to get started',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        final products = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index].data() as Map<String, dynamic>;
            final docId = products[index].id;
            final quantity = product['quantity'] ?? 0;
            final price = product['price'] ?? 0;
            
            Color stockColor;
            String stockStatus;
            if (quantity <= 0) {
              stockColor = Colors.red;
              stockStatus = 'Out of Stock';
            } else if (quantity <= 5) {
              stockColor = Colors.orange;
              stockStatus = 'Low Stock';
            } else {
              stockColor = const Color(0xFF4CAF50);
              stockStatus = 'In Stock';
            }
            
            return _buildStandardCard(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Product image placeholder
                      Container(
                        width: 60,
                        height: 60,
              decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: product['imageUrl'] != null && product['imageUrl'].isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  product['imageUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.image,
                                      color: Color(0xFFBDBDBD),
                                      size: 24,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.image,
                                color: Color(0xFFBDBDBD),
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Unknown Product',
                              style: GoogleFonts.quicksand(
                              fontSize: 16,
                                color: const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w600,
                            ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                          ),
                            const SizedBox(height: 4),
                          Text(
                            '₱${price.toStringAsFixed(2)}',
                              style: GoogleFonts.quicksand(
                                fontSize: 18,
                                color: const Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stockColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2,
                                        size: 14,
                                color: stockColor,
                              ),
                                      const SizedBox(width: 4),
                              Text(
                                '$quantity ${product['unit'] ?? ''}',
                                        style: GoogleFonts.quicksand(
                                          fontSize: 12,
                                  color: stockColor,
                                          fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stockColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    stockStatus,
                                    style: GoogleFonts.quicksand(
                                      fontSize: 12,
                                      color: stockColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                                ),
                              ],
                            ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showStockUpdateDialog(docId, product['name'] ?? 'Product', quantity, true),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            'Add Stock',
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: quantity > 0 
                              ? () => _showStockUpdateDialog(docId, product['name'] ?? 'Product', quantity, false)
                              : null,
                          icon: const Icon(Icons.remove, size: 18),
                          label: Text(
                            'Remove',
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            disabledBackgroundColor: const Color(0xFFE0E0E0),
                            disabledForegroundColor: const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    ],
                  ),
                                ],
                              ),
                            );
          },
        );
      },
    );
  }

  void _showStockUpdateDialog(String productId, String productName, int currentQuantity, bool isAdding) {
    final TextEditingController quantityController = TextEditingController();
    quantityController.text = '1';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              isAdding ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: isAdding ? const Color(0xFF4CAF50) : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAdding ? 'Add Stock' : 'Remove Stock',
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
                                ),
                              ],
                            ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product: $productName',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                color: const Color(0xFF757575),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current stock: $currentQuantity',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: const Color(0xFF757575),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quantity to ${isAdding ? 'add' : 'remove'}:',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.quicksand(
                fontSize: 16,
                color: const Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                hintText: 'Enter quantity',
                hintStyle: GoogleFonts.quicksand(
                  fontSize: 16,
                  color: const Color(0xFF9E9E9E),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
                    ),
                  ],
                ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                color: const Color(0xFF757575),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                final newQuantity = isAdding 
                    ? currentQuantity + quantity 
                    : (currentQuantity - quantity).clamp(0, double.infinity).toInt();
                _updateStock(productId, newQuantity);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAdding ? const Color(0xFF4CAF50) : Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              isAdding ? 'Add Stock' : 'Remove Stock',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStock(String productId, int newQuantity) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'quantity': newQuantity});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock updated to $newQuantity',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update stock: $e',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildProfileTab() {
    final user = _authService.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: GroceryLoadingWidget(
              size: 100,
              showText: true,
              loadingText: 'Loading...',
            ),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No profile data found.'));
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        
        return Scaffold(
          appBar: RolePageHeader(title: 'Profile Management',
      onBackTap: () {
          setState(() { _selectedIndex = 0; });
        },),
          body: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            children: [
              // Profile Section
              Container(
                padding: EdgeInsets.all(screenWidth * 0.06),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _showProfileImageOptions,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: screenWidth * 0.08,
                                backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                                backgroundImage: _getSupplierProfileImage(data),
                                child: _getSupplierProfileImage(data) == null
                                    ? Icon(
                                        Icons.store,
                                        size: screenWidth * 0.08,
                                        color: Color(0xFF6CA04A),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6CA04A),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'Supplier Name',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                data['email'] ?? user.email ?? '',
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.035,
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6CA04A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Role: ${data['role']?.toString().toUpperCase() ?? 'SUPPLIER'}',
                                  style: GoogleFonts.quicksand(
                                    fontSize: screenWidth * 0.03,
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
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.06),
              
              // Personal Information Section
              Container(
                padding: EdgeInsets.all(screenWidth * 0.06),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    // Phone Information
                    if (data['phone'] != null && data['phone'].toString().isNotEmpty)
                      _buildInfoRow(Icons.phone, 'Phone', data['phone'], screenWidth),
                    
                    if (data['phone'] != null && data['phone'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Address Information
                    if (data['address'] != null && data['address'].toString().isNotEmpty)
                      _buildInfoRow(Icons.location_on, 'Address', data['address'], screenWidth),
                    
                    if (data['address'] != null && data['address'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Business Name Information
                    if (data['businessName'] != null && data['businessName'].toString().isNotEmpty)
                      _buildInfoRow(Icons.business, 'Business Name', data['businessName'], screenWidth),
                    
                    if (data['businessName'] != null && data['businessName'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Business Type Information
                    if (data['businessType'] != null && data['businessType'].toString().isNotEmpty)
                      _buildInfoRow(Icons.category, 'Business Type', data['businessType'], screenWidth),
                    
                    if (data['businessType'] != null && data['businessType'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Description Information
                    if (data['description'] != null && data['description'].toString().isNotEmpty)
                      _buildInfoRow(Icons.description, 'Description', data['description'], screenWidth),
                    
                    if (data['description'] != null && data['description'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Member Since
                    _buildInfoRow(Icons.calendar_today, 'Member Since', 
                      data['createdAt'] != null 
                        ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                        : 'N/A', 
                      screenWidth),
                    
                    if (data['lastLogin'] != null) ...[
                      SizedBox(height: screenWidth * 0.03),
                      _buildInfoRow(Icons.access_time, 'Last Login', 
                        (data['lastLogin'] as Timestamp).toDate().toString().split(' ')[0], 
                        screenWidth),
                    ],
                    
                    if (data['isVerified'] != null) ...[
                      SizedBox(height: screenWidth * 0.03),
                      _buildInfoRow(
                        data['isVerified'] == true ? Icons.verified : Icons.pending,
                        'Verification Status',
                        data['isVerified'] == true ? 'Verified' : 'Pending',
                        screenWidth,
                        valueColor: data['isVerified'] == true ? Colors.green : Colors.orange,
                      ),
                    ],
                    
                    // Get Verified Button for unverified suppliers
                    if (data['isVerified'] != true) ...[
                      SizedBox(height: screenWidth * 0.04),
                      _buildGetVerifiedButton(screenWidth),
                    ],
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // Statistics Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Statistics',
                      style: GoogleFonts.quicksand(
                        fontSize: 18,
                        color: Color(0xFF222222),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('products')
                              .where('sellerId', isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return _buildProfileStat('Products', '$count');
                          },
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .where('sellerId', isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return _buildProfileStat('Orders', '$count');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, double screenWidth, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF757575), size: screenWidth * 0.04),
        SizedBox(width: screenWidth * 0.02),
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: screenWidth * 0.035,
            color: Color(0xFF757575),
            fontWeight: FontWeight.w400,
          ),
        ),
        Spacer(),
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: screenWidth * 0.035,
            color: valueColor ?? Color(0xFF757575),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.quicksand(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildGetVerifiedButton(double screenWidth) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showVerificationDialog,
        icon: Icon(Icons.verified_user, color: Colors.white),
        label: Text(
          'Get Verified',
          style: GoogleFonts.quicksand(
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF6CA04A),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VerificationDialog(),
    );
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    _nowNotifier.dispose();
    super.dispose();
  }
Future<void> _deleteProduct(String docId, String productName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.red, size: 24),
          SizedBox(width: 8),
          Text(
            'Delete Product',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete this product?',
            style: GoogleFonts.quicksand(fontSize: 16),
          ),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '"$productName"',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade800,
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            '⚠️ This action cannot be undone.',
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('Delete'),
        ),
      ],
    ),
  );
  
  if (confirmed == true) {
    try {
      await FirebaseFirestore.instance.collection('products').doc(docId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "$productName" deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete product: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
}

class VerificationDialog extends StatefulWidget {
  const VerificationDialog({super.key});

  @override
  State<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<VerificationDialog> {
  final AuthStateService _authService = AuthStateService();
  bool _isSubmitting = false;
  Uint8List? _frontIdBytes;
  Uint8List? _backIdBytes;
  String? _frontIdFileName;
  String? _backIdFileName;

  AuthUser? get user => _authService.currentUser;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Fixed Header
            Container(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: Color(0xFF6CA04A), size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ID Verification',
                      style: GoogleFonts.quicksand(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF6CA04A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF6CA04A).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verification Requirements:',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6CA04A),
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildRequirement('Upload clear photos of front and back of your valid ID'),
                          _buildRequirement('Ensure all text is readable and not blurred'),
                          _buildRequirement('Accepted IDs: Driver\'s License, Passport, National ID'),
                          _buildRequirement('Processing time: Up to 24 hours (auto-approved if not reviewed)'),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Front ID Upload
                    _buildImageUploadSection(
                      title: 'Front of ID',
                      subtitle: 'Tap to capture or select image',
                      imageBytes: _frontIdBytes,
                      fileName: _frontIdFileName,
                      onTap: () => _pickImage(true),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Back ID Upload
                    _buildImageUploadSection(
                      title: 'Back of ID',
                      subtitle: 'Tap to capture or select image',
                      imageBytes: _backIdBytes,
                      fileName: _backIdFileName,
                      onTap: () => _pickImage(false),
                    ),
                    
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Fixed Submit Button
            Container(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit() ? _submitVerification : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit() ? Color(0xFF6CA04A) : Colors.grey[400],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _canSubmit() ? 2 : 0,
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
    strokeWidth: 2.5, // adjust thickness
    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Processing...',
                              style: GoogleFonts.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Submit for Verification',
                          style: GoogleFonts.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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

  Widget _buildRequirement(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF6CA04A), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection({
    required String title,
    required String subtitle,
    required Uint8List? imageBytes,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      imageBytes != null ? Icons.check_circle : Icons.camera_alt,
                      color: imageBytes != null ? Color(0xFF6CA04A) : Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  imageBytes != null ? 'Image captured: $fileName' : subtitle,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: imageBytes != null ? Color(0xFF6CA04A) : Colors.grey[600],
                  ),
                ),
                if (imageBytes != null) ...[
                  SizedBox(height: 12),
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(bool isFront) async {
    try {
      // Show image source selection dialog
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      if (source == ImageSource.camera) {
        // Use custom ID camera widget with size detection
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) => IdCameraWidget(
              title: isFront ? 'Front of ID' : 'Back of ID',
              onImageCaptured: (bytes, fileName) {
                Navigator.of(context).pop({
                  'bytes': bytes,
                  'fileName': fileName,
                });
              },
            ),
          ),
        );

        if (result != null) {
          setState(() {
            if (isFront) {
              _frontIdBytes = result['bytes'] as Uint8List;
              _frontIdFileName = result['fileName'] as String;
            } else {
              _backIdBytes = result['bytes'] as Uint8List;
              _backIdFileName = result['fileName'] as String;
            }
          });
        }
      } else {
        // Use regular image picker for gallery
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1500,
          maxHeight: 1500,
          imageQuality: 90,
        );

        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            if (isFront) {
              _frontIdBytes = bytes;
              _frontIdFileName = image.name;
            } else {
              _backIdBytes = bytes;
              _backIdFileName = image.name;
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Image Source',
                  style: GoogleFonts.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                SizedBox(height: 20),
                
                // Camera Option with ID detection
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(ImageSource.camera),
                    icon: Icon(Icons.camera_alt, color: Colors.white),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Take Photo with ID Detection',
                          style: GoogleFonts.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Guided capture with frame overlay',
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6CA04A),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Gallery Option
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
                    icon: Icon(Icons.photo_library, color: Color(0xFF6CA04A)),
                    label: Text(
                      'Choose from Gallery',
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6CA04A),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Color(0xFF6CA04A)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Cancel Option
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _canSubmit() {
    return _frontIdBytes != null && _backIdBytes != null && !_isSubmitting;
  }

  Future<void> _submitVerification() async {
    if (!_canSubmit() || user == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get user data for submission
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final supplierName = userData['name'] ?? 'Unknown Supplier';
      final supplierEmail = userData['email'] ?? user!.email ?? '';

      // Submit verification request
      final verificationId = await SupplierVerificationService.submitVerificationRequest(
        supplierId: user!.uid,
        supplierName: supplierName,
        supplierEmail: supplierEmail,
        frontIdImageBytes: _frontIdBytes!,
        backIdImageBytes: _backIdBytes!,
      );

      if (verificationId != null) {
        // Show success dialog
        Navigator.of(context).pop(); // Close verification dialog
        _showSuccessDialog();
      } else {
        throw Exception('Failed to submit verification request');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting verification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Color(0xFF6CA04A),
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Verification Submitted!',
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Your ID verification has been submitted successfully. Our team will review your documents within 24 hours. If not reviewed manually, your account will be automatically verified.',
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6CA04A),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Got it!',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (migrated to standalone widget StockIndicator below)
}

class StockIndicator extends StatelessWidget {
  final int quantity;
  const StockIndicator({super.key, required this.quantity});

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: const Text(
          'OUT',
          style: TextStyle(
            fontSize: 8,
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (quantity <= 5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Text(
          'LOW',
          style: TextStyle(
            fontSize: 8,
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}