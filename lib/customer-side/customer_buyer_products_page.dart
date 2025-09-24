// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/role_page_header.dart';
import 'package:flutter/material.dart';
import 'customer_product_details_page.dart'; // Import ProductDetailsPage
import 'customer_dashboard.dart';
import '../widgets/lottie_loading_widget.dart';
import '../services/auth_state_service.dart';

class BuyerProductsPage extends StatefulWidget {
  final String? supplierId;
  final String? searchQuery;
  final String? categoryFilter;
  final bool? promoFilter;
  final String? paymentMethodFilter;
  final bool? isFreshTodayFilter;
  final double? ratingFilter;
  final String? locationFilter;
  final bool? isBestDealFilter;
  final String? sortBy; // New parameter for sorting (e.g., 'mostSold', 'popular')
  
  const BuyerProductsPage({
    super.key, 
    this.supplierId,
    this.searchQuery,
    this.categoryFilter,
    this.promoFilter,
    this.paymentMethodFilter,
    this.isFreshTodayFilter,
    this.ratingFilter,
    this.locationFilter,
    this.isBestDealFilter,
    this.sortBy,
  });

  static Route routeForSupplier(String supplierId) =>
      MaterialPageRoute(builder: (_) => BuyerProductsPage(supplierId: supplierId));

  @override
  State<BuyerProductsPage> createState() => _BuyerProductsPageState();
}

class _BuyerProductsPageState extends State<BuyerProductsPage> with TickerProviderStateMixin {
  String _selectedCategory = 'All';
  final List<String> _categories = const [
    'All', 
    'Leafy Greens', 
    'Root Vegetables', 
    'Herbs & Spices', 
    'Legumes',
    'Grains',
  ];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final AuthStateService _authService = AuthStateService();
  AuthUser? get user => _authService.currentUser;
  final ScrollController _categoryScrollController = ScrollController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Initialize search query if provided
    if (widget.searchQuery != null) {
      _searchQuery = widget.searchQuery!;
      _searchController.text = widget.searchQuery!;
    }
    
    // Initialize category filter if provided
    if (widget.categoryFilter != null) {
      _selectedCategory = widget.categoryFilter!;
      // Ensure the category exists in our list, if not add it
      if (!_categories.contains(widget.categoryFilter!)) {
        _categories.insert(1, widget.categoryFilter!);
      }
    }
    
