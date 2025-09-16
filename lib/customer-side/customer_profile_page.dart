// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:veggieconnect/customer-side/customer_order_history_page.dart';
import 'package:veggieconnect/services/cloudinary_service.dart';
import 'package:veggieconnect/services/auth_state_service.dart';
import '../widgets/lottie_loading_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _avatarUrl;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final AuthStateService _authService = AuthStateService();
  AuthUser? get user => _authService.currentUser;

  @override
  void initState() {
    super.initState();
    _loadLocalProfileImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalProfileImage() async {
    final user = _authService.currentUser;
    if (user != null) {
      // No longer using local profile images - all images are now stored on Cloudinary
      // This method is kept for compatibility but does nothing
    }
  }

  Future<void> _pickAvatar() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb) ...[
              ListTile(
                leading: Icon(Icons.photo_library, color: Color(0xFF6CA04A)),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Color(0xFF6CA04A)),
                title: Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.cloud_upload, color: Color(0xFF6CA04A)),
              title: Text('Upload via Cloudinary'),
              onTap: () async {
                Navigator.pop(context);
                if (kIsWeb) {
                  await _uploadViaCloudinaryWeb();
                } else {
                  await _uploadViaCloudinaryMobile();
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.link, color: Color(0xFF6CA04A)),
              title: Text('Enter Image URL'),
              onTap: () async {
                Navigator.pop(context);
                await _promptImageUrlInput();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadViaCloudinaryWeb() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      final bytes = await CloudinaryService.pickImageFromWeb();
      if (bytes == null) return;
      final url = await CloudinaryService.uploadBytes(bytes, fileName: 'avatar_${user.uid}.jpg');
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'avatarUrl': url});
      setState(() {
        _avatarUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded to Cloudinary successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cloudinary upload failed: $e')),
      );
    }
  }

  Future<void> _uploadViaCloudinaryMobile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );
      
      if (picked != null) {
        final file = File(picked.path);
        final url = await CloudinaryService.uploadFile(file);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'avatarUrl': url});
        
        setState(() {
          _avatarUrl = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded to Cloudinary successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cloudinary upload failed: $e')),
      );
    }
  }

  Future<void> _promptImageUrlInput() async {
    final controller = TextEditingController(text: _avatarUrl ?? '');
    final user = _authService.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Profile Image URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://example.com/image.jpg',
              labelText: 'Image URL',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6CA04A)),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Save', style: GoogleFonts.quicksand(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final url = controller.text.trim();
      final isValid = url.startsWith('http://') || url.startsWith('https://');
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid http(s) URL')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'avatarUrl': url});

      setState(() {
        _avatarUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully')),
      );
    }
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );
      
      if (picked != null) {
        final file = File(picked.path);
        final url = await CloudinaryService.uploadFile(file);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'avatarUrl': url});

        setState(() {
          _avatarUrl = url;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image uploaded to Cloudinary successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile image: $e')),
      );
    }
  }

  ImageProvider? _getProfileImage(Map<String, dynamic> data) {
    // Priority: state URL (fresh upload) > Network from Firestore
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    
    final dynamicUrl = data['avatarUrl'];
    if (dynamicUrl is String && dynamicUrl.isNotEmpty) {
      return NetworkImage(dynamicUrl);
    }
    
    return null;
  }

  Row _buildInfoRow(IconData icon, String label, String value, double screenWidth, {Color? valueColor}) {
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final user = _authService.currentUser;
    
    if (user == null) {
      return Scaffold(
        backgroundColor: Color(0xFFF8FAF5),
        body: Center(
          child: Text(
            'Please log in to view your profile.',
            style: GoogleFonts.quicksand(
              fontSize: 16,
              color: Color(0xFF757575),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Profile',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: const [],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: GroceryLoadingWidget(
                size: 120,
                showText: true,
                loadingText: 'Loading profile...'
              ),
            );
          }
          
          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          _nameController.text = userData['name'] ?? user.displayName ?? '';
          _emailController.text = userData['email'] ?? user.email ?? '';
          
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
                            onTap: _pickAvatar,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: screenWidth * 0.08,
                                  backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                                  backgroundImage: _getProfileImage(userData),
                                  child: _getProfileImage(userData) == null
                                      ? Icon(
                                          Icons.person,
                                          size: screenWidth * 0.08,
                                          color: Color(0xFF6CA04A),
                                        )
                                      : null,
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
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
                                  userData['name'] ?? user.displayName ?? 'User',
                                  style: GoogleFonts.quicksand(
                                    fontSize: screenWidth * 0.045,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  userData['email'] ?? user.email ?? '',
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
                                    'Role: ${userData['role']?.toString().toUpperCase() ?? 'CUSTOMER'}',
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
                      if (userData['phone'] != null && userData['phone'].toString().isNotEmpty)
                        _buildInfoRow(Icons.phone, 'Phone', userData['phone'], screenWidth),
                      
                      if (userData['phone'] != null && userData['phone'].toString().isNotEmpty)
                        SizedBox(height: screenWidth * 0.03),
                      
                      // Address Information
                      if (userData['address'] != null && userData['address'].toString().isNotEmpty)
                        _buildInfoRow(Icons.location_on, 'Address', userData['address'], screenWidth),
                      
                      if (userData['address'] != null && userData['address'].toString().isNotEmpty)
                        SizedBox(height: screenWidth * 0.03),
                      
                      // Member Since
                      _buildInfoRow(Icons.calendar_today, 'Member Since', 
                        userData['createdAt'] != null 
                          ? (userData['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                          : 'N/A', 
                        screenWidth),
                    ],
                  ),
                ),
                
                SizedBox(height: screenWidth * 0.06),
                
                // Order History Section
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
                        'Order History',
                        style: GoogleFonts.quicksand(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.04),
                      
                      // Order History Content
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('orders')
                            .where('buyerId', isEqualTo: user.uid)
                            .orderBy('createdAt', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, orderSnapshot) {
                          if (orderSnapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: GroceryLoadingWidget(
                                    size: 60,
                                    showText: true,
                                    loadingText: 'Loading recent orders...'
                                  ),
                                ),
                              ),
                            );
                          }
                          
                          if (!orderSnapshot.hasData || orderSnapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No orders yet',
                                      style: GoogleFonts.quicksand(
                                        fontSize: screenWidth * 0.04,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Start shopping to see your order history here',
                                      style: GoogleFonts.quicksand(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          
                          final orders = orderSnapshot.data!.docs;
                          return Column(
                            children: orders.map((orderDoc) {
                              final orderData = orderDoc.data() as Map<String, dynamic>;
                              final orderId = orderDoc.id;
                              final status = orderData['status'] ?? 'pending';
                              final unitPrice = (orderData['price'] ?? 0) as num;
                              final qty = (orderData['quantity'] ?? 1) as num;
                              final totalNum = (orderData['totalAmount'] ??
                                  orderData['paymentAmount'] ??
                                  orderData['total'] ??
                                  (unitPrice * qty)) as num;
                              final total = totalNum.toDouble();
                              final createdAt = orderData['createdAt'] as Timestamp?;
                              final dateStr = createdAt != null 
                                ? createdAt.toDate().toString().split(' ')[0]
                                : 'N/A';
                              
                              Color statusColor;
                              switch (status.toLowerCase()) {
                                case 'completed':
                                  statusColor = Colors.green;
                                  break;
                                case 'processing':
                                  statusColor = Colors.blue;
                                  break;
                                case 'cancelled':
                                  statusColor = Colors.red;
                                  break;
                                default:
                                  statusColor = Colors.orange;
                              }
                              
                              return Container(
                                margin: EdgeInsets.only(bottom: screenWidth * 0.03),
                                padding: EdgeInsets.all(screenWidth * 0.04),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF8FAF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Color(0xFF8D9773).withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.shopping_bag,
                                        color: statusColor,
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: screenWidth * 0.03),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Order #${orderId.substring(0, 8)}...',
                                            style: GoogleFonts.quicksand(
                                              fontSize: screenWidth * 0.04,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            dateStr,
                                            style: GoogleFonts.quicksand(
                                              fontSize: screenWidth * 0.035,
                                              color: Color(0xFF757575),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₱${total.toStringAsFixed(2)}',
                                          style: GoogleFonts.quicksand(
                                            fontSize: screenWidth * 0.04,
                                            color: Color(0xFF6CA04A),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: GoogleFonts.quicksand(
                                              fontSize: screenWidth * 0.03,
                                              color: statusColor,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      
                      SizedBox(height: screenWidth * 0.04),
                      
                      // View All Orders Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6CA04A),
                            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                         onPressed: () {
      Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BuyerOrderHistoryPage(),
    ),
  );
},
                          child: Text(
                            'View All Orders',
                            style: GoogleFonts.quicksand(
                              fontSize: screenWidth * 0.045,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}