// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/preboarding_model.dart';
import '../services/preboarding_service.dart';
import '../authentication/login_page.dart';

class PreboardingScreen extends StatefulWidget {
  const PreboardingScreen({super.key});

  @override
  State<PreboardingScreen> createState() => _PreboardingScreenState();
}

class _PreboardingScreenState extends State<PreboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  int _currentPage = 0;
  final List<PreboardingModel> _preboardingData = [
    PreboardingModel(
      title: "Welcome to VeggieConnect",
      description: "Your gateway to fresh, local vegetables directly from suppliers to your table.",
      gifPath: "assets/pre-boarding-gif/vege.gif",
    ),
    PreboardingModel(
      title: "Connect with Local Suppliers",
      description: "Discover nearby farms and suppliers offering the freshest produce in your area.",
      gifPath: "assets/pre-boarding-gif/vege2.gif",
    ),
    PreboardingModel(
      title: "Fresh from Farm to Market",
      description: "Experience the journey of vegetables from local farms to your local market.",
      gifPath: "assets/pre-boarding-gif/vege3.gif",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _preboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completePreboarding();
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _preboardingData.length - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completePreboarding() async {
    await PreboardingService.markPreboardingAsSeen();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const SizedBox(width: 60),
                  Expanded(
                    child: Text(
                      "VeggieConnect",
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _skipToEnd,
                    child: Text(
                      "Skip",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _preboardingData.length,
                itemBuilder: (context, index) {
                  return _buildPage(_preboardingData[index]);
                },
              ),
            ),
            
            // Page indicators and navigation
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _preboardingData.length,
                      (index) => _buildPageIndicator(index),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Next / Get Started button
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              _currentPage == _preboardingData.length - 1 ? "Get Started" : "Next",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(PreboardingModel data) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = MediaQuery.of(context).size;
            final imageSide = (size.width * 0.6).clamp(180.0, constraints.maxHeight * 0.45);
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: imageSide.toDouble(),
                      height: imageSide.toDouble(),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(160),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(160),
                        child: Image.asset(
                          data.gifPath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: Icon(
                                Icons.eco,
                                size: (imageSide * 0.4).clamp(64.0, 140.0),
                                color: const Color(0xFF2E7D32),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E7D32),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        data.description,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color(0xFF2E7D32),
                          height: 1.5,
                        ),
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
  }

  Widget _buildPageIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white30,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
