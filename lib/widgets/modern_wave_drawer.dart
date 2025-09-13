import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class ModernWaveDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final String headerName;
  final String headerEmail;
  final String? headerAvatarUrl;
  final VoidCallback? onHeaderTap;
  final List<DrawerItem> items;
  final List<DrawerItem>? additionalItems;
  final Color primaryColor;
  final Color backgroundColor;

  const ModernWaveDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.headerName,
    required this.headerEmail,
    this.headerAvatarUrl,
    this.onHeaderTap,
    required this.items,
    this.additionalItems,
    this.primaryColor = const Color(0xFF4CAF50),
    this.backgroundColor = Colors.white,
  });

  @override
  State<ModernWaveDrawer> createState() => _ModernWaveDrawerState();
}

class _ModernWaveDrawerState extends State<ModernWaveDrawer>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _waveController;
  late Animation<double> _slideAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.elasticOut,
    );

    // Start animations
    _slideController.forward();
    _waveController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-300 * (1 - _slideAnimation.value), 0),
          child: Container(
            width: 300,
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                // Wave background
                CustomPaint(
                  size: Size(300, MediaQuery.of(context).size.height),
                  painter: WaveDrawerPainter(
                    primaryColor: widget.primaryColor,
                    backgroundColor: widget.backgroundColor,
                    waveAnimation: _waveAnimation.value,
                  ),
                ),
                // Drawer content
                Container(
                  width: 280,
                  child: Column(
                    children: [
                      // Header section
                      _buildHeader(),
                      // Navigation items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          children: [
                            ...widget.items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final isSelected = widget.selectedIndex == item.index;
                              
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: _buildDrawerItem(item, isSelected, index),
                              );
                            }).toList(),
                            if (widget.additionalItems != null) ...[
                              const SizedBox(height: 20),
                              const Divider(height: 1, color: Colors.grey),
                              const SizedBox(height: 10),
                              ...widget.additionalItems!.asMap().entries.map((entry) {
                                final index = entry.key + widget.items.length;
                                final item = entry.value;
                                
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: _buildDrawerItem(item, false, index),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
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

  Widget _buildHeader() {
    return GestureDetector(
      onTap: widget.onHeaderTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.primaryColor,
              widget.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
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
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.headerAvatarUrl != null 
                      ? NetworkImage(widget.headerAvatarUrl!) 
                      : null,
                    child: widget.headerAvatarUrl == null 
                      ? const Icon(Icons.person, size: 32, color: Color(0xFF4CAF50))
                      : null,
                  ),
                ),
                if (widget.onHeaderTap != null)
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
            const SizedBox(height: 16),
            Text(
              widget.headerName,
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
              widget.headerEmail,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(DrawerItem item, bool isSelected, int animationIndex) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (animationIndex * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          widget.primaryColor.withOpacity(0.8),
                          widget.primaryColor.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: widget.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (item.onTap != null) {
                      item.onTap!();
                    } else if (item.index >= 0) {
                      widget.onItemTap(item.index);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : widget.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.icon,
                            color: isSelected
                                ? Colors.white
                                : item.isDestructive
                                    ? Colors.red
                                    : widget.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : item.isDestructive
                                      ? Colors.red
                                      : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WaveDrawerPainter extends CustomPainter {
  final Color primaryColor;
  final Color backgroundColor;
  final double waveAnimation;

  WaveDrawerPainter({
    required this.primaryColor,
    required this.backgroundColor,
    required this.waveAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // Draw main background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw wave pattern
    final wavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withOpacity(0.1),
          primaryColor.withOpacity(0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final waveHeight = 30 * waveAnimation;
    final waveLength = size.width / 2;

    path.moveTo(0, 0);
    path.lineTo(size.width - 50, 0);

    // Create wave pattern on the right edge
    for (double y = 0; y <= size.height; y += waveLength) {
      final waveOffset = math.sin((y / waveLength) * 2 * math.pi) * waveHeight;
      path.quadraticBezierTo(
        size.width - 25 + waveOffset,
        y + waveLength / 2,
        size.width - 50,
        y + waveLength,
      );
    }

    path.lineTo(size.width - 50, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, wavePaint);

    // Draw accent wave
    final accentPaint = Paint()
      ..color = primaryColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final accentPath = Path();
    accentPath.moveTo(size.width - 80, 0);

    for (double y = 0; y <= size.height; y += waveLength * 0.7) {
      final waveOffset = math.cos((y / (waveLength * 0.7)) * 2 * math.pi) * (waveHeight * 0.5);
      accentPath.quadraticBezierTo(
        size.width - 60 + waveOffset,
        y + (waveLength * 0.7) / 2,
        size.width - 80,
        y + (waveLength * 0.7),
      );
    }

    accentPath.lineTo(size.width - 80, size.height);
    accentPath.lineTo(size.width - 100, size.height);
    accentPath.lineTo(size.width - 100, 0);
    accentPath.close();

    canvas.drawPath(accentPath, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DrawerItem {
  final IconData icon;
  final String title;
  final int index;
  final VoidCallback? onTap;
  final bool isDestructive;

  const DrawerItem({
    required this.icon,
    required this.title,
    required this.index,
    this.onTap,
    this.isDestructive = false,
  });
}
