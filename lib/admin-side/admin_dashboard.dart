// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unrelated_type_equality_checks, avoid_print
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/modern_analytics_widgets.dart';
import '../services/modern_analytics_service.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:veggieconnect/admin-side/admin_farm_map_page.dart';
import 'package:veggieconnect/services/tax_service.dart';
import 'package:veggieconnect/widgets/notification_center.dart';
import '../services/revenue_service.dart';
import '../authentication/login_page.dart';
import '../services/cloudinary_service.dart';
import '../widgets/lottie_loading_widget.dart';
import 'admin_verify_listings_page.dart';
import 'admin_manage_accounts_page.dart';
import 'admin_verification_review_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/role_page_header.dart';
import '../widgets/modern_wave_drawer.dart';
import '../services/auth_state_service.dart';
import '../services/notification_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  String? _localProfileImagePath;
  final AuthStateService _authService = AuthStateService();
  final NotificationService _notificationService = NotificationService();

  AuthUser? get user => _authService.currentUser;


  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;
    _initializeConnectivity();
    _loadLocalProfileImage();
    _verifyAdminUsers();
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

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _initializeConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
      });
      
      if (!_isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Network connection lost. Auto-approval may be delayed.'),
            backgroundColor: Color(0xFFE57373),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Network connection restored.'),
            backgroundColor: Color(0xFF6CA04A),
          ),
        );
      }
    });
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
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
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF222222),
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
        const SnackBar(content: Text('Profile picture updated successfully!')),
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

  ImageProvider? _getAdminProfileImage(Map<String, dynamic>? userData) {
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
      final file = File(_localProfileImagePath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    
    return null;
  }

  Future<void> _verifyAdminUsers() async {
    try {
      print('🔍 Verifying admin users in database...');
      
      // Check for users with admin role
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      
      print('👥 Found ${adminSnapshot.docs.length} admin users');
      
      for (final doc in adminSnapshot.docs) {
        final userData = doc.data();
        print('👤 Admin: ${userData['email']} (ID: ${doc.id})');
        print('   - FCM Token: ${userData['fcmToken'] != null ? "✅ Present" : "❌ Missing"}');
        print('   - Role: ${userData['role']}');
      }
      
      if (adminSnapshot.docs.isEmpty) {
        print('⚠️ No admin users found! Creating test admin...');
        
        // Get current user from AuthStateService
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'role': 'admin'});
          print('✅ Current user promoted to admin');
        }
      }
    } catch (e) {
      print('❌ Error verifying admin users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: _selectedIndex == 0 ? ModernAppBar(
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.quicksand(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        showSearch: false,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        actions: [
          // Notification Bell with Badge
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationCenter(),
                        ),
                      );
                    },
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
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
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
          const SizedBox(width: 8),
        ],
      ) : null,
      drawer: _buildModernDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildOverviewTab(),
          _buildAnalyticsTab(),
          _buildFarmLocationsTab(),
          AdminVerifyListingsPage(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        onTap: (index) {
          setState(() { _selectedIndex = index; });
        },
        backgroundColor: Color(0xFF4CAF50),
        color: Colors.white,
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        items: const [
          Icon(Icons.home, size: 30, color: Colors.green),
          Icon(Icons.analytics, size: 30, color: Colors.green),
          Icon(Icons.location_on, size: 30, color: Colors.green),
          Icon(Icons.verified, size: 30, color: Colors.green),
          Icon(Icons.person, size: 30, color: Colors.green),
        ],
      ),
    );
  }

  

  Widget _buildModernDrawer() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _authService.currentUser != null 
        ? FirebaseFirestore.instance.collection('users').doc(_authService.currentUser!.uid).snapshots()
        : null,
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final displayName = userData?['name'] ?? _authService.currentUser?.displayName ?? 'Admin';
        final email = _authService.currentUser?.email ?? 'admin@email.com';
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
                DrawerItem(icon: Icons.analytics, title: 'Analytics', index: 1),
                DrawerItem(icon: Icons.location_on, title: 'Farm Locations', index: 2),
                DrawerItem(icon: Icons.verified, title: 'Verify Listings', index: 3),
                DrawerItem(icon: Icons.person, title: 'Profile', index: 4),
              ],
            ),
            DrawerSection(
              title: 'ADMIN TOOLS',
              items: [
                DrawerItem(
                  icon: Icons.manage_accounts,
                  title: 'Manage Accounts',
                  index: -1,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminManageAccountsPage()),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.verified_user,
                  title: 'Supplier Verification',
                  index: -1,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminVerificationReviewPage()),
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
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions first
          Text(
            'Quick Actions',
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          _buildActionCard(
            title: 'Manage Accounts',
            subtitle: 'View and manage user accounts',
            icon: Icons.manage_accounts,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminManageAccountsPage()),
              );
            },
          ),
          _buildActionCard(
            title: 'Supplier Verification',
            subtitle: 'Review supplier ID verification requests',
            icon: Icons.verified_user,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminVerificationReviewPage()),
              );
            },
          ),
          _buildActionCard(
            title: 'Verify Listings',
            subtitle: 'Review pending product listings',
            icon: Icons.verified,
            onTap: () {
              setState(() {
                _selectedIndex = 3;
              });
            },
          ),
          const SizedBox(height: 24),

          // Overview compact
          Text(
            'System Overview',
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [
              // Total Users (suppliers and buyers only, exclude admins)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', whereIn: ['supplier', 'buyer', 'Supplier', 'Buyer'])
                    .snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                    count = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final role = (data['role'] ?? '').toString().toLowerCase();
                      return role == 'supplier' || role == 'buyer';
                    }).length;
                  }
                  return _buildStatCard(
                    title: 'Total Users',
                    value: '$count',
                    icon: Icons.people,
                    color: const Color(0xFF2196F3),
                  );
                },
              ),
              // Total Products
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _buildStatCard(
                    title: 'Total Products',
                    value: '$count',
                    icon: Icons.inventory,
                    color: const Color(0xFF4CAF50),
                  );
                },
              ),
              // Total Orders
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _buildStatCard(
                    title: 'Total Orders',
                    value: '$count',
                    icon: Icons.shopping_cart,
                    color: const Color(0xFFFF9800),
                  );
                },
              ),
              // Revenue
              StreamBuilder<double>(
                stream: RevenueService.getTotalRevenueStream(),
                builder: (context, snapshot) {
                  final revenue = snapshot.data ?? 0.0;
                  return _buildStatCard(
                    title: 'Total Revenue',
                    value: RevenueService.formatCurrency(revenue),
                    icon: Icons.attach_money,
                    color: const Color(0xFF4CAF50),
                  );
                },
              ),
              // Tax Collected
              FutureBuilder<double>(
                future: TaxService.getTotalTaxCollected(),
                builder: (context, snapshot) {
                  final taxCollected = snapshot.data ?? 0.0;
                  return _buildStatCard(
                    title: 'Tax Collected',
                    value: TaxService.formatCurrency(taxCollected),
                    icon: Icons.account_balance,
                    color: const Color(0xFF9C27B0),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Scaffold(
      appBar: RolePageHeader(
        title: 'Analytics',
        onBackTap: () => setState(() { _selectedIndex = 0; }),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Real-time KPIs Section
            _buildRealTimeKPIsSection(),
            const SizedBox(height: 24),
            
            // Business Performance Section
            _buildBusinessPerformanceSection(),
            const SizedBox(height: 24),
            
            // User Engagement Section
            _buildUserEngagementSection(),
            const SizedBox(height: 24),
            
            // Product Performance Section
            _buildProductPerformanceSection(),
            const SizedBox(height: 24),
            
            // Market Trends Section
            _buildMarketTrendsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeKPIsSection() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: ModernAnalyticsService.getRealTimeKPIsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard('Real-time KPIs', 'Loading real-time data...');
        }

        final data = snapshot.data ?? {};
        final todayRevenue = data['todayRevenue'] ?? 0.0;
        final todayOrders = data['todayOrders'] ?? 0;
        final todayCustomers = data['todayCustomers'] ?? 0;
        final dailyGrowth = data['dailyGrowth'] ?? 0.0;
        final todayAOV = data['todayAOV'] ?? 0.0;
        final aovGrowth = data['aovGrowth'] ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Real-time KPIs',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.88,
              children: [
                _buildKPICard(
                  title: 'Today\'s Revenue',
                  value: ModernAnalyticsService.formatCurrency(todayRevenue),
                  change: dailyGrowth != 0 ? '${dailyGrowth > 0 ? '+' : ''}${dailyGrowth.toStringAsFixed(1)}%' : null,
                  icon: Icons.attach_money,
                  color: const Color(0xFF4CAF50),
                  isPositive: dailyGrowth >= 0,
                ),
                _buildKPICard(
                  title: 'Today\'s Orders',
                  value: todayOrders.toString(),
                  change: data['yesterdayOrders'] != null && data['yesterdayOrders'] > 0 
                      ? '${((todayOrders - data['yesterdayOrders']) / data['yesterdayOrders'] * 100).toStringAsFixed(1)}%'
                      : null,
                  icon: Icons.shopping_cart,
                  color: const Color(0xFF2196F3),
                  isPositive: todayOrders >= (data['yesterdayOrders'] ?? 0),
                ),
                _buildKPICard(
                  title: 'Active Customers',
                  value: todayCustomers.toString(),
                  subtitle: 'Today',
                  icon: Icons.people,
                  color: const Color(0xFF9C27B0),
                ),
                _buildKPICard(
                  title: 'Average Order Value',
                  value: ModernAnalyticsService.formatCurrency(todayAOV),
                  change: aovGrowth != 0 ? '${aovGrowth > 0 ? '+' : ''}${aovGrowth.toStringAsFixed(1)}%' : null,
                  icon: Icons.trending_up,
                  color: const Color(0xFFFF9800),
                  isPositive: aovGrowth >= 0,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBusinessPerformanceSection() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: ModernAnalyticsService.getBusinessPerformanceStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard('Business Performance', 'Loading business metrics...');
        }

        final data = snapshot.data ?? {};
        final totalRevenue = data['totalRevenue'] ?? 0.0;
        final totalOrders = data['totalOrders'] ?? 0;
        final completionRate = data['completionRate'] ?? 0.0;
        final averageOrderValue = data['averageOrderValue'] ?? 0.0;
        final conversionFunnel = data['conversionFunnel'] as Map<String, dynamic>? ?? {};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Performance',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildKPICard(
                    title: 'Total Revenue',
                    value: ModernAnalyticsService.formatCurrency(totalRevenue),
                    icon: Icons.account_balance_wallet,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKPICard(
                    title: 'Total Orders',
                    value: ModernAnalyticsService.formatNumber(totalOrders),
                    icon: Icons.receipt_long,
                    color: const Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildProgressCard(
                    title: 'Order Completion Rate',
                    value: completionRate,
                    maxValue: 100,
                    color: const Color(0xFF4CAF50),
                    description: 'Orders successfully completed',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKPICard(
                    title: 'Average Order Value',
                    value: ModernAnalyticsService.formatCurrency(averageOrderValue),
                    icon: Icons.trending_up,
                    color: const Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildConversionFunnelChart(conversionFunnel),
          ],
        );
      },
    );
  }

  Widget _buildUserEngagementSection() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: ModernAnalyticsService.getUserEngagementStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard('User Engagement', 'Loading user data...');
        }

        final data = snapshot.data ?? {};
        final totalUsers = data['totalUsers'] ?? 0;
        final activeUsers = data['activeUsers'] ?? 0;
        final newUsers = data['newUsers'] ?? 0;
        final activeUserRate = data['activeUserRate'] ?? 0.0;
        final topActiveUsers = data['topActiveUsers'] as List<dynamic>? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Engagement',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.05,
              children: [
                _buildKPICard(
                  title: 'Total Users',
                  value: ModernAnalyticsService.formatNumber(totalUsers),
                  icon: Icons.people,
                  color: const Color(0xFF9C27B0),
                ),
                _buildKPICard(
                  title: 'Active Users',
                  value: ModernAnalyticsService.formatNumber(activeUsers),
                  subtitle: 'Last 7 days',
                  icon: Icons.people_alt,
                  color: const Color(0xFF4CAF50),
                ),
                _buildKPICard(
                  title: 'New Users',
                  value: ModernAnalyticsService.formatNumber(newUsers),
                  subtitle: 'Last 30 days',
                  icon: Icons.person_add,
                  color: const Color(0xFF2196F3),
                ),
                _buildProgressCard(
                  title: 'Active User Rate',
                  value: activeUserRate,
                  maxValue: 100,
                  color: const Color(0xFF4CAF50),
                  description: 'Users active in last 7 days',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTopPerformersCard(
              title: 'Most Active Users',
              items: topActiveUsers.cast<Map<String, dynamic>>(),
              nameKey: 'name',
              valueKey: 'activityScore',
              subtitleKey: 'role',
              itemIcon: Icons.star,
              iconColor: const Color(0xFFFF9800),
              valueSuffix: ' pts',
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductPerformanceSection() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: ModernAnalyticsService.getProductPerformanceStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
          return ModernAnalyticsCard(
            title: 'Product Performance',
            icon: Icons.inventory,
            iconColor: const Color(0xFFFF9800),
            isLoading: true,
            loadingText: 'Loading product data...',
            child: const SizedBox.shrink(),
          );
        }

        final data = snapshot.data ?? {};
        final totalProducts = data['totalProducts'] ?? 0;
        final activeProducts = data['activeProducts'] ?? 0;
        final lowStockProducts = data['lowStockProducts'] ?? 0;
        final outOfStockProducts = data['outOfStockProducts'] ?? 0;
        final stockHealthScore = data['stockHealthScore'] ?? 0.0;
        final topPerformingProducts = data['topPerformingProducts'] as List<dynamic>? ?? [];
        final lowStockAlerts = data['lowStockAlerts'] as List<dynamic>? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Performance',
              style: GoogleFonts.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                ModernKPIWidget(
                  title: 'Total Products',
                  value: ModernAnalyticsService.formatNumber(totalProducts),
                  icon: Icons.inventory,
                  color: const Color(0xFF9C27B0),
                ),
                ModernKPIWidget(
                  title: 'Active Products',
                  value: ModernAnalyticsService.formatNumber(activeProducts),
                  icon: Icons.check_circle,
                  color: const Color(0xFF4CAF50),
                ),
                ModernKPIWidget(
                  title: 'Low Stock',
                  value: ModernAnalyticsService.formatNumber(lowStockProducts),
                  icon: Icons.warning,
                  color: const Color(0xFFFF9800),
                ),
                ModernKPIWidget(
                  title: 'Out of Stock',
                  value: ModernAnalyticsService.formatNumber(outOfStockProducts),
                  icon: Icons.error,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            PerformanceIndicatorWidget(
              title: 'Stock Health Score',
              value: stockHealthScore,
              maxValue: 100,
              color: stockHealthScore >= 80 ? const Color(0xFF4CAF50) : 
                     stockHealthScore >= 60 ? const Color(0xFFFF9800) : Colors.red,
              description: 'Percentage of products with healthy stock levels',
            ),
            const SizedBox(height: 20),
            if (topPerformingProducts.isNotEmpty)
              TopPerformersWidget(
                title: 'Top Performing Products',
                items: topPerformingProducts.cast<Map<String, dynamic>>(),
                nameKey: 'name',
                valueKey: 'revenue',
                subtitleKey: 'category',
                itemIcon: Icons.star,
                iconColor: const Color(0xFF4CAF50),
                valueSuffix: '',
              ),
            if (lowStockAlerts.isNotEmpty) ...[
              const SizedBox(height: 20),
              TopPerformersWidget(
                title: 'Stock Alerts',
                items: lowStockAlerts.cast<Map<String, dynamic>>(),
                nameKey: 'name',
                valueKey: 'quantity',
                subtitleKey: 'status',
                itemIcon: Icons.warning,
                iconColor: Colors.red,
                valueSuffix: ' units',
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMarketTrendsSection() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: ModernAnalyticsService.getMarketTrendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ModernAnalyticsCard(
            title: 'Market Trends',
            icon: Icons.trending_up,
            iconColor: const Color(0xFF2196F3),
            isLoading: true,
            loadingText: 'Loading market data...',
            child: const SizedBox.shrink(),
          );
        }

        final data = snapshot.data ?? {};
        final peakHours = data['peakHours'] as List<dynamic>? ?? [];
        final categoryTrends = data['categoryTrends'] as Map<String, dynamic>? ?? {};
        final currentSeason = data['currentSeason'] ?? 'Unknown';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market Trends',
              style: GoogleFonts.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                            Icon(
                              Icons.wb_sunny,
                              color: const Color(0xFF4CAF50),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current Season',
                              style: GoogleFonts.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                      ],
                    ),
                    const SizedBox(height: 12),
                        Text(
                          currentSeason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                    ),
                  ],
                ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: const Color(0xFF2196F3),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Peak Hours',
                              style: GoogleFonts.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          peakHours.isNotEmpty ? peakHours.first['hour'] : 'N/A',
                          style: GoogleFonts.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        if (peakHours.isNotEmpty)
                          Text(
                            '${peakHours.first['orders']} orders',
                            style: GoogleFonts.quicksand(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
            if (categoryTrends.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildCategoryTrendsChart(categoryTrends),
            ],
          ],
        );
      },
    );
  }

  Widget _buildConversionFunnelChart(Map<String, dynamic> funnel) {
    final totalOrders = funnel['totalOrders'] ?? 0;
    final completedOrders = funnel['completedOrders'] ?? 0;
    final pendingOrders = funnel['pendingOrders'] ?? 0;
    final cancelledOrders = funnel['cancelledOrders'] ?? 0;

    return ModernChartWidget(
      title: 'Order Conversion Funnel',
      subtitle: 'Order status distribution',
      chart: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: completedOrders.toDouble(),
              title: 'Completed\n${((completedOrders / totalOrders) * 100).toStringAsFixed(1)}%',
              color: const Color(0xFF4CAF50),
              radius: 60,
              titleStyle: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: pendingOrders.toDouble(),
              title: 'Pending\n${((pendingOrders / totalOrders) * 100).toStringAsFixed(1)}%',
              color: const Color(0xFFFF9800),
              radius: 60,
              titleStyle: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: cancelledOrders.toDouble(),
              title: 'Cancelled\n${((cancelledOrders / totalOrders) * 100).toStringAsFixed(1)}%',
              color: Colors.red,
              radius: 60,
              titleStyle: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
      legends: ['Completed', 'Pending', 'Cancelled'],
      legendColors: [const Color(0xFF4CAF50), const Color(0xFFFF9800), Colors.red],
    );
  }

  Widget _buildCategoryTrendsChart(Map<String, dynamic> trends) {
    final entries = trends.entries.toList()
      ..sort((a, b) => (b.value as double).compareTo(a.value as double));
    
    final topCategories = entries.take(5).toList();
    
    return ModernChartWidget(
      title: 'Top Product Categories',
      subtitle: 'Revenue by category',
      chart: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: topCategories.isNotEmpty ? (topCategories.first.value as double) * 1.2 : 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < topCategories.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        topCategories[index].key.length > 8 
                            ? '${topCategories[index].key.substring(0, 8)}...'
                            : topCategories[index].key,
                        style: GoogleFonts.quicksand(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    ModernAnalyticsService.formatCurrency(value),
                    style: GoogleFonts.quicksand(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: topCategories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: category.value as double,
                  color: const Color(0xFF4CAF50),
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }


  Widget _buildKPICard({
    required String title,
    required String value,
    String? subtitle,
    String? change,
    required IconData icon,
    required Color color,
    bool isPositive = true,
  }) {
    return Container(
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 16,
                  ),
                ),
                const Spacer(),
                if (change != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPositive 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up : Icons.trending_down,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          change,
                          style: GoogleFonts.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                color: const Color(0xFF757575),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.quicksand(
                  fontSize: 11,
                  color: const Color(0xFF757575),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required double value,
    required double maxValue,
    required Color color,
    String? description,
  }) {
    final percentage = (value / maxValue * 100).clamp(0, 100);
    
    return Container(
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(1)}%',
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: const Color(0xFF757575),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformersCard({
    required String title,
    required List<Map<String, dynamic>> items,
    required String nameKey,
    required String valueKey,
    String? subtitleKey,
    IconData? itemIcon,
    Color? iconColor,
    int maxItems = 5,
    String valueSuffix = '',
  }) {
    return Container(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            ...items.take(maxItems).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isTopThree = index < 3;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isTopThree 
                      ? (iconColor ?? const Color(0xFF4CAF50)).withOpacity(0.05)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: isTopThree 
                      ? Border.all(
                          color: (iconColor ?? const Color(0xFF4CAF50)).withOpacity(0.2),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isTopThree 
                            ? (iconColor ?? const Color(0xFF4CAF50))
                            : Colors.grey[400],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (itemIcon != null) ...[
                      Icon(
                        itemIcon,
                        color: iconColor ?? const Color(0xFF4CAF50),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item[nameKey]?.toString() ?? 'Unknown',
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          if (subtitleKey != null && item[subtitleKey] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              item[subtitleKey].toString(),
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                color: const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '${item[valueKey]?.toString() ?? '0'}$valueSuffix',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isTopThree 
                            ? (iconColor ?? const Color(0xFF4CAF50))
                            : const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(String title, String loadingText) {
    return Container(
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
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 16),
            Text(
              loadingText,
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

  Widget _buildFarmLocationsTab() {
    return const AdminFarmMapPage();
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
              size: 120,
              showText: true,
              loadingText: 'Loading dashboard...',
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
        },
          ),
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
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
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
                                backgroundColor: Color(0xFF4CAF50).withOpacity(0.1),
                                backgroundImage: _getAdminProfileImage(data),
                                child: _getAdminProfileImage(data) == null
                                    ? Icon(
                                        Icons.admin_panel_settings,
                                        size: screenWidth * 0.08,
                                        color: Color(0xFF4CAF50),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF4CAF50),
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
                                data['name'] ?? user.displayName ?? 'Admin User',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                data['email'] ?? user.email ?? '',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: Color(0xFF757575),
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFF4CAF50).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Role: ${data['role']?.toString().toUpperCase() ?? 'ADMIN'}',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.03,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4CAF50),
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
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    
                    // Phone Information
                    if (data['phone'] != null && data['phone'].toString().isNotEmpty)
                      _buildAdminInfoRow(Icons.phone, 'Phone', data['phone'], screenWidth),
                    
                    if (data['phone'] != null && data['phone'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Address Information
                    if (data['address'] != null && data['address'].toString().isNotEmpty)
                      _buildAdminInfoRow(Icons.location_on, 'Address', data['address'], screenWidth),
                    
                    if (data['address'] != null && data['address'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Department Information
                    if (data['department'] != null && data['department'].toString().isNotEmpty)
                      _buildAdminInfoRow(Icons.business, 'Department', data['department'], screenWidth),
                    
                    if (data['department'] != null && data['department'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Employee ID Information
                    if (data['employeeId'] != null && data['employeeId'].toString().isNotEmpty)
                      _buildAdminInfoRow(Icons.badge, 'Employee ID', data['employeeId'], screenWidth),
                    
                    if (data['employeeId'] != null && data['employeeId'].toString().isNotEmpty)
                      SizedBox(height: screenWidth * 0.03),
                    
                    // Member Since
                    _buildAdminInfoRow(Icons.calendar_today, 'Member Since', 
                      data['createdAt'] != null 
                        ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                        : 'N/A', 
                      screenWidth),
                    
                    if (data['lastLogin'] != null) ...[
                      SizedBox(height: screenWidth * 0.03),
                      _buildAdminInfoRow(Icons.access_time, 'Last Login', 
                        (data['lastLogin'] as Timestamp).toDate().toString().split(' ')[0], 
                        screenWidth),
                    ],
                    
                    SizedBox(height: screenWidth * 0.03),
                    _buildAdminInfoRow(Icons.security, 'Access Level', 
                      data['accessLevel'] ?? 'Full Access', 
                      screenWidth),
                    
                    if (data['isActive'] != null) ...[
                      SizedBox(height: screenWidth * 0.03),
                      _buildAdminInfoRow(
                        data['isActive'] == true ? Icons.check_circle : Icons.cancel,
                        'Account Status',
                        data['isActive'] == true ? 'Active' : 'Inactive',
                        screenWidth,
                        valueColor: data['isActive'] == true ? Colors.green : Colors.red,
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // System Statistics Section
              _buildModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Overview',
                      style: GoogleFonts.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('role', whereIn: ['supplier', 'buyer', 'Supplier', 'Buyer'])
                              .snapshots(),
                          builder: (context, snapshot) {
                            int count = 0;
                            if (snapshot.hasData) {
                              count = snapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final role = (data['role'] ?? '').toString().toLowerCase();
                                return role == 'supplier' || role == 'buyer';
                              }).length;
                            }
                            return _buildAdminStat('Total Users', '$count');
                          },
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('products')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return _buildAdminStat('Products', '$count');
                          },
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return _buildAdminStat('Orders', '$count');
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

  Widget _buildAdminInfoRow(IconData icon, String label, String value, double screenWidth, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF757575), size: screenWidth * 0.04),
        SizedBox(width: screenWidth * 0.02),
        Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
          ),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            color: valueColor ?? Color(0xFF757575),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 14,
            color: const Color(0xFF757575),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: const Color(0xFF757575),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Icon(Icons.trending_up, color: color, size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                color: const Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
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
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

// ignore: unused_element
class _AdminSubpage extends StatelessWidget {
  final String title;
  final Widget content;
  const _AdminSubpage({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: RolePageHeader(
        title: title,
        onBackTap: () => Navigator.of(context).pop(),
      ),
      body: content,
    );
  }
}