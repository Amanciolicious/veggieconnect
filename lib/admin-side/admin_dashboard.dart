// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unrelated_type_equality_checks
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:veggieconnect/admin-side/admin_farm_map_page.dart';
import 'package:veggieconnect/services/tax_service.dart';
import '../authentication/login_page.dart';
import '../services/cloudinary_service.dart';
import '../services/farm_auto_approval_service.dart';
import 'admin_verify_listings_page.dart';
import 'admin_reports_page.dart';
import 'admin_manage_accounts_page.dart';
import 'farm_location_requests_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/modern_card.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final String _searchQuery = '';
  String? _roleFilter; // e.g., 'Supplier', 'Customer', 'Admin'
  String? _statusFilter; // e.g., 'Active', 'Pending', 'Suspended'
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  String? _localProfileImagePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeConnectivity();
    _loadLocalProfileImage();
  }

  Future<void> _loadLocalProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
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
                fontFamily: 'Poppins',
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
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadViaCloudinary() async {
    Navigator.pop(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
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
    final user = FirebaseAuth.instance.currentUser;
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: ModernAppBar(
        title: 'Admin Dashboard',
        showSearch: false,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
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
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: const Color(0xFF4CAF50),
        color: Colors.white,
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
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseAuth.instance.currentUser != null 
                  ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                  : null,
                builder: (context, snapshot) {
                  final userData = snapshot.data?.data() as Map<String, dynamic>?;
                  final displayName = userData?['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Admin';
                  final email = FirebaseAuth.instance.currentUser?.email ?? 'admin@email.com';
                  
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
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.white,
                                backgroundImage: _getAdminProfileImage(userData),
                                child: _getAdminProfileImage(userData) == null 
                                  ? const Icon(Icons.admin_panel_settings, size: 32, color: Color(0xFF4CAF50))
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
                        email,
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
          _buildDrawerItem(Icons.dashboard, 'Overview', 0),
          _buildDrawerItem(Icons.analytics, 'Analytics', 1),
          _buildDrawerItem(Icons.location_on, 'Farm Locations', 2),
          _buildDrawerItem(Icons.verified, 'Verify Listings', 3),
          _buildDrawerItem(Icons.person, 'Profile', 4),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: Color(0xFF4CAF50), size: 24),
            title: Text(
              'Manage Accounts',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminManageAccountsPage()),
              );
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red, size: 24),
            title: Text(
              'Logout',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF757575),
        size: 24,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF1A1A1A),
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF4CAF50).withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
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
                    // Filter out admin accounts from the count
                    count = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final role = (data['role'] ?? '').toString().toLowerCase();
                      return role == 'supplier' || role == 'buyer';
                    }).length;
                  }
                  return StatCard(
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
                  return StatCard(
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
                  return StatCard(
                    title: 'Total Orders',
                    value: '$count',
                    icon: Icons.shopping_cart,
                    color: const Color(0xFFFF9800),
                  );
                },
              ),
              // Revenue
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('status', isEqualTo: 'completed')
                    .snapshots(),
                builder: (context, snapshot) {
                  double revenue = 0;
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      revenue += (data['totalPrice'] ?? 0).toDouble();
                    }
                  }
                  return StatCard(
                    title: 'Total Revenue',
                    value: '₱${revenue.toStringAsFixed(2)}',
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
                  return StatCard(
                    title: 'Tax Collected',
                    value: TaxService.formatCurrency(taxCollected),
                    icon: Icons.account_balance,
                    color: const Color(0xFF9C27B0),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          ActionCard(
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
          ActionCard(
            title: 'Verify Listings',
            subtitle: 'Review pending product listings',
            icon: Icons.verified,
            onTap: () {
              setState(() {
                _selectedIndex = 3;
              });
            },
          ),
          ActionCard(
            title: 'View Reports',
            subtitle: 'Access system reports and analytics',
            icon: Icons.report,
            onTap: () {
              setState(() {
                _selectedIndex = 4;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Revenue Overview (real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
            builder: (context, orderSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final now = DateTime.now();
              final firstDayThisMonth = DateTime(now.year, now.month, 1);
              final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
              final firstDayThisYear = DateTime(now.year, 1, 1);
              final firstDayLastYear = DateTime(now.year - 1, 1, 1);
              double thisMonth = 0, lastMonth = 0, thisYear = 0, lastYear = 0;
              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final amount = (data['totalPrice'] ?? 0).toDouble();
                  if (createdAt == null) continue;
                  if (createdAt.isAfter(firstDayThisMonth)) thisMonth += amount;
                  if (createdAt.isAfter(firstDayLastMonth) && createdAt.isBefore(firstDayThisMonth)) lastMonth += amount;
                  if (createdAt.isAfter(firstDayThisYear)) thisYear += amount;
                  if (createdAt.isAfter(firstDayLastYear) && createdAt.isBefore(firstDayThisYear)) lastYear += amount;
                }
              }
              double percentMonth = lastMonth > 0 ? ((thisMonth - lastMonth) / lastMonth) * 100 : 0;
              double percentYear = lastYear > 0 ? ((thisYear - lastYear) / lastYear) * 100 : 0;
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Revenue Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAnalyticsItem('This Month', '₱${thisMonth.toStringAsFixed(0)}', '${percentMonth >= 0 ? '+' : ''}${percentMonth.toStringAsFixed(0)}%'),
                          ),
                          Expanded(
                            child: _buildAnalyticsItem('Last Month', '₱${lastMonth.toStringAsFixed(0)}', ''),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAnalyticsItem('This Year', '₱${thisYear.toStringAsFixed(0)}', '${percentYear >= 0 ? '+' : ''}${percentYear.toStringAsFixed(0)}%'),
                          ),
                          Expanded(
                            child: _buildAnalyticsItem('Last Year', '₱${lastYear.toStringAsFixed(0)}', ''),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // User Growth (real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final now = DateTime.now();
              final firstDayThisMonth = DateTime(now.year, now.month, 1);
              int newUsers = 0, activeUsers = 0;
              if (userSnap.hasData) {
                for (var doc in userSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final lastActive = (data['lastLogin'] as Timestamp?)?.toDate();
                  if (createdAt != null && createdAt.isAfter(firstDayThisMonth)) newUsers++;
                  if (lastActive != null && lastActive.isAfter(firstDayThisMonth)) activeUsers++;
                }
              }
              // For demo, percent changes are not calculated (can be added if needed)
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Growth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAnalyticsItem('New Users', newUsers.toString(), ''),
                          ),
                          Expanded(
                            child: _buildAnalyticsItem('Active Users', activeUsers.toString(), ''),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Order Counts (real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, orderSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final now = DateTime.now();
              final firstDayThisMonth = DateTime(now.year, now.month, 1);
              final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
              int totalOrders = 0, thisMonthOrders = 0, lastMonthOrders = 0;
              double totalOrderValue = 0;
              int totalOrderProducts = 0;
              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final value = (data['totalPrice'] ?? 0).toDouble();
                  final quantity = (data['quantity'] ?? 1) as int;
                  totalOrders++;
                  totalOrderValue += value;
                  totalOrderProducts += quantity;
                  if (createdAt != null) {
                    if (createdAt.isAfter(firstDayThisMonth)) thisMonthOrders++;
                    if (createdAt.isAfter(firstDayLastMonth) && createdAt.isBefore(firstDayThisMonth)) lastMonthOrders++;
                  }
                }
              }
              double avgOrderValue = totalOrders > 0 ? totalOrderValue / totalOrders : 0;
              double avgProductsPerOrder = totalOrders > 0 ? totalOrderProducts / totalOrders : 0;
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildAnalyticsItem('Total Orders', totalOrders.toString(), '')),
                          Expanded(child: _buildAnalyticsItem('This Month', thisMonthOrders.toString(), '')),
                          Expanded(child: _buildAnalyticsItem('Last Month', lastMonthOrders.toString(), '')),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildAnalyticsItem('Avg Order Value', '₱${avgOrderValue.toStringAsFixed(0)}', '')),
                          Expanded(child: _buildAnalyticsItem('Avg Products/Order', avgProductsPerOrder.toStringAsFixed(2), '')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Top Products (real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, productSnap) {
              if (productSnap.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              // Aggregate top products by total quantity sold (from orders)
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
                builder: (context, orderSnap) {
                  if (orderSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  }
                  // Map productId to total quantity sold
                  final Map<String, int> productSales = {};
                  if (orderSnap.hasData) {
                    for (var doc in orderSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final productId = data['productId'] ?? '';
                      final quantity = (data['quantity'] ?? 1) as int;
                      if (productId is String && productId.isNotEmpty) {
                        productSales[productId] = (productSales[productId] ?? 0) + quantity;
                      }
                    }
                  }
                  // Get product details
                  final products = productSnap.data?.docs ?? [];
                  final topProducts = products
                      .map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final id = doc.id;
                        return {
                          'id': id,
                          'name': data['name'] ?? '',
                          'imageUrl': data['imageUrl'] ?? '',
                          'quantitySold': productSales[id] ?? 0,
                        };
                      })
                      .where((p) => p['quantitySold'] > 0)
                      .toList();
                  topProducts.sort((a, b) => (b['quantitySold'] as int).compareTo(a['quantitySold'] as int));
                  final top5 = topProducts.take(5).toList();
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top 5 Products (by sales)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          if (top5.isEmpty)
                            const Text('No product sales yet.'),
                          for (var p in top5)
                            ListTile(
                              leading: p['imageUrl'] != null && (p['imageUrl'] as String).isNotEmpty
                                  ? Image.network(p['imageUrl'], width: 40, height: 40, fit: BoxFit.cover)
                                  : const Icon(Icons.shopping_basket, size: 40),
                              title: Text(p['name'] ?? ''),
                              trailing: Text('Sold: ${p['quantitySold']}'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          // Sales by Category (real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
            builder: (context, orderSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              // Aggregate sales by category
              final Map<String, double> categorySales = {};
              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'] ?? 'Uncategorized';
                  final amount = (data['totalPrice'] ?? 0).toDouble();
                  categorySales[category] = (categorySales[category] ?? 0) + amount;
                }
              }
              final sortedCategories = categorySales.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sales by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      if (sortedCategories.isEmpty)
                        const Text('No sales data.'),
                      if (sortedCategories.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= sortedCategories.length) return const SizedBox();
                                      return Text(sortedCategories[idx].key, style: const TextStyle(fontSize: 10));
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (int i = 0; i < sortedCategories.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: sortedCategories[i].value,
                                        color: Colors.blue,
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
            },
          ),
          const SizedBox(height: 20),
          // Top Suppliers by Sales (real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
            builder: (context, orderSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final Map<String, double> supplierSales = {};
              final Map<String, String> supplierNames = {};
              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final supplierId = data['sellerId'] ?? '';
                  final supplierName = data['supplierName'] ?? 'Unknown';
                  final amount = (data['totalPrice'] ?? 0).toDouble();
                  supplierSales[supplierId] = (supplierSales[supplierId] ?? 0) + amount;
                  supplierNames[supplierId] = supplierName;
                }
              }
              final topSuppliers = supplierSales.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final top5 = topSuppliers.take(5).toList();
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top 5 Suppliers (by sales)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      if (top5.isEmpty)
                        const Text('No supplier sales yet.'),
                      for (var entry in top5)
                        ListTile(
                          title: Text(supplierNames[entry.key] ?? 'Unknown'),
                          trailing: Text('₱${entry.value.toStringAsFixed(0)}'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Customer Lifetime Value (CLV) for Top 5 Buyers (real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
            builder: (context, orderSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final Map<String, double> buyerCLV = {};
              final Map<String, String> buyerNames = {};
              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final buyerId = data['buyerId'] ?? '';
                  final buyerName = data['buyerName'] ?? 'Unknown';
                  final amount = (data['totalPrice'] ?? 0).toDouble();
                  buyerCLV[buyerId] = (buyerCLV[buyerId] ?? 0) + amount;
                  buyerNames[buyerId] = buyerName;
                }
              }
              final topBuyers = buyerCLV.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final top5 = topBuyers.take(5).toList();
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top 5 Buyers (Customer Lifetime Value)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      if (top5.isEmpty)
                        const Text('No buyer data yet.'),
                      for (var entry in top5)
                        ListTile(
                          title: Text(buyerNames[entry.key] ?? 'Unknown'),
                          trailing: Text('₱${entry.value.toStringAsFixed(0)}'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Conversion Rate (orders/total users, real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, orderSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnap) {
                  if (orderSnap.connectionState == ConnectionState.waiting || userSnap.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final totalOrders = orderSnap.data?.docs.length ?? 0;
                  final totalUsers = userSnap.data?.docs.length ?? 0;
                  final conversionRate = totalUsers > 0 ? (totalOrders / totalUsers) * 100 : 0;
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Conversion Rate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          Text('Orders: $totalOrders'),
                          Text('Users: $totalUsers'),
                          const SizedBox(height: 8),
                          Text('Conversion Rate: ${conversionRate.toStringAsFixed(2)}%'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          // Daily/Weekly Sales Trend (last 7/30 days, real-time)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
            builder: (context, orderSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final now = DateTime.now();
              final last7Days = List.generate(7, (i) => now.subtract(Duration(days: i)));
              final last30Days = List.generate(30, (i) => now.subtract(Duration(days: i)));
              final Map<String, double> dailySales = {};
              final Map<String, double> weeklySales = {};
              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final amount = (data['totalPrice'] ?? 0).toDouble();
                  if (createdAt == null) continue;
                  final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
                  if (now.difference(createdAt).inDays < 7) {
                    dailySales[dayKey] = (dailySales[dayKey] ?? 0) + amount;
                  }
                  if (now.difference(createdAt).inDays < 30) {
                    final weekKey = 'Week ${((now.difference(createdAt).inDays) ~/ 7) + 1}';
                    weeklySales[weekKey] = (weeklySales[weekKey] ?? 0) + amount;
                  }
                }
              }
              final sortedDaily = dailySales.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              final sortedWeekly = weeklySales.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sales Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      const Text('Last 7 Days:'),
                      for (var entry in sortedDaily)
                        Text('${entry.key}: ₱${entry.value.toStringAsFixed(0)}'),
                      const SizedBox(height: 12),
                      const Text('Last 30 Days (by week):'),
                      for (var entry in sortedWeekly)
                        Text('${entry.key}: ₱${entry.value.toStringAsFixed(0)}'),
                      if (sortedDaily.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= sortedDaily.length) return const SizedBox();
                                      return Text(sortedDaily[idx].key.substring(5)); // MM-DD
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (int i = 0; i < sortedDaily.length; i++)
                                      FlSpot(i.toDouble(), sortedDaily[i].value),
                                  ],
                                  isCurved: true,
                                  color: Colors.green,
                                  barWidth: 3,
                                  dotData: FlDotData(show: false),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnalyticsItem(String label, String value, String change) {
    final isPositive = change.startsWith('+');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              color: isPositive ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              change,
              style: TextStyle(
                fontSize: 12,
                color: isPositive ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFarmLocationsTab() {
    return const AdminFarmMapPage();
  }

  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No profile data found.'));
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Profile',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 24),
              
              // Profile Image and Basic Info Section
              ModernCard(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showProfileImageOptions,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
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
                              radius: 50,
                              backgroundColor: Colors.transparent,
                              backgroundImage: _getAdminProfileImage(data),
                              child: _getAdminProfileImage(data) == null
                                  ? const Icon(
                                      Icons.admin_panel_settings,
                                      size: 50,
                                      color: Color(0xFF4CAF50),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
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
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      data['name'] ?? user.displayName ?? 'Admin User',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['email'] ?? user.email ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Role: ${data['role']?.toString().toUpperCase() ?? 'ADMIN'}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Personal Information Section
              ModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    if (data['phone'] != null && data['phone'].toString().isNotEmpty)
                      _buildAdminInfoRow(Icons.phone, 'Phone', data['phone']),
                    
                    if (data['address'] != null && data['address'].toString().isNotEmpty)
                      _buildAdminInfoRow(Icons.location_on, 'Address', data['address']),
                    
                    if (data['department'] != null && data['department'].toString().isNotEmpty)
                      _buildAdminInfoRow(Icons.business, 'Department', data['department']),
                    
                    if (data['employeeId'] != null && data['employeeId'].toString().isNotEmpty)
                      _buildAdminInfoRow(Icons.badge, 'Employee ID', data['employeeId']),
                    
                    _buildAdminInfoRow(Icons.calendar_today, 'Member Since', 
                      data['createdAt'] != null 
                        ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                        : 'N/A'),
                    
                    if (data['lastLogin'] != null)
                      _buildAdminInfoRow(Icons.access_time, 'Last Login', 
                        (data['lastLogin'] as Timestamp).toDate().toString().split(' ')[0]),
                    
                    _buildAdminInfoRow(Icons.security, 'Access Level', 
                      data['accessLevel'] ?? 'Full Access'),
                    
                    if (data['isActive'] != null)
                      _buildAdminInfoRow(
                        data['isActive'] == true ? Icons.check_circle : Icons.cancel,
                        'Account Status',
                        data['isActive'] == true ? 'Active' : 'Inactive',
                        valueColor: data['isActive'] == true ? Colors.green : Colors.red,
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // System Statistics Section
              ModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Overview',
                      style: GoogleFonts.inter(
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
        );
      },
    );
  }

  Widget _buildAdminInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF757575),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: valueColor ?? const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF757575),
          ),
        ),
      ],
    );
  }
}