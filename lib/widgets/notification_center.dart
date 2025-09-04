// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter({super.key});

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Mark all notifications as read when opening notification center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final user = _auth.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: const Color(0xFF6CA04A),
        ),
        body: const Center(
          child: Text('Please log in to view notifications'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        backgroundColor: const Color(0xFF6CA04A),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return IconButton(
                onPressed: unreadCount > 0 ? _markAllAsRead : null,
                icon: Icon(
                  Icons.done_all, 
                  color: unreadCount > 0 ? Colors.white : Colors.white.withOpacity(0.5),
                ),
                tooltip: unreadCount > 0 ? 'Mark all as read' : 'All notifications read',
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationData>>(
        stream: _notificationService.getNotificationHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications here when you receive them',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.grey[500],
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;
          
          return ListView.builder(
            padding: EdgeInsets.all(screenWidth * 0.04),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification, screenWidth);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationData notification, double screenWidth) {
    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : const Color(0xFFF8FAF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : const Color(0xFF6CA04A).withOpacity(0.3),
          width: notification.isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(screenWidth * 0.04),
        leading: _getNotificationIcon(notification.type, screenWidth, notification.isRead),
        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
            color: notification.isRead ? const Color(0xFF666666) : const Color(0xFF333333),
            fontFamily: 'Poppins',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: notification.isRead ? const Color(0xFF888888) : const Color(0xFF666666),
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatTimestamp(notification.timestamp),
                  style: TextStyle(
                    fontSize: screenWidth * 0.032,
                    color: Colors.grey[500],
                    fontFamily: 'Poppins',
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6CA04A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: screenWidth * 0.025,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
        trailing: !notification.isRead
            ? IconButton(
                onPressed: () => _markAsRead(notification.id),
                icon: Icon(
                  Icons.mark_email_read,
                  color: const Color(0xFF6CA04A),
                  size: screenWidth * 0.04,
                ),
                tooltip: 'Mark as read',
              )
            : null,
      ),
    );
  }

  Widget _getNotificationIcon(String type, double screenWidth, bool isRead) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'order_update':
        iconData = Icons.shopping_bag;
        iconColor = const Color(0xFF6CA04A);
        break;
      case 'chat':
        iconData = Icons.chat_bubble;
        iconColor = Colors.blue;
        break;
      case 'payment':
        iconData = Icons.payment;
        iconColor = Colors.green;
        break;
      case 'product_approval':
        iconData = Icons.check_circle;
        iconColor = Colors.orange;
        break;
      case 'promo':
        iconData = Icons.local_offer;
        iconColor = Colors.purple;
        break;
      case 'rating':
        iconData = Icons.star;
        iconColor = Colors.amber;
        break;
      case 'low_stock':
        iconData = Icons.warning;
        iconColor = Colors.red;
        break;
      case 'system':
        iconData = Icons.info;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.025),
      decoration: BoxDecoration(
        color: isRead ? iconColor.withOpacity(0.1) : iconColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: isRead ? null : Border.all(color: iconColor.withOpacity(0.3), width: 1),
      ),
      child: Icon(
        iconData,
        color: isRead ? iconColor.withOpacity(0.7) : iconColor,
        size: screenWidth * 0.05,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _handleNotificationTap(NotificationData notification) {
    // Mark notification as read when tapped
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }
    
    // Handle navigation based on notification type and data
    final data = notification.data;
    final screen = data['screen'] as String?;
    
    if (screen != null) {
      // Navigate to the appropriate screen
      // This would need to be implemented based on your app's navigation structure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigate to $screen'),
          backgroundColor: const Color(0xFF6CA04A),
        ),
      );
    }
  }

  void _markAsRead(String notificationId) {
    _notificationService.markAsRead(notificationId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification marked as read'),
        backgroundColor: Color(0xFF6CA04A),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _markAllAsRead() {
    _notificationService.markAllAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: Color(0xFF6CA04A),
      ),
    );
  }
}
