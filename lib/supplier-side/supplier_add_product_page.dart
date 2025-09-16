// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_state_service.dart';
import '../services/cloudinary_service.dart';
import '../services/content_filter_service.dart';
import '../services/tax_service.dart';
import '../services/notification_service.dart';
import '../services/supplier_verification_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import '../widgets/lottie_loading_widget.dart';
import 'supplier_dashboard.dart';
import 'supplier_chat_list_page.dart';
import 'supplier_map_page.dart';

class AddProductPage extends StatefulWidget {
  final Map<String, dynamic>? product;
  final String? docId;
  const AddProductPage({super.key, this.product, this.docId});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final AuthStateService _authService = AuthStateService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(); // Add quantity controller
  int _quantity = 0;
  String _unit = 'kg';
  String _category = 'Leafy Greens';
  bool _isActive = true;
  String? _imageUrl;
  bool _isUploading = false;
  late final Ticker _ticker;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier<DateTime>(DateTime.now());
  Stream<QuerySnapshot>? _pendingProductStream;

  // Predefined categories and units
  static const List<String> _categories = [
    'Leafy Greens',
    'Root Vegetables',
    'Herbs & Spices',
    'Legumes',
    'Grains',
  ];

  static const List<String> _units = [
    'kg',
    'pieces',
    'sack',
    'bundle',
    'dozen',
    'pack',
    'box',
    'bag',
    'gram',
    'pound',
  ];

  @override
  void initState() {
    super.initState();
    // Start a light ticker that only updates a value notifier once per second
    _ticker = Ticker((_) {
      final current = DateTime.now();
      if (current.second != _nowNotifier.value.second) {
        _nowNotifier.value = current;
      }
    });
    _ticker.start();

    // Prepare stream for the latest pending product for this supplier
    final user = _authService.currentUser;
    if (user != null) {
      _pendingProductStream = FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('autoApprovalScheduledAt', descending: true)
          .limit(1)
          .snapshots();
    }
    if (widget.product != null) {
      _nameController.text = widget.product!['name'] ?? '';
      _descController.text = widget.product!['description'] ?? '';
      _priceController.text = widget.product!['price']?.toString() ?? '';
      _quantity = widget.product!['quantity'] ?? 0;
      _quantityController.text = _quantity.toString(); // Initialize quantity controller
      _unit = widget.product!['unit'] ?? 'kg';
      // Ensure the initial category exists in the predefined list to avoid DropdownButton assertion errors
      final incomingCategory = widget.product!['category']?.toString();
      if (incomingCategory != null && _categories.contains(incomingCategory)) {
        _category = incomingCategory;
      } else {
        // Fallback to first valid option
        _category = _categories.first;
      }
      _isActive = widget.product!['isActive'] ?? true;
      _imageUrl = widget.product!['imageUrl'];
    } else {
      _quantityController.text = '0'; // Set default value
    }
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    _nowNotifier.dispose();
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _quantityController.dispose(); // Dispose quantity controller
    super.dispose();
  }

  void _incrementQuantity() {
    setState(() {
      if (_quantity < 999999) { // Add reasonable maximum limit
        _quantity++;
        _quantityController.text = _quantity.toString();
      }
    });
  }

  void _decrementQuantity() {
    if (_quantity > 0) {
      setState(() {
        _quantity--;
        _quantityController.text = _quantity.toString();
      });
    }
  }

  void _updateQuantity(String value) {
    final newQuantity = int.tryParse(value) ?? 0;
    // Clamp the quantity between 0 and 999999
    final clampedQuantity = newQuantity.clamp(0, 999999);
    setState(() {
      _quantity = clampedQuantity;
      // Only update controller if it's different to avoid cursor jumping
      if (_quantityController.text != clampedQuantity.toString()) {
        _quantityController.text = clampedQuantity.toString();
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        try {
          String? cloudinaryUrl;
          
          // Show progress feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Uploading image to cloud storage...'),
                  ],
                ),
                backgroundColor: Color(0xFF4CAF50),
                duration: Duration(seconds: 10),
              ),
            );
          }

          // Upload to Cloudinary with retry logic
          int retryCount = 0;
          const maxRetries = 3;
          
