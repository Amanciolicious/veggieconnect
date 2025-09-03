// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'customer_home_page.dart';
import '../admin-side/admin_dashboard.dart';
import '../supplier-side/supplier_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingPage extends StatefulWidget {
  final String? userId; // Add userId parameter
  const OnboardingPage({super.key, this.userId});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _pageIndex = 0;
  String _userRole = 'buyer'; // Default role
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (widget.userId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _userRole = userData['role'] ?? 'buyer';
            _userName = userData['name'] ?? 'User';
          });
        }
      } catch (e) {
        // Handle error silently, keep default values
      }
    }
  }

  List<_OnboardData> get _pages {
    if (_userRole == 'supplier') {
      return [
        _OnboardData(
          icon: Icons.store,
          title: 'Welcome to VegieConnect!',
          desc: 'Hello $_userName! Start selling your fresh vegetables to customers in your area.',
        ),
        _OnboardData(
          icon: Icons.add_business,
          title: 'List Your Products',
          desc: 'Add your fresh vegetables with photos, descriptions, and competitive prices.',
        ),
        _OnboardData(
          icon: Icons.analytics,
          title: 'Track Your Sales',
          desc: 'Monitor your orders, earnings, and customer feedback in real-time.',
        ),
        _OnboardData(
          icon: Icons.eco,
          title: 'Grow Your Business',
          desc: 'Connect with more customers and build your vegetable business with VegieConnect.',
        ),
      ];
    } else {
      // Customer onboarding
      return [
        _OnboardData(
          icon: Icons.eco,
          title: 'Welcome to VegieConnect!',
          desc: 'Hello $_userName! Discover fresh vegetables from local farmers and suppliers.',
        ),
        _OnboardData(
          icon: Icons.shopping_cart_checkout,
          title: 'Easy Ordering',
          desc: 'Browse, select, and order your favorite vegetables in just a few taps.',
        ),
        _OnboardData(
          icon: Icons.track_changes,
          title: 'Track Your Orders',
          desc: 'Stay updated with real-time order tracking and delivery notifications.',
        ),
        _OnboardData(
          icon: Icons.local_offer,
          title: 'Fresh & Affordable',
          desc: 'Enjoy fresh, quality vegetables at competitive prices from trusted suppliers.',
        ),
      ];
    }
  }

  Future<void> _finishOnboarding() async {
    try {
      // Mark onboarding as complete in both SharedPreferences and Firestore
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      
      // Update Firestore if userId is provided
      if (widget.userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
          'onboardingCompleted': true,
          'isNewlyRegistered': false, // Mark as no longer newly registered
        });
      }
      
      if (!mounted) return;
      
      // Navigate based on user role
      Widget destination;
      if (_userRole == 'admin') {
        destination = AdminDashboard();
      } else if (_userRole == 'supplier') {
        destination = SupplierDashboard();
      } else {
        destination = const CustomerHomePage();
      }
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      // If Firestore update fails, still proceed with SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      if (!mounted) return;
      
      // Navigate based on user role even if Firestore update fails
      Widget destination;
      if (_userRole == 'admin') {
        destination = AdminDashboard();
      } else if (_userRole == 'supplier') {
        destination = SupplierDashboard();
      } else {
        destination = const CustomerHomePage();
      }
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Row(
                children: List.generate(
                  _pages.length,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _pageIndex 
                            ? Color(0xFF6CA04A) 
                            : Color(0xFF8D9773).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() {
                    _pageIndex = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: EdgeInsets.all(screenWidth * 0.06),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: screenWidth * 0.3,
                          height: screenWidth * 0.3,
                          decoration: BoxDecoration(
                            color: Color(0xFF6CA04A).withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            page.icon,
                            size: screenWidth * 0.15,
                            color: Color(0xFF6CA04A),
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.05),
                        
                        // Title
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: screenWidth * 0.07,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: Color(0xFF2E2E2E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: screenHeight * 0.02),
                        
                        // Description
                        Text(
                          page.desc,
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontFamily: 'Poppins',
                            color: Color(0xFF757575),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.06),
              child: Row(
                children: [
                  // Skip/Back button
                  if (_pageIndex > 0)
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _controller.previousPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Text(
                          'Back',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6CA04A),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: TextButton(
                        onPressed: _finishOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  
                  SizedBox(width: screenWidth * 0.04),
                  
                  // Next/Get Started button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6CA04A),
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        if (_pageIndex < _pages.length - 1) {
                          _controller.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finishOnboarding();
                        }
                      },
                      child: Text(
                        _pageIndex < _pages.length - 1 ? 'Next' : 'Get Started',
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardData {
  final IconData icon;
  final String title;
  final String desc;
  const _OnboardData({required this.icon, required this.title, required this.desc});
}