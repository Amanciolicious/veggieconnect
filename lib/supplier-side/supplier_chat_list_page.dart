// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:veggieconnect/services/chat_service.dart';
import 'package:veggieconnect/services/auth_state_service.dart';
import 'supplier_chat_page.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../widgets/lottie_loading_widget.dart';
import 'supplier_dashboard.dart';
import 'supplier_map_page.dart' show SupplierLocationPage;
import '../widgets/modern_wave_drawer.dart';
import '../authentication/login_page.dart';
import 'supplier_orders_page.dart';

class SupplierChatListPage extends StatefulWidget {
  const SupplierChatListPage({super.key});

  @override
  State<SupplierChatListPage> createState() => _SupplierChatListPageState();
}

class _SupplierChatListPageState extends State<SupplierChatListPage> {
  final ChatService _chatService = ChatService();
  final AuthStateService _authService = AuthStateService();
  final Set<String> _selectedConversations = {};
  bool _isSelectionMode = false;

  AuthUser? get user => _authService.currentUser;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Not logged in.')),
      );
    }

    // Optimized for Infinix Smart 8 (720x1612)
    final padding = screenWidth * 0.04; // ~29px

    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedConversations.length} selected' : 'Messages',
          style: GoogleFonts.quicksand(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF6CA04A),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white, size: screenWidth * 0.05),
              onPressed: _deleteSelectedConversations,
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: screenWidth * 0.05),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedConversations.clear();
                });
              },
            ),
          ],
        ],
      ),
      drawer: StreamBuilder<DocumentSnapshot>(
        stream: user != null 
          ? FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots()
          : null,
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final displayName = userData?['name'] ?? user?.displayName ?? 'Supplier';
          final email = user?.email ?? 'supplier@email.com';
          final profileImageUrl = userData?['avatarUrl'] as String?;
          
          return ModernWaveDrawer(
            selectedIndex: -1, // No main tab selected since we're on messages page
            onItemTap: (index) {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupplierDashboard(),
                ),
              );
            },
            headerName: displayName,
            headerEmail: email,
            headerAvatarUrl: profileImageUrl,
            items: [
              DrawerItem(icon: Icons.dashboard, title: 'Overview', index: 0),
              DrawerItem(icon: Icons.inventory, title: 'Manage Products', index: 1),
              DrawerItem(icon: Icons.inventory_2, title: 'Stock Management', index: 2),
              DrawerItem(icon: Icons.person, title: 'Profile', index: 3),
            ],
            additionalItems: [
              DrawerItem(
                icon: Icons.shopping_cart,
                title: 'Orders Management',
                index: -1,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SupplierOrdersPage()),
                  );
                },
              ),
              DrawerItem(
                icon: Icons.person_pin,
                title: 'My Location',
                index: -1,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SupplierLocationPage()),
                  );
                },
              ),
              DrawerItem(
                icon: Icons.message,
                title: 'Messages',
                index: -1,
                onTap: () {
                  Navigator.pop(context);
                  // Already on messages page, no navigation needed
                },
              ),
              DrawerItem(
                icon: Icons.logout,
                title: 'Logout',
                index: -1,
                isDestructive: true,
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
          );
        },
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: 0, // default to home tab when coming from messages page
        backgroundColor: Color(0xFF4CAF50),
        color: Colors.white,
        height: 60,
        animationDuration: Duration(milliseconds: 300),
        onTap: (index) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const SupplierDashboard(),
            ),
          );
        },
        items: [
          Icon(Icons.home, size: 30, color: Colors.green),
          Icon(Icons.inventory, size: 30, color: Colors.green),
          Icon(Icons.inventory_2, size: 30, color: Colors.green),
          Icon(Icons.shopping_cart, size: 30, color: Colors.green),
          Icon(Icons.person, size: 30, color: Colors.green),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getConversations(user!.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.quicksand(
                  color: Colors.red,
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: GroceryLoadingWidget(
                size: 120,
                showText: true,
                loadingText: 'Loading conversations...',
              ),
            );
          }

          final conversations = snapshot.data!.docs;

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start chatting with your customers!',
                    style: GoogleFonts.quicksand(
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index].data() as Map<String, dynamic>;
              final conversationId = conversations[index].id;
              final isSelected = _selectedConversations.contains(conversationId);
              
              return GestureDetector(
                onTap: () {
                  if (_isSelectionMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedConversations.remove(conversationId);
                        if (_selectedConversations.isEmpty) {
                          _isSelectionMode = false;
                        }
                      } else {
                        _selectedConversations.add(conversationId);
                      }
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SupplierChatPage(
                          conversationId: conversationId,
                          buyerId: conversation['buyerId'] ?? '',
                          buyerName: conversation['buyerName'] ?? 'Unknown',
                        ),
                      ),
                    );
                  }
                },
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedConversations.add(conversationId);
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF6CA04A).withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Color(0xFF6CA04A) : Colors.grey.withOpacity(0.2),
                      width: isSelected ? 2 : 1,
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
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFF6CA04A),
                      child: Text(
                        (conversation['buyerName'] ?? 'U')[0].toUpperCase(),
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    title: Text(
                      conversation['buyerName'] ?? 'Unknown',
                      style: GoogleFonts.quicksand(
                        color: Color(0xFF222222),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      conversation['lastMessage'] ?? 'No messages yet',
                      style: GoogleFonts.quicksand(
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (conversation['lastMessageTime'] != null)
                          Text(
                            _formatTime(conversation['lastMessageTime']),
                            style: GoogleFonts.quicksand(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        if (conversation['lastMessageSenderId'] != null && conversation['lastMessageSenderId'] != user!.uid && (conversation['lastMessage']?.toString().isNotEmpty ?? false))
                          Container(
                            margin: EdgeInsets.only(top: 4),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteSelectedConversations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete Conversations', style: GoogleFonts.quicksand(fontWeight: FontWeight.w400)),
        content: Text(
          'Are you sure you want to delete ${_selectedConversations.length} conversation(s)?',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.quicksand(color: Colors.grey, fontWeight: FontWeight.w400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.quicksand(color: Colors.red, fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final conversationId in _selectedConversations) {
          await _chatService.hideConversationForSupplier(
            conversationId: conversationId,
            supplierId: user!.uid,
          );
        }
        setState(() {
          _isSelectionMode = false;
          _selectedConversations.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversations deleted'),
            backgroundColor: Color(0xFF6CA04A),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is String) {
      time = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
