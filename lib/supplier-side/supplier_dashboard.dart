// ignore_for_file: deprecated_member_use, empty_catches, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:veggieconnect/supplier-side/supplier_orders_page.dart';
import '../authentication/login_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:veggieconnect/services/cloudinary_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'supplier_chat_list_page.dart';
import 'add_product_page.dart';
import 'package:veggieconnect/supplier-side/farm_map_page.dart' show SupplierLocationPage;
import 'package:veggieconnect/supplier-side/supplier_location_management_page.dart';

class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  int _selectedIndex = 0;
  String? _localProfileImagePath;

  @override
  void initState() {
    super.initState();
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
      
      if (image != null && FirebaseAuth.instance.currentUser != null) {
        // Upload picked file to Cloudinary (mobile/desktop)
        await _uploadToCloudinaryAndSave(file: File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Color(0xFFE57373),
        ),
      );
    }
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF6CA04A),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 3),
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
                    final profileImageUrl = userData?['profileImageUrl'] as String?;
                    final displayName = userData?['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Supplier';
                    final email = FirebaseAuth.instance.currentUser?.email ?? 'supplier@email.com';
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _showProfileImageOptions,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.white,
                                backgroundImage: _getSupplierProfileImage(userData),
                                child: _getSupplierProfileImage(userData) == null 
                                  ? Icon(Icons.store, size: 40, color: Color(0xFFA7C957))
                                  : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Color(0xFF6CA04A), width: 2),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Color(0xFF6CA04A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: Text(
                'Overview',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: Text(
                'Manage Products',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: Text(
                'Stock Management',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() {
                  _selectedIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: Text(
                'Orders Management',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupplierOrdersPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(
                'Profile',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() {
                  _selectedIndex = 3;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_pin),
              title: Text(
                'Supplier Location',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupplierLocationPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(
                'Manage Location',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupplierLocationManagementPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.message),
              title: Text(
                'Messages',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SupplierChatListPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
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
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildOverviewTab(cardRadius),
          _buildProductsTab(),
          _buildStockManagementTab(),
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
          Icon(Icons.home, size: 30, color: Colors.green,),
          Icon(Icons.gif_outlined, size: 30, color: Colors.green,),
          Icon(Icons.inventory_2, size: 30, color: Colors.green,),
          Icon(Icons.person_outline, size: 30, color: Colors.green,),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BorderRadius cardRadius) {
  
    
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(child: Text('Not logged in.'));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1.6, // Adjusted for better fit
            children: [
              // Total Products
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('sellerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
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
                    .where('sellerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                    .where('status', isNotEqualTo: 'completed')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _buildStatCard(cardRadius, 'Active Orders', '$count', Icons.shopping_cart, Colors.green);
                },
              ),
              // Revenue
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('sellerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
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
                  return _buildStatCard(cardRadius, 'Revenue', '₱${revenue.toStringAsFixed(2)}', Icons.attach_money, Colors.green);
                },
              ),
              // Total Orders
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('sellerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _buildStatCard(cardRadius, 'Total Orders', '$count', Icons.receipt_long, Colors.orange);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BorderRadius cardRadius, String title, String value, IconData icon, Color color) {
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
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Icon(Icons.trending_up, color: color, size: 16),
              ],
            ),
            const Spacer(),
            Text(
              title, 
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
                fontFamily: 'Poppins',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Text(
              value, 
              style: TextStyle(
                fontSize: 20,
                color: color,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                    fontFamily: 'Poppins',
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
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildProductList(),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No products yet',
              style: TextStyle(fontSize: 16),
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
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222222),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Price: ₱${product['price'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6CA04A),
                                ),
                              ),
                              Text(
                                'Stock: ${product['quantity'] ?? 0}',
                                style: TextStyle(
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
                                style: TextStyle(
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
          Text(
            'Stock Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 20),
          _buildStockOverview(),
          SizedBox(height: 20),
          _buildStockList(),
        ],
      ),
    );
  }

  Widget _buildStockOverview() {
    final user = FirebaseAuth.instance.currentUser;
    
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
                fontFamily: 'Poppins',
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        int totalProducts = snapshot.data!.docs.length;
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
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard(BorderRadius.circular(20), 'Total Products', '$totalProducts', Icons.inventory, Colors.blue),
            _buildStatCard(BorderRadius.circular(20), 'Low Stock', '$lowStockProducts', Icons.warning, Colors.orange),
            _buildStatCard(BorderRadius.circular(20), 'Out of Stock', '$outOfStockProducts', Icons.remove_shopping_cart, Colors.red),
            _buildStatCard(BorderRadius.circular(20), 'Total Value', '₱${totalValue.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
          ],
        );
      },
    );
  }

  Widget _buildStockList() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Center(child: Text('Not logged in.', style: TextStyle(fontSize: 16)));
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user.uid)
          .orderBy('quantity')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(fontSize: 14)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No products yet.', style: TextStyle(fontSize: 16)));
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222222),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '₱${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6CA04A),
                              fontFamily: 'Poppins',
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: stockColor,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
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
                          onTap: () => _updateStock(docId, quantity + 1),
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
                          onTap: () => _updateStock(docId, quantity > 0 ? quantity - 1 : 0),
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
                'Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 20),
              
              // Profile Image and Basic Info Section
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
                  children: [
                    GestureDetector(
                      onTap: _showProfileImageOptions,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                            backgroundImage: _getSupplierProfileImage(data),
                            child: _getSupplierProfileImage(data) == null
                                ? Icon(
                                    Icons.store,
                                    size: 50,
                                    color: Color(0xFF6CA04A),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Color(0xFF6CA04A),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      data['name'] ?? 'Supplier Name',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      data['email'] ?? user.email ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF6CA04A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Role: ${data['role']?.toString().toUpperCase() ?? 'SUPPLIER'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6CA04A),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // Detailed Information Section
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
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    if (data['phone'] != null && data['phone'].toString().isNotEmpty)
                      _buildInfoRow(Icons.phone, 'Phone', data['phone']),
                    
                    if (data['address'] != null && data['address'].toString().isNotEmpty)
                      _buildInfoRow(Icons.location_on, 'Address', data['address']),
                    
                    if (data['businessName'] != null && data['businessName'].toString().isNotEmpty)
                      _buildInfoRow(Icons.business, 'Business Name', data['businessName']),
                    
                    if (data['businessType'] != null && data['businessType'].toString().isNotEmpty)
                      _buildInfoRow(Icons.category, 'Business Type', data['businessType']),
                    
                    if (data['description'] != null && data['description'].toString().isNotEmpty)
                      _buildInfoRow(Icons.description, 'Description', data['description']),
                    
                    _buildInfoRow(Icons.calendar_today, 'Member Since', 
                      data['createdAt'] != null 
                        ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                        : 'N/A'),
                    
                    if (data['lastLogin'] != null)
                      _buildInfoRow(Icons.access_time, 'Last Login', 
                        (data['lastLogin'] as Timestamp).toDate().toString().split(' ')[0]),
                    
                    if (data['isVerified'] != null)
                      _buildInfoRow(
                        data['isVerified'] == true ? Icons.verified : Icons.pending,
                        'Verification Status',
                        data['isVerified'] == true ? 'Verified' : 'Pending',
                        valueColor: data['isVerified'] == true ? Colors.green : Colors.orange,
                      ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                        fontFamily: 'Poppins',
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

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Color(0xFF6CA04A),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF757575),
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Color(0xFF222222),
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Stay updated with latest alerts',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

}