// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:veggieconnect/services/chat_service.dart';
import 'supplier_chat_page.dart';

class SupplierChatListPage extends StatefulWidget {
  const SupplierChatListPage({super.key});

  @override
  State<SupplierChatListPage> createState() => _SupplierChatListPageState();
}

class _SupplierChatListPageState extends State<SupplierChatListPage> {
  final ChatService _chatService = ChatService();
  final Set<String> _selectedConversations = {};
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    // Optimized for Infinix Smart 8 (720x1612)
    final padding = screenWidth * 0.04; // ~29px

    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          _isSelectionMode ? '${_selectedConversations.length} selected' : 'Messages',
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.w400,
          ),
        ),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getConversations(user.uid),
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
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
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
                        if (conversation['lastMessageSenderId'] != null && conversation['lastMessageSenderId'] != user.uid && (conversation['lastMessage']?.toString().isNotEmpty ?? false))
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

  void _toggleSelection(String conversationId) {
    setState(() {
      if (_selectedConversations.contains(conversationId)) {
        _selectedConversations.remove(conversationId);
        if (_selectedConversations.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedConversations.add(conversationId);
      }
    });
  }

  Future<void> _deleteSelectedConversations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
            supplierId: user.uid,
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

  Future<void> _deleteConversation(String conversationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Conversation', style: GoogleFonts.quicksand(fontWeight: FontWeight.w400)),
        content: Text('Are you sure you want to delete this conversation? This action cannot be undone.', style: GoogleFonts.quicksand(fontWeight: FontWeight.w400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.quicksand(color: Colors.grey, fontWeight: FontWeight.w400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.quicksand(fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChatService().deleteConversation(conversationId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversation deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete conversation: $e')),
        );
      }
    }
  }

  Future<void> _hideConversation(String conversationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await ChatService().hideConversation(conversationId, user.uid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversation hidden')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to hide conversation: $e')),
      );
    }
  }
}
