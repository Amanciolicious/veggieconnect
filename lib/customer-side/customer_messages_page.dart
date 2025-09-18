// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:veggieconnect/services/chat_service.dart';
import 'package:veggieconnect/services/auth_state_service.dart';
import 'customer_chat_page.dart';
import '../widgets/lottie_loading_widget.dart';
import '../widgets/role_page_header.dart';

class CustomerMessagesPage extends StatefulWidget {
  const CustomerMessagesPage({super.key});

  @override
  State<CustomerMessagesPage> createState() => _CustomerMessagesPageState();
}

class _CustomerMessagesPageState extends State<CustomerMessagesPage> {
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
        backgroundColor: Color(0xFFF8FAF5),
        body: Center(
          child: Text(
            'Please log in to view messages',
            style: GoogleFonts.quicksand(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    final padding = screenWidth * 0.04;

    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: RolePageHeader(
        title: _isSelectionMode ? '${_selectedConversations.length} selected' : 'My Messages',
        trailing: _isSelectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete, color: Color(0xFF4CAF50), size: screenWidth * 0.05),
                    onPressed: _deleteSelectedConversations,
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Color(0xFF4CAF50), size: screenWidth * 0.05),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedConversations.clear();
                      });
                    },
                  ),
                ],
              )
            : null,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatService.streamBuyerConversations(user!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: GroceryLoadingWidget(
                size: 120,
                showText: true,
                loadingText: 'Loading conversations...',
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error loading messages',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data?.docs ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Container(
                margin: EdgeInsets.all(padding * 2),
                padding: EdgeInsets.all(padding * 2),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: screenWidth * 0.15,
                      color: Color(0xFF6CA04A),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    Text(
                      'No conversations yet',
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.06,
                        color: Color(0xFF6CA04A),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenWidth * 0.02),
                    Text(
                      'Start chatting with suppliers by visiting product details!',
                      style: GoogleFonts.quicksand(
                        fontSize: screenWidth * 0.04,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final data = conversation.data();
              final conversationId = conversation.id;
              final supplierName = data['supplierName'] ?? 'Unknown Supplier';
              final lastMessage = data['lastMessage'] ?? '';
              final lastMessageTime = data['lastMessageTime'] as Timestamp?;
              final lastSenderId = data['lastMessageSenderId'];
              final showUnread = lastSenderId != null && lastSenderId != user?.uid && (lastMessage?.toString().isNotEmpty ?? false);
              final isSelected = _selectedConversations.contains(conversationId);

              return Container(
                margin: EdgeInsets.only(bottom: padding),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF6CA04A).withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Color(0xFF6CA04A) : Color(0xFF8D9773).withOpacity(0.08),
                    width: isSelected ? 2 : 1.2,
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
                  contentPadding: EdgeInsets.all(padding),
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                    child: Text(
                      supplierName.isNotEmpty ? supplierName[0].toUpperCase() : 'S',
                      style: GoogleFonts.quicksand(
                        color: Color(0xFF6CA04A),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  title: Text(
                    supplierName,
                    style: GoogleFonts.quicksand(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text(
                        lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                        style: GoogleFonts.quicksand(
                          fontSize: screenWidth * 0.035,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lastMessageTime != null) ...[
                        SizedBox(height: 4),
                        Text(
                          _formatTimestamp(lastMessageTime),
                          style: GoogleFonts.quicksand(
                            fontSize: screenWidth * 0.03,
                            color: Color(0xFF757575),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: _isSelectionMode
                      ? Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? Color(0xFF6CA04A) : Color(0xFF757575),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (lastMessageTime != null)
                              Text(
                                _formatTimestamp(lastMessageTime),
                                style: GoogleFonts.quicksand(
                                  fontSize: screenWidth * 0.03,
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            if (showUnread)
                              Container(
                                margin: EdgeInsets.only(top: 4),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'NEW',
                                  style: GoogleFonts.quicksand(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                          ],
                        ),
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedConversations.remove(conversationId);
                        } else {
                          _selectedConversations.add(conversationId);
                        }
                        if (_selectedConversations.isEmpty) {
                          _isSelectionMode = false;
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BuyerChatPage(
                            supplierId: data['supplierId'] ?? '',
                            supplierName: supplierName,
                            buyerId: user?.uid,
                            buyerName: user?.displayName ?? 'Customer',
                          ),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedConversations.add(conversationId);
                      });
                    }
                  },
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
            child: Text('Cancel', style: GoogleFonts.quicksand(color: Color(0xFF757575), fontWeight: FontWeight.w400)),
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
          await _chatService.hideConversationForBuyer(
            conversationId: conversationId,
            buyerId: user!.uid,
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

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());

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
