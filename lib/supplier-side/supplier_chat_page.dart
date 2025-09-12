// ignore_for_file: avoid_print, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:veggieconnect/services/chat_service.dart';
import 'package:intl/intl.dart';
import '../widgets/lottie_loading_widget.dart';

class SupplierChatPage extends StatefulWidget {
  final String conversationId;
  final String buyerId;
  final String buyerName;
  const SupplierChatPage({super.key, required this.conversationId, required this.buyerId, required this.buyerName});

  @override
  State<SupplierChatPage> createState() => _SupplierChatPageState();
}

class _SupplierChatPageState extends State<SupplierChatPage> {
  final _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _localMessages = [];

  @override
  void initState() {
    super.initState();
    _initLocal();
    // Sync offline messages when page loads
    _chatService.checkAndSyncOfflineMessages();
  }

  Future<void> _initLocal() async {
    try {
      final cached = await _chatService.loadLocalMessages(widget.conversationId);
      setState(() => _localMessages = cached);
    } catch (e) {
      print('Error loading local messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Optimized for Infinix Smart 8 (720x1612)
    final padding = screenWidth * 0.04; // ~29px
    final messagePadding = screenWidth * 0.03; // ~22px
    final borderRadius = screenWidth * 0.03; // ~22px
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.buyerName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: const GroceryLoadingWidget(
                      size: 80,
                      showText: true,
                      loadingText: 'Loading messages...'
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty && _localMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                // Prefer Firestore messages when available to avoid duplicates
                if (messages.isNotEmpty) {
                  final fsMessages = messages.map((d) => d.data() as Map<String, dynamic>).toList();
                  // Persist to local cache (best-effort; avoid setState in builder)
                  _chatService.setLocalMessages(conversationId: widget.conversationId, messages: fsMessages);
                  return ListView.builder(
                    reverse: true,
                    padding: EdgeInsets.all(padding),
                    itemCount: fsMessages.length,
                    itemBuilder: (context, index) {
                      final message = fsMessages[fsMessages.length - 1 - index];
                      final isMe = message['senderId'] == user?.uid;
                      return _buildMessageBubble(message, isMe, messagePadding, borderRadius);
                    },
                  );
                }

                // Fallback to local messages only (offline/initial)
                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.all(padding),
                  itemCount: _localMessages.length,
                  itemBuilder: (context, index) {
                    final message = _localMessages[_localMessages.length - 1 - index];
                    final isMe = message['senderId'] == user?.uid;
                    return _buildMessageBubble(message, isMe, messagePadding, borderRadius);
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                        borderSide: BorderSide(color: Color(0xFF6CA04A)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: messagePadding,
                        vertical: messagePadding * 0.7,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: padding * 0.5),
                GestureDetector(
                  onTap: () async {
                    if (_controller.text.trim().isEmpty) return;
                    await _chatService.sendMessage(
                      conversationId: widget.conversationId,
                      senderId: user!.uid,
                      text: _controller.text,
                    );
                    _controller.clear();
                  },
                  child: Container(
                    padding: EdgeInsets.all(messagePadding * 0.7),
                    decoration: BoxDecoration(
                      color: Color(0xFF6CA04A),
                      borderRadius: BorderRadius.circular(borderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, double messagePadding, double borderRadius) {
    // Parse timestamp
    DateTime? ts;
    final rawTs = message['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs);
    }
    final timeLabel = ts != null ? DateFormat('h:mm a').format(ts) : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: messagePadding * 0.5,
          left: isMe ? messagePadding * 2 : 0,
          right: isMe ? 0 : messagePadding * 2,
        ),
        padding: EdgeInsets.all(messagePadding),
        decoration: BoxDecoration(
          color: isMe ? Color(0xFF6CA04A) : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message['text'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : Color(0xFF222222),
                fontSize: 14,
              ),
            ),
            if (timeLabel.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white.withOpacity(0.85) : Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
