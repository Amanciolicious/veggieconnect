// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:veggieconnect/services/chat_service.dart';
import 'package:intl/intl.dart';

class BuyerChatPage extends StatefulWidget {
  final String supplierId;
  final String supplierName;
  final String? buyerId;
  final String? buyerName;

  const BuyerChatPage({
    super.key, 
    required this.supplierId, 
    required this.supplierName,
    this.buyerId,
    this.buyerName,
  });

  @override
  State<BuyerChatPage> createState() => _BuyerChatPageState();
}

class _BuyerChatPageState extends State<BuyerChatPage> {
  final _controller = TextEditingController();
  String? _conversationId;
  final ChatService _chatService = ChatService();
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _localMessages = [];

  @override
  void initState() {
    super.initState();
    _initConversation();
    // Sync offline messages when page loads
    _chatService.checkAndSyncOfflineMessages();
  }

  Future<void> _initConversation() async {
    if (user == null) return;
    try {
      final convId = await _chatService.getOrCreateConversation(
        buyerId: user!.uid,
        supplierId: widget.supplierId,
        buyerName: user!.displayName,
        supplierName: widget.supplierName,
      );
      final cached = await _chatService.loadLocalMessages(convId);
      setState(() {
        _conversationId = convId;
        _localMessages = cached;
      });
    } catch (e) {
      // Handle error gracefully
      print('Error initializing conversation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        title: Text(
          'Chat with ${widget.supplierName}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        elevation: 0,
      ),
      body: _conversationId == null
          ? Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _chatService.streamMessages(_conversationId!),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isNotEmpty) {
                        final fsMessages = docs.map((d) {
                          final m = d.data();
                          return {
                            'senderId': m['senderId'],
                            'text': m['text'],
                            'timestamp': (m['timestamp'] as Timestamp?)?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
                          };
                        }).toList();
                        _chatService.setLocalMessages(conversationId: _conversationId!, messages: fsMessages);
                        return ListView.builder(
                          reverse: true,
                          padding: EdgeInsets.all(16),
                          itemCount: fsMessages.length,
                          itemBuilder: (context, index) {
                            final message = fsMessages[fsMessages.length - 1 - index];
                            final isMe = message['senderId'] == user?.uid;
                            // Build bubble with timestamp
                            return Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: BoxConstraints(maxWidth: 250),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe ? Color(0xFF6CA04A) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isMe ? null : Border.all(
                                        color: Color(0xFF8D9773).withOpacity(0.2),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: _buildBuyerBubbleContent(message, isMe),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }
                      // Fallback to local cached messages if no Firestore data
                      return ListView.builder(
                        reverse: true,
                        padding: EdgeInsets.all(16),
                        itemCount: _localMessages.length,
                        itemBuilder: (context, index) {
                          final message = _localMessages[_localMessages.length - 1 - index];
                          final isMe = message['senderId'] == user?.uid;
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                Container(
                                  constraints: BoxConstraints(maxWidth: 250),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe ? Color(0xFF6CA04A) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isMe ? null : Border.all(
                                      color: Color(0xFF8D9773).withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: _buildBuyerBubbleContent(message, isMe),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFF8D9773).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFF8D9773).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                color: Color(0xFF757575),
                                fontFamily: 'Poppins',
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Poppins',
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF6CA04A),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 24,
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

  void _sendMessage() {
    if (_conversationId == null || _controller.text.trim().isEmpty) return;
    _chatService.sendMessage(
      conversationId: _conversationId!,
      senderId: user!.uid,
      text: _controller.text,
    );
    _controller.clear();
  }

  Widget _buildBuyerBubbleContent(Map<String, dynamic> message, bool isMe) {
    DateTime? ts;
    final rawTs = message['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs);
    }
    final timeLabel = ts != null ? DateFormat('h:mm a').format(ts) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message['text'] ?? '',
          style: TextStyle(
            fontSize: 16,
            color: isMe ? Colors.white : Colors.black87,
            fontFamily: 'Poppins',
          ),
        ),
        if (timeLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: TextStyle(
              fontSize: 10,
              color: isMe ? Colors.white.withOpacity(0.85) : Colors.grey,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ],
    );
  }
}