    // Scroll to selected category after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedCategory();
      // Start pulse animation if category is pre-selected
      if (widget.categoryFilter != null) {
        _pulseController.repeat(reverse: true);
        // Stop animation after 3 seconds
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            _pulseController.stop();
            _pulseController.reset();
          }
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Showing products in $_selectedCategory'),
              ],
            ),
            backgroundColor: Color(0xFF6CA04A),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToSelectedCategory() {
    if (widget.categoryFilter != null && _categoryScrollController.hasClients) {
      final selectedIndex = _categories.indexOf(widget.categoryFilter!);
      if (selectedIndex > 0) { // Don't scroll if it's the first item (All)
        final itemWidth = 120.0; // Approximate width of each category item
        final scrollOffset = (selectedIndex - 1) * itemWidth;
        _categoryScrollController.animateTo(
          scrollOffset,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive sizing for Infinix Smart 8 (720x1612)
    final isSmallScreen = screenWidth <= 720;
    final responsivePadding = isSmallScreen ? screenWidth * 0.03 : screenWidth * 0.04;
    final responsiveMargin = isSmallScreen ? screenWidth * 0.025 : screenWidth * 0.03;
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: RolePageHeader(
        title: _getAppBarTitle(),
        onBackTap: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const CustomerHomePage()),
            );
          }
        },
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: responsivePadding, vertical: responsiveMargin),
        child: Column(
          children: [
            // Search bar
            Container(
              margin: EdgeInsets.only(bottom: responsiveMargin),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 10 : 12, 
                vertical: isSmallScreen ? 3 : 4
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
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
              child: Row(
                children: [
                  Icon(
                    Icons.search, 
                    color: Colors.black38,
                    size: isSmallScreen ? 18 : 20,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.quicksand(
                        fontSize: isSmallScreen ? screenWidth * 0.035 : 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search products...', 
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w400,
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 16,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: Icon(
                        Icons.clear, 
                        color: Colors.black38,
                        size: isSmallScreen ? 18 : 20,
                      ),
                    ),
                ],
              ),
            ),
            
            // Show category selection indicator if coming from dashboard
            if (widget.categoryFilter != null && _selectedCategory != 'All')
              Container(
                margin: EdgeInsets.only(bottom: responsiveMargin),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16, 
                  vertical: isSmallScreen ? 10 : 12
                ),
                decoration: BoxDecoration(
                  color: Color(0xFF6CA04A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                  border: Border.all(
                    color: Color(0xFF6CA04A).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category,
                      color: Color(0xFF6CA04A),
                      size: isSmallScreen ? 18 : 20,
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Expanded(
                      child: Text(
                        'Showing products in: $_selectedCategory',
                        style: GoogleFonts.quicksand(
                          color: Color(0xFF6CA04A),
                          fontWeight: FontWeight.w400,
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = 'All';
                        });
                      },
                      child: Icon(
                        Icons.clear,
                        color: Color(0xFF6CA04A),
                        size: isSmallScreen ? 18 : 20,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Show sorting indicator
            if (widget.sortBy == 'mostSold' || widget.sortBy == 'popular')
              Container(
                margin: EdgeInsets.only(bottom: responsiveMargin),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16, 
                  vertical: isSmallScreen ? 10 : 12
                ),
                decoration: BoxDecoration(
                  color: widget.sortBy == 'mostSold' 
                      ? Color(0xFF9C27B0).withOpacity(0.1)
                      : Color(0xFFE91E63).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                  border: Border.all(
                    color: widget.sortBy == 'mostSold' 
                        ? Color(0xFF9C27B0).withOpacity(0.3)
                        : Color(0xFFE91E63).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.sortBy == 'mostSold' ? Icons.trending_up : Icons.favorite,
                      color: widget.sortBy == 'mostSold' ? Color(0xFF9C27B0) : Color(0xFFE91E63),
                      size: isSmallScreen ? 18 : 20,
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Expanded(
                      child: Text(
                        widget.sortBy == 'mostSold' 
                            ? 'Showing most sold products' 
                            : 'Showing popular products',
                        style: GoogleFonts.quicksand(
                          color: widget.sortBy == 'mostSold' ? Color(0xFF9C27B0) : Color(0xFFE91E63),
                          fontWeight: FontWeight.w400,
                          fontSize: isSmallScreen ? screenWidth * 0.035 : 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Category filter
            Container(
              height: isSmallScreen ? 45 : 50,
              margin: EdgeInsets.only(bottom: responsiveMargin),
              child: ListView.builder(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final isPreSelected = widget.categoryFilter == category && isSelected;
                        final scale = isPreSelected ? _pulseAnimation.value : 1.0;
                        
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            margin: EdgeInsets.only(right: isSmallScreen ? 10 : 12),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 20, 
                              vertical: isSmallScreen ? 10 : 12
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? Color(0xFF6CA04A) : Colors.white,
                              borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 25),
                              border: Border.all(
                                color: isSelected ? Color(0xFF6CA04A) : Color(0xFF8D9773).withOpacity(0.3),
                                width: isPreSelected ? 2.0 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isPreSelected 
                                    ? Color(0xFF6CA04A).withOpacity(0.4)
                                    : Colors.grey.withOpacity(0.1),
                                  spreadRadius: isPreSelected ? 2 : 1,
                                  blurRadius: isPreSelected ? 6 : 3,
                                  offset: Offset(0, isPreSelected ? 2 : 1),
                                ),
                              ],
                            ),
                            child: Text(
                              category,
                              style: GoogleFonts.quicksand(
                                color: isSelected ? Colors.white : Color(0xFF757575),
                                fontWeight: FontWeight.w400,
                                fontSize: isSmallScreen ? screenWidth * 0.032 : 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: responsiveMargin),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildProductQuery(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: GroceryLoadingWidget(
                        size: 120,
                        showText: true,
                        loadingText: 'Loading products...',
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: isSmallScreen ? 40 : 50, color: Colors.red),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Text(
                            'Error loading products', 
                            style: GoogleFonts.quicksand(
                              color: Colors.red, 
                              fontWeight: FontWeight.w400,
                              fontSize: isSmallScreen ? screenWidth * 0.04 : 16,
                            )
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            '${snapshot.error}', 
                            style: GoogleFonts.quicksand(
                              fontSize: isSmallScreen ? screenWidth * 0.03 : 12, 
                              fontWeight: FontWeight.w400
                            )
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No products found.', 
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w400,
                          fontSize: isSmallScreen ? screenWidth * 0.04 : 16,
                        )
                      )
                    );
                  }
                  final allProducts = snapshot.data!.docs;
                  
                  // Filter products synchronously first
                  final filteredProducts = allProducts.where((doc) {
                    final product = doc.data() as Map<String, dynamic>;
                    final name = (product['name'] ?? '').toString().trim();
                    final price = (product['price'] ?? 0);
                    final quantity = (product['quantity'] ?? 0);
                    
                    // Filter by search query
                    final matchesSearch = _searchQuery.isEmpty || 
                        name.toLowerCase().contains(_searchQuery.toLowerCase());
                    
                    // Filter by category
                    final category = product['category'] ?? '';
                    final matchesCategory = _selectedCategory == 'All' || 
                        category.toLowerCase() == _selectedCategory.toLowerCase();
                    
                    return name.isNotEmpty && 
                           price > 0 && 
                           quantity > 0 && 
                           matchesSearch && 
                           matchesCategory;
                  }).toList();
                  
                  // Use FutureBuilder to handle async supplier ban checking
                  return FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: _filterProductsBySupplierStatus(filteredProducts),
                    builder: (context, productSnapshot) {
                      if (productSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: GroceryLoadingWidget(
                            size: 100,
                            showText: true,
                            loadingText: 'Filtering products...',
                          ),
                        );
                      }
                      
                      // Show all approved products
                      final products = productSnapshot.data ?? [];
                      
                      // Products are already sorted by the query based on sortBy parameter
                      
                      if (products.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.sortBy == 'popular' ? Icons.favorite_border : Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.sortBy == 'popular' 
                                    ? 'No favorite products yet' 
                                    : 'No products found.',
                                style: GoogleFonts.quicksand(
                                  fontWeight: FontWeight.w400,
                                  fontSize: isSmallScreen ? screenWidth * 0.04 : 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (widget.sortBy == 'popular') ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the heart icon on products to add them to your favorites',
                                  style: GoogleFonts.quicksand(
                                    fontWeight: FontWeight.w400,
                                    fontSize: isSmallScreen ? screenWidth * 0.032 : 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          )
                        );
                      }
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index].data() as Map<String, dynamic>;
                          final productId = products[index].id;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailsPage(
                                    productId: productId,
                                    product: product,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                                  margin: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? screenWidth * 0.008 : screenWidth * 0.01, 
                                    horizontal: isSmallScreen ? screenWidth * 0.008 : screenWidth * 0.01
                                  ),
                                  padding: EdgeInsets.all(isSmallScreen ? screenWidth * 0.03 : screenWidth * 0.035),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
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
                                      Center(
                                        child: ProductImageWidget(
                                          imagePath: product['imageUrl'] ?? '',
                                          width: isSmallScreen ? screenWidth * 0.18 : screenWidth * 0.22,
                                          height: isSmallScreen ? screenWidth * 0.18 : screenWidth * 0.22,
                                          placeholder: Icon(
                                            Icons.shopping_basket, 
                                            size: isSmallScreen ? screenWidth * 0.11 : screenWidth * 0.13, 
                                            color: Color(0xFF6CA04A)
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? screenWidth * 0.02 : screenWidth * 0.025),
                                      Text(
                                        product['name'] ?? '', 
                                        style: GoogleFonts.quicksand(
                                          fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045, 
                                          fontWeight: FontWeight.w400
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: isSmallScreen ? screenWidth * 0.008 : screenWidth * 0.01),
                                      Text(
                                        '\u20b1${product['price']?.toStringAsFixed(2) ?? '0.00'}', 
                                        style: GoogleFonts.quicksand(
                                          fontSize: isSmallScreen ? screenWidth * 0.038 : screenWidth * 0.042, 
                                          fontWeight: FontWeight.w400
                                        )
                                      ),
                                      SizedBox(height: isSmallScreen ? screenWidth * 0.008 : screenWidth * 0.01),
                                      Text(
                                        'Stock: ${product['quantity'] ?? 0} ${product['unit'] ?? ''}', 
                                        style: GoogleFonts.quicksand(
                                          fontSize: isSmallScreen ? screenWidth * 0.03 : screenWidth * 0.032, 
                                          color: Color(0xFF757575), 
                                          fontWeight: FontWeight.w400
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          StreamBuilder<QuerySnapshot>(
                                            stream: user != null 
                                                ? FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(user!.uid)
                                                    .collection('cart')
                                                    .where('productId', isEqualTo: productId)
                                                    .snapshots()
                                                : null,
                                            builder: (context, cartSnapshot) {
                                              final isInCart = cartSnapshot.hasData && cartSnapshot.data!.docs.isNotEmpty;
                                              return isInCart
                                                  ? Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: isSmallScreen ? 6 : 8, 
                                                        vertical: isSmallScreen ? 1 : 2
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Color(0xFF6CA04A).withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        'In Basket', 
                                                        style: GoogleFonts.quicksand(
                                                          color: Color(0xFF6CA04A), 
                                                          fontSize: isSmallScreen ? screenWidth * 0.03 : screenWidth * 0.032, 
                                                          fontWeight: FontWeight.w400
                                                        )
                                                      ),
                                                    )
                                                  : const SizedBox.shrink();
                                            },
                                          ),
                                          if (((product['favoriteCount'] ?? 0) as num) > 5)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isSmallScreen ? 6 : 8, 
                                                vertical: isSmallScreen ? 1 : 2
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Popular', 
                                                style: GoogleFonts.quicksand(
                                                  color: Colors.orange,  
                                                  fontSize: isSmallScreen ? screenWidth * 0.03 : screenWidth * 0.032, 
                                                  fontWeight: FontWeight.w400
                                                )
                                              ),
                                            ),
                                        ],
                                      ),
                                      // Favorite button
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: StreamBuilder<DocumentSnapshot>(
                                          stream: user != null 
                                              ? FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user!.uid)
                                                  .snapshots()
                                              : null,
                                          builder: (context, snapshot) {
                                            bool isFavorite = false;
                                            if (snapshot.hasData && snapshot.data!.exists) {
                                              final data = snapshot.data!.data() as Map<String, dynamic>;
                                              final favs = (data['favorites'] as List?)?.cast<String>() ?? const <String>[];
                                              isFavorite = favs.contains(productId);
                                            }
                                          
                                            return GestureDetector(
                                              onTap: () => _toggleFavorite(productId),
                                              child: Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.grey.withOpacity(0.2),
                                                      spreadRadius: 1,
                                                      blurRadius: 3,
                                                      offset: Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                                  color: isFavorite ? Colors.red : Colors.grey[600],
                                                  size: 20,
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
                        },
                      );
                    },
                  );
              }),
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    if (widget.supplierId != null) {
      return 'Supplier Products';
    } else if (widget.categoryFilter != null && _selectedCategory != 'All') {
      return '$_selectedCategory Products';
    } else if (widget.sortBy == 'mostSold') {
      return 'Most Sold Products';
    } else if (widget.sortBy == 'popular') {
      return 'Popular Products';
    } else {
      return 'Browse Products';
    }
  }

  Stream<QuerySnapshot> _buildProductQuery() {
    // Handle popular products with customer-specific favorites
    if (widget.sortBy == 'popular') {
      return _buildPopularProductsQuery();
    }
    
    Query base = FirebaseFirestore.instance
        .collection('products')
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'approved'); // Only show approved products to customers
    
    // Apply promo filter if specified
    if (widget.promoFilter == true) {
      base = base.where('hasPromo', isEqualTo: true);
    }
    
    // Apply supplier filter if specified
    if (widget.supplierId != null) {
      base = base.where('sellerId', isEqualTo: widget.supplierId);
    }
    
    // Apply category filter
    if (_selectedCategory != 'All') {
      base = base.where('category', isEqualTo: _selectedCategory);
    }
    
    // Apply payment method filter if specified
    if (widget.paymentMethodFilter != null) {
      base = base.where('paymentMethods', arrayContains: widget.paymentMethodFilter);
    }
    
    // Apply isFreshToday filter if specified
    if (widget.isFreshTodayFilter == true) {
      base = base.where('isFreshToday', isEqualTo: true);
    }
    
    // Apply rating filter if specified
    if (widget.ratingFilter != null) {
      base = base.where('rating', isGreaterThanOrEqualTo: widget.ratingFilter);
    }
    
    // Apply location filter if specified
    if (widget.locationFilter != null) {
      base = base.where('location', isEqualTo: widget.locationFilter);
    }
    
    // Apply isBestDeal filter if specified
    if (widget.isBestDealFilter == true) {
      base = base.where('isBestDeal', isEqualTo: true);
    }
    
    // Apply sorting based on sortBy parameter
    if (widget.sortBy == 'mostSold') {
      // Sort by soldCount in descending order (most sold first)
      base = base.orderBy('soldCount', descending: true);
    } else {
      // Default sorting by updatedAt
      base = base.orderBy('updatedAt', descending: true);
    }
    
    return base.snapshots();
  }

  Stream<QuerySnapshot> _buildPopularProductsQuery() {
    // Get current user's favorites and fetch those products
    if (user == null) {
      // Return empty stream if no user
      return Stream<QuerySnapshot>.empty();
    }
    
    // First get the user's favorite product IDs
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .snapshots()
        .asyncMap((favoritesSnapshot) async {
          if (favoritesSnapshot.docs.isEmpty) {
            // Return empty query result
            return await FirebaseFirestore.instance
                .collection('products')
                .where('status', isEqualTo: 'nonexistent')
                .limit(0)
                .get();
          }
          
          // Get product IDs from favorites
          final productIds = favoritesSnapshot.docs.map((doc) => doc.id).toList();
          
          // Build base query with filters
          Query base = FirebaseFirestore.instance
              .collection('products')
              .where('isActive', isEqualTo: true)
              .where('status', isEqualTo: 'approved');
          
          // Apply category filter if specified
          if (_selectedCategory != 'All') {
            base = base.where('category', isEqualTo: _selectedCategory);
          }
          
          // Apply other filters
          if (widget.promoFilter == true) {
            base = base.where('hasPromo', isEqualTo: true);
          }
          
          if (widget.supplierId != null) {
            base = base.where('sellerId', isEqualTo: widget.supplierId);
          }
          
          if (widget.paymentMethodFilter != null) {
            base = base.where('paymentMethods', arrayContains: widget.paymentMethodFilter);
          }
          
          if (widget.isFreshTodayFilter == true) {
            base = base.where('isFreshToday', isEqualTo: true);
          }
          
          if (widget.ratingFilter != null) {
            base = base.where('rating', isGreaterThanOrEqualTo: widget.ratingFilter);
          }
          
          if (widget.locationFilter != null) {
            base = base.where('location', isEqualTo: widget.locationFilter);
          }
          
          if (widget.isBestDealFilter == true) {
            base = base.where('isBestDeal', isEqualTo: true);
          }
          
          // Fetch products that are in the user's favorites
          final productsQuery = await base
              .where(FieldPath.documentId, whereIn: productIds)
              .orderBy('updatedAt', descending: true)
              .get();
          
          return productsQuery;
        });
  }

  Future<List<QueryDocumentSnapshot>> _filterProductsBySupplierStatus(List<QueryDocumentSnapshot> products) async {
    final filteredProducts = <QueryDocumentSnapshot>[];
    for (final product in products) {
      final productData = product.data() as Map<String, dynamic>;
      final sellerId = productData['sellerId'] ?? '';
      if (sellerId.isNotEmpty) {
        try {
          final supplierDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(sellerId)
              .get();
          if (supplierDoc.exists) {
            final supplierData = supplierDoc.data() as Map<String, dynamic>;
            if (!(supplierData['isBanned'] ?? false)) {
              filteredProducts.add(product);
            }
          }
        } catch (e) {
          debugPrint('Error checking supplier ban status: $e');
        }
      }
    }
    return filteredProducts;
  }

  Future<void> _toggleFavorite(String productId) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add favorites.')),
      );
      return;
    }

    try {
      debugPrint('Toggling favorite for product: $productId');
      
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final favoritesColl = userRef.collection('favorites');
      final favoriteDocRef = favoritesColl.doc(productId);

      // Ensure base user doc exists and keep legacy array in sync for UI
      final userDocSnap = await userRef.get();
      final currentArray = List<String>.from((userDocSnap.data() ?? const {})['favorites'] ?? <String>[]);
      final existingFavSnap = await favoriteDocRef.get();

      if (existingFavSnap.exists) {
        // Unfavorite
        await favoriteDocRef.delete();
        if (currentArray.contains(productId)) {
          currentArray.remove(productId);
        }
        await userRef.set({
          'favorites': currentArray,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Favorite
        await favoriteDocRef.set({
          'productId': productId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!currentArray.contains(productId)) {
          currentArray.add(productId);
        }
        await userRef.set({
          'favorites': currentArray,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

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

  // Popularity/favoriteCount are maintained by backend triggers; no direct client updates
}