          while (retryCount < maxRetries) {
            try {
              if (kIsWeb) {
                final bytes = await image.readAsBytes();
                cloudinaryUrl = await CloudinaryService.uploadProductBytes(
                  bytes, 
                  fileName: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg'
                );
              } else {
                final file = File(image.path);
                cloudinaryUrl = await CloudinaryService.uploadProductFile(file);
              }
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              if (retryCount >= maxRetries) {
                rethrow; // Re-throw after max retries
              }
              // Wait before retry
              await Future.delayed(Duration(seconds: 2));
            }
          }

          // Ensure cloudinaryUrl is not null before proceeding
          if (cloudinaryUrl != null) {
            setState(() {
              _imageUrl = cloudinaryUrl;
              _isUploading = false;
            });

            // Clear any existing snackbars and show success message
            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Image uploaded successfully to cloud storage'),
                    ],
                  ),
                  backgroundColor: Color(0xFF4CAF50),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else {
            throw Exception('Failed to get upload URL from Cloudinary');
          }
        } catch (e) {
          setState(() {
            _isUploading = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text('Failed to upload image to cloud storage')),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please check your internet connection and try again',
                      style: GoogleFonts.quicksand(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () => _pickImage(),
                ),
              ),
            );
          }
          
          // Log the actual error for debugging
          print('Cloudinary upload error: ${e.toString()}');
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to select image: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
      print('Image picker error: ${e.toString()}');
    }
  }

  Future<void> _submitProduct() async {
    if (_formKey.currentState!.validate()) {
      // Check if supplier is verified before allowing product submission
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not logged in!')),
        );
        return;
      }

      // Check verification status
      final isVerified = await SupplierVerificationService.isSupplierVerified(user.uid);
      if (!isVerified) {
        _showVerificationRequiredDialog();
        return;
      }

      setState(() => _isUploading = true);
      
      try {
        // Fetch supplier name and trust status from Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final isTrusted = userDoc.data()?['isTrusted'] == true;

        // --- Automatic Assessment Logic ---
        final prohibitedKeywords = ['illegal', 'banned', 'prohibited'];
        final name = _nameController.text.trim();
        final desc = _descController.text.trim();
        final originalPrice = double.tryParse(_priceController.text.trim()) ?? 0;
        
        // Apply tax deduction to the price
        if (!TaxService.isValidPriceForTax(originalPrice)) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Price must be at least ${TaxService.formatCurrency(TaxService.getMinimumRequiredPrice())} to cover the ₱5 listing fee.'
              ),
            ),
          );
          return;
        }
        
        final hasAllFields = name.isNotEmpty && desc.isNotEmpty && originalPrice > 0 && _quantity > 0 && _unit.isNotEmpty && _category.isNotEmpty;
        final priceValid = originalPrice > 0 && originalPrice < 10000;
        // Content filtering
        final contentFilterService = ContentFilterService();
        final contentCheck = contentFilterService.checkProductContent(
          productName: name,
          description: desc,
          supplierId: user.uid,
          category: _category,
          price: originalPrice,
        );

        final noProhibited = !prohibitedKeywords.any((word) => name.toLowerCase().contains(word) || desc.toLowerCase().contains(word));
        // For image, check if _imageUrl is present
        final hasImage = (_imageUrl ?? '').isNotEmpty;

        // Auto-approve if content is clean and supplier is trusted
        String finalStatus = 'pending';
        bool finalIsVerified = false;
        bool finalContentFlagged = contentCheck.issues.isNotEmpty;
        bool finalAutoApproved = false;
        
        if (hasAllFields && priceValid && noProhibited && hasImage && isTrusted && contentCheck.isApproved) {
          finalStatus = 'approved';
          finalIsVerified = true;
          finalAutoApproved = true;
        }

        if (widget.product != null) {
          // Show confirmation dialog before updating
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Update Product'),
              content: const Text('Are you sure you want to update this product?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Update'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        }
      
        if (widget.product != null) {
          // Updating existing product
          try {
            final currentDoc = await FirebaseFirestore.instance.collection('products').doc(widget.docId!).get();
            final currentStatus = currentDoc.data()?['status'] ?? 'pending';
            
            // Only re-evaluate approval status if product was previously rejected or pending
            // Preserve approval status for already-approved products
            if (currentStatus == 'approved') {
              // Product is already approved - preserve approval status
              finalStatus = 'approved';
              finalIsVerified = true;
              // Only flag content if there are serious issues, but keep it approved
              finalContentFlagged = contentCheck.issues.isNotEmpty;
              finalAutoApproved = currentDoc.data()?['autoApproved'] ?? false;
            } else {
              // Re-evaluate for pending/rejected products
              if (hasAllFields && priceValid && noProhibited && hasImage && isTrusted && contentCheck.isApproved) {
                finalStatus = 'approved';
                finalIsVerified = true;
                finalAutoApproved = true;
              }
            }
            
            // Since image is already uploaded to Cloudinary in _pickImage, use the URL directly
            await FirebaseFirestore.instance.collection('products').doc(widget.docId!).update({
              'sellerId': user.uid,
              'supplierName': userDoc.data()?['name'] ?? 'Unknown Supplier',
              'name': name,
              'description': desc,
              'originalPrice': originalPrice,
              'price': TaxService.calculateNetPrice(originalPrice), // Store the net price after tax deduction
              'taxAmount': TaxService.getTaxAmount(),
              'quantity': _quantity,
              'unit': _unit,
              'category': _category,
              'imageUrl': _imageUrl ?? '',
              'status': finalStatus,
              'isVerified': finalIsVerified,
              'contentFlagged': finalContentFlagged,
              'autoApproved': finalAutoApproved,
              'updatedAt': FieldValue.serverTimestamp(),
              'lastModified': FieldValue.serverTimestamp(),
              'favoriteCount': 0,
              'soldCount': 0,
              'isActive': _isActive,
              // Quick Actions fields
              'paymentMethods': ['cashOnPickup', 'online'], // Support both payment methods
              'isFreshToday': _isCreatedToday(),
              'rating': 0.0, // Initialize rating
              'totalRatings': 0,
              'location': 'nearMe', // Default location filter
              'isBestDeal': _isBestDeal(TaxService.calculateNetPrice(originalPrice)),
              'lastRatingUpdate': FieldValue.serverTimestamp(),
            });

            setState(() => _isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product updated successfully!')),
            );
            Navigator.pop(context);
          } catch (e) {
            setState(() => _isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating product: $e')),
            );
          }
        } else {
          // Creating new product
          try {
            final docRef = FirebaseFirestore.instance.collection('products').doc();
            
            await docRef.set({
              'sellerId': user.uid,
              'supplierName': userDoc.data()?['name'] ?? 'Unknown Supplier',
              'name': name,
              'description': desc,
              'originalPrice': originalPrice,
              'price': TaxService.calculateNetPrice(originalPrice), // Store the net price after tax deduction
              'taxAmount': TaxService.getTaxAmount(),
              'quantity': _quantity,
              'unit': _unit,
              'category': _category,
              'imageUrl': _imageUrl ?? '',
              'status': finalStatus,
              'isVerified': finalIsVerified,
              'contentFlagged': finalContentFlagged,
              'autoApproved': finalAutoApproved,
              'createdAt': FieldValue.serverTimestamp(),
              'lastModified': FieldValue.serverTimestamp(),
              'favoriteCount': 0,
              'soldCount': 0,
              'isActive': _isActive,
              // Quick Actions fields
              'paymentMethods': ['cashOnPickup', 'online'], // Support both payment methods
              'isFreshToday': _isCreatedToday(),
              'rating': 0.0, // Initialize rating
              'totalRatings': 0,
              'location': 'nearMe', // Default location filter
              'isBestDeal': _isBestDeal(TaxService.calculateNetPrice(originalPrice)),
              'lastRatingUpdate': FieldValue.serverTimestamp(),
            });

            // Send admin notification for new product submission
            await NotificationService().sendNewProductSubmissionNotification(
              productName: name,
              supplierName: userDoc.data()?['name'] ?? 'Unknown Supplier',
              supplierId: user.uid,
              productId: docRef.id,
            );

            setState(() => _isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(finalStatus == 'approved' ? 'Product added and approved!' : 'Product added successfully! Pending approval.')),
            );
            Navigator.pop(context);
          } catch (e) {
            setState(() => _isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error adding product: $e')),
            );
          }
        }
      } catch (e) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  bool _isCreatedToday() {
    // Check if this is a new product (not an update)
    if (widget.product == null) {
      return true; // New products are always "fresh today"
    }
    // For updates, check if the product was created today
    return false; // Updates are not considered "fresh today"
  }

  bool _isBestDeal(double price) {
    return true; // TO DO: implement logic to check if product is the best deal
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.product != null ? 'Edit Product' : 'Add Product',
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      drawer: _buildSupplierDrawer(context),
      bottomNavigationBar: CurvedNavigationBar(
        index: 1, // Products tab
        backgroundColor: const Color(0xFF4CAF50),
        color: Colors.white,
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) {
          // Navigate back to SupplierDashboard with the selected tab
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const SupplierDashboard(),
            ),
          );
        },
        items: const [
          Icon(Icons.home, size: 30, color: Colors.green),
          Icon(Icons.inventory, size: 30, color: Colors.green),
          Icon(Icons.inventory_2, size: 30, color: Colors.green),
          Icon(Icons.shopping_cart, size: 30, color: Colors.green),
          Icon(Icons.person, size: 30, color: Colors.green),
        ],
      ),
      body: _isUploading
          ? const Center(
              child: GroceryLoadingWidget(
                size: 140,
                showText: true,
                loadingText: 'Uploading product...',
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pending auto-approval countdown banner (if applicable)
                    if (_pendingProductStream != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: _pendingProductStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return SizedBox.shrink();
                          }
                          final doc = snapshot.data!.docs.first;
                          final data = doc.data() as Map<String, dynamic>;
                          final scheduled = data['autoApprovalScheduledAt'] as Timestamp?;
                          if (scheduled == null) return SizedBox.shrink();
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: ValueListenableBuilder<DateTime>(
                                    valueListenable: _nowNotifier,
                                    builder: (_, now, _) => Text(
                                      _formatCountdown(scheduled, now),
                                      style: GoogleFonts.quicksand(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    // Image Section
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildImageSection(),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Product Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF6CA04A)),
                        ),
                        prefixIcon: Icon(Icons.shopping_basket, color: Color(0xFF6CA04A)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter product name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF6CA04A)),
                        ),
                        prefixIcon: Icon(Icons.description, color: Color(0xFF6CA04A)),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Price and Quantity Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Price (₱)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Color(0xFF6CA04A)),
                                  ),
                                  prefixIcon: Icon(Icons.attach_money, color: Color(0xFF6CA04A)),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter price';
                                  }
                                  final price = double.tryParse(value);
                                  if (price == null) {
                                    return 'Please enter valid price';
                                  }
                                  if (!TaxService.isValidPriceForTax(price)) {
                                    return 'Minimum price: ${TaxService.formatCurrency(TaxService.getMinimumRequiredPrice())}';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {}); // Trigger rebuild to update tax info
                                },
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6CA04A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFF6CA04A).withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Price Breakdown:',
                                      style: GoogleFonts.quicksand(
                                        fontSize: 12,
                                        color: Color(0xFF6CA04A),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Your Price:',
                                          style: GoogleFonts.quicksand(
                                            fontSize: 11,
                                            color: Color(0xFF666666),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        Text(
                                          TaxService.formatCurrency(double.tryParse(_priceController.text) ?? 0),
                                          style: GoogleFonts.quicksand(
                                            fontSize: 11,
                                            color: Color(0xFF222222),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Listing Fee:',
                                          style: GoogleFonts.quicksand(
                                            fontSize: 11,
                                            color: Color(0xFF666666),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        Text(
                                          '-${TaxService.formatCurrency(TaxService.getTaxAmount())}',
                                          style: GoogleFonts.quicksand(
                                            fontSize: 11,
                                            color: Colors.red,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Divider(height: 8, thickness: 1, color: Color(0xFF6CA04A).withOpacity(0.3)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Final Price:',
                                          style: GoogleFonts.quicksand(
                                            fontSize: 12,
                                            color: Color(0xFF6CA04A),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        Text(
                                          TaxService.formatCurrency(
                                            TaxService.isValidPriceForTax(double.tryParse(_priceController.text) ?? 0)
                                                ? TaxService.calculateNetPrice(double.tryParse(_priceController.text) ?? 0)
                                                : 0
                                          ),
                                          style: GoogleFonts.quicksand(
                                            fontSize: 12,
                                            color: Color(0xFF6CA04A),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Quantity *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Color(0xFF6CA04A)),
                                  ),
                                  prefixIcon: Icon(Icons.inventory, color: Color(0xFF6CA04A)),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter quantity';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Please enter valid quantity';
                                  }
                                  return null;
                                },
                                onChanged: _updateQuantity,
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _decrementQuantity,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                                        foregroundColor: Color(0xFF6CA04A),
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Icon(Icons.remove, size: 20),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _incrementQuantity,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF6CA04A),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Icon(Icons.add, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Category and Unit Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _categories.contains(_category) ? _category : null,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFF6CA04A)),
                              ),
                              prefixIcon: Icon(Icons.category, color: Color(0xFF6CA04A)),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _category = value!;
                              });
                            },
                            isExpanded: true,
                            value: _category,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _units.contains(_unit) ? _unit : null,
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFF6CA04A)),
                              ),
                              prefixIcon: Icon(Icons.straighten, color: Color(0xFF6CA04A)),
                            ),
                            items: _units.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  unit,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _unit = value!;
                              });
                            },
                            isExpanded: true,
                            value: _unit,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Active Status Switch
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Product Active',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              color: Color(0xFF222222),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Switch(
                            value: _isActive,
                            onChanged: (value) {
                              setState(() {
                                _isActive = value;
                              });
                            },
                            activeThumbColor: Color(0xFF6CA04A),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6CA04A),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        widget.product != null ? 'Update Product' : 'Add Product',
                        style: GoogleFonts.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    if (_imageUrl != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(_imageUrl!) as ImageProvider,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.add_photo_alternate,
          size: 64,
          color: Color(0xFF6CA04A),
        ),
      );
    }
  }

  String _formatCountdown(Timestamp ts, DateTime now) {
    final target = ts.toDate();
    final diff = target.difference(now);
    if (diff.isNegative) return 'Auto-approval overdue';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (h > 0) return 'Auto-approval in ${h}h ${m}m ${s}s';
    if (m > 0) return 'Auto-approval in ${m}m ${s.toString().padLeft(2, '0')}s';
    return 'Auto-approval in ${s}s';
  }

  Drawer _buildSupplierDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(color: Color(0xFF6CA04A)),
            child: DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.store, color: Color(0xFF6CA04A))),
                  const SizedBox(height: 12),
                  Text(
                    'Supplier Menu',
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _drawerItem(icon: Icons.dashboard, label: 'Overview', onTap: () => _goToTab(context, 0)),
          _drawerItem(icon: Icons.inventory, label: 'Manage Products', onTap: () => _goToTab(context, 1), selected: true),
          _drawerItem(icon: Icons.inventory_2, label: 'Stock Management', onTap: () => _goToTab(context, 2)),
          _drawerItem(icon: Icons.shopping_cart, label: 'Orders Management', onTap: () => _goToTab(context, 3)),
          _drawerItem(icon: Icons.person, label: 'Profile', onTap: () => _goToTab(context, 4)),
          const Divider(),
          _drawerItem(icon: Icons.person_pin, label: 'My Location', onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierLocationPage()));
          }),
          _drawerItem(icon: Icons.message, label: 'Messages', onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierChatListPage()));
          }),
        ],
      ),
    );
  }

  Widget _drawerItem({required IconData icon, required String label, required VoidCallback onTap, bool selected = false}) {
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF4CAF50) : const Color(0xFF757575)),
      title: Text(
        label,
        style: GoogleFonts.quicksand(
          fontSize: 14,
          color: const Color(0xFF222222),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFF4CAF50).withOpacity(0.08),
      onTap: onTap,
    );
  }

  void _goToTab(BuildContext context, int index) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const SupplierDashboard(),
      ),
    );
  }

  void _showVerificationRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Color(0xFF6CA04A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user,
                  size: 40,
                  color: Color(0xFF6CA04A),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Verification Required',
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E2E2E),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'You need to complete ID verification before you can add or manage products. This helps ensure trust and safety in our marketplace.',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Color(0xFF6CA04A)),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6CA04A),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const SupplierDashboard()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6CA04A),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Get Verified',
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
            ],
          ),
        ),
      ),
    );
  }
}