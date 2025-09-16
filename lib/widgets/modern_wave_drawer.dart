// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernWaveDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final String headerName;
  final String headerEmail;
  final String? headerAvatarUrl;
  final VoidCallback? onHeaderTap;
  final List<DrawerItem> items;
  final List<DrawerItem>? additionalItems;
  final List<DrawerSection>? sections;
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
    this.sections,
    this.primaryColor = const Color(0xFF4CAF50),
    this.backgroundColor = Colors.white,
  });

  @override
  State<ModernWaveDrawer> createState() => _ModernWaveDrawerState();
}

class _ModernWaveDrawerState extends State<ModernWaveDrawer>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    // Start animations
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-300 * (1 - _slideAnimation.value), 0),
          child: SizedBox(
            width: 300,
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                // Drawer background
                Container(
                  width: 300,
                  height: MediaQuery.of(context).size.height,
                  color: widget.backgroundColor,
                ),
                // Drawer content
                Column(
                  children: [
                    // Header section
                    _buildHeader(),
                    // Navigation items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        children: [
                          if (widget.sections != null) ...[
                            ...widget.sections!.asMap().entries.map((entry) {
                              final sectionIndex = entry.key;
                              final section = entry.value;
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Add divider before each section (except the first one)
                                  if (sectionIndex > 0) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Colors.grey),
                                    const SizedBox(height: 12),
                                  ],
                                  ...section.items.map((item) {
                                    final isSelected = widget.selectedIndex == item.index;
                                    
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      child: _buildDrawerItem(item, isSelected),
                                    );
                                  }),
                                ],
                              );
                            }),
                          ] else ...[
                            ...widget.items.asMap().entries.map((entry) {
                              final item = entry.value;
                              final isSelected = widget.selectedIndex == item.index;
                              
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: _buildDrawerItem(item, isSelected),
                              );
                            }),
                            if (widget.additionalItems != null) ...[
                              const SizedBox(height: 20),
                              const Divider(height: 1, color: Colors.grey),
                              const SizedBox(height: 10),
                              ...widget.additionalItems!.asMap().entries.map((entry) {
                                final item = entry.value;
                                
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: _buildDrawerItem(item, false),
                                );
                              }),
                            ],
                          ],
                        ],
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

  Widget _buildDrawerItem(DrawerItem item, bool isSelected) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
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

class DrawerSection {
  final String title;
  final List<DrawerItem> items;

  const DrawerSection({
    required this.title,
    required this.items,
  });
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
