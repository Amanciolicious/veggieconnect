// ignore_for_file: deprecated_member_use, use_build_context_synchronously, library_private_types_in_public_api, avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:veggieconnect/authentication/login_page.dart';
import 'package:veggieconnect/supplier-side/supplier_add_product_page.dart';
import 'package:veggieconnect/supplier-side/supplier_orders_page.dart';
import 'package:veggieconnect/supplier-side/supplier_chat_list_page.dart';
import 'package:veggieconnect/supplier-side/supplier_map_page.dart';
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

class _SupplierDashboardState extends State<SupplierDashboard> {
  int _selectedIndex = 0;
  String? _localProfileImagePath;
  bool _showVerificationNotification = false;

  final AuthStateService _authService = AuthStateService();

  AuthUser? get user => _authService.currentUser;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        title: Text(
          'Supplier Dashboard',
          style: GoogleFonts.quicksand(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        elevation: 0,
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
                          builder: (context) => const NotificationCenter(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications,
                      color: Colors.white,
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
      ),
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
                  DrawerItem(icon: Icons.inventory, title: 'Manage Products', index: 1),
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
                      await _authService.signOut();
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
        backgroundColor: const Color(0xFF4CAF50),
        color: Colors.white,
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        items: const [
          Icon(Icons.home, size: 30, color: Colors.green,),
          Icon(Icons.inventory, size: 30, color: Colors.green,),
          Icon(Icons.inventory_2, size: 30, color: Colors.green,),
          Icon(Icons.shopping_cart, size: 30, color: Colors.green,),
          Icon(Icons.person, size: 30, color: Colors.green,),
        ],
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
                  return _buildStatCard(cardRadius, 'Total Products', '$count', Icons.inventory, Colors.blue);
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
                    Icons.attach_money, 
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
          Text(
            'Stock Management',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              color: Color(0xFF222222),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          _buildStockOverview(),
        ],
      ),
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
                    Icon(icon, color: color, size: iconSize),
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
    
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'My Products',
                  style: GoogleFonts.quicksand(
                    fontSize: 20,
                    color: Color(0xFF222222),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddProductPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6CA04A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Add',
                  style: GoogleFonts.quicksand(fontSize: 16),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Status toggle chips
          _buildStatusToggle(),
          SizedBox(height: 12),
          _buildProductList(),
        ],
      ),
    );
  }

  String _productStatusFilter = 'All';

  Widget _buildStatusToggle() {
    final statuses = ['All', 'approved', 'pending', 'rejected'];
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
        // Local filter by status
        if (_productStatusFilter != 'All') {
          products = products.where((d) => ((d.data() as Map<String, dynamic>)['status'] ?? 'pending') == _productStatusFilter).toList();
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
                              Text(
                                'Stock: ${product['quantity'] ?? 0}',
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
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

  Widget _buildStockManagementTab() {

    
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Keep stock list only; the overview is shown on the Overview tab
          _buildStockList(),
        ],
      ),
    );
  }

  Widget _buildStockOverview() {
    final user = _authService.currentUser;
    
    if (user == null) {
      return const Center(child: Text('Not logged in.'));
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
              loadingText: 'Loading...',
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading data',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.w400,
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
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard(BorderRadius.circular(20), 'Low Stock', '$lowStockProducts', Icons.warning, Colors.orange),
            _buildStatCard(BorderRadius.circular(20), 'Out of Stock', '$outOfStockProducts', Icons.remove_shopping_cart, Colors.red),
            _buildStatCard(BorderRadius.circular(20), 'Total Value', '₱${totalValue.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
          ],
        );
        
      },
    );
    
  }

  Widget _buildStockList() {
    final user = _authService.currentUser;
    
    if (user == null) {
      return Center(child: Text('Not logged in.', style: GoogleFonts.quicksand(fontSize: 16)));
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
              loadingText: 'Loading orders...',
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.quicksand(fontSize: 14)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No products yet.', style: GoogleFonts.quicksand(fontSize: 16)));
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
            if (quantity <= 0) {
              stockColor = Colors.red;
            } else if (quantity <= 5) {
              stockColor = Colors.orange;
            } else {
              stockColor = Colors.green;
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Unknown Product',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              color: Color(0xFF222222),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '₱${price.toStringAsFixed(2)}',
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              color: Color(0xFF6CA04A),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 16,
                                color: stockColor,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '$quantity ${product['unit'] ?? ''}',
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  color: stockColor,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Increase'),
                                content: Text('Increase stock for this product by 1?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              _updateStock(docId, quantity + 1);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF6CA04A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Decrease'),
                                content: Text('Decrease stock for this product by 1?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              _updateStock(docId, quantity > 0 ? quantity - 1 : 0);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Icon(Icons.remove, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStock(String productId, int newQuantity) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'quantity': newQuantity});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock updated to $newQuantity')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update stock: $e')),
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
        
        return SingleChildScrollView(
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
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('supplier_ratings')
                              .where('sellerId', isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            double avg = 0;
                            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                              double sum = 0;
                              for (var doc in snapshot.data!.docs) {
                                sum += (doc['rating'] ?? 0) is int
                                  ? (doc['rating'] ?? 0).toDouble()
                                  : (doc['rating'] ?? 0);
                              }
                              avg = sum / snapshot.data!.docs.length;
                            }
                            return _buildProfileStat('Rating', avg > 0 ? avg.toStringAsFixed(1) : 'N/A');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
          mainAxisSize: MainAxisSize.min,
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
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
            padding: EdgeInsets.all(16),
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
}