// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Removed AppLoader to avoid using Lottie in notifications loading state
import '../services/notification_service.dart';
import '../customer-side/customer_navigation_screen.dart';
import './lottie_loading_widget.dart';
import '../services/auth_state_service.dart';
import './role_page_header.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter({super.key});

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  final NotificationService _notificationService = NotificationService();
  final AuthStateService _authService = AuthStateService();
  bool _isSelectionMode = false;
  final Set<String> _selectedNotifications = <String>{};

  AuthUser? get user => _authService.currentUser;

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
    
    if (user == null) {
      return Scaffold(
        appBar: const RolePageHeader(
          title: 'Notifications',
          showBackButton: true,
        ),
        body: const Center(
          child: Text('Please log in to view notifications'),
        ),
      );
    }

    return Scaffold(
      appBar: RolePageHeader(
        title: 'Notifications',
        showBackButton: true,
        trailing: _isSelectionMode 
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cancel selection
                IconButton(
                  onPressed: _exitSelectionMode,
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel selection',
                ),
                // Delete selected
                IconButton(
                  onPressed: _selectedNotifications.isNotEmpty ? _deleteSelectedNotifications : null,
                  icon: Icon(
                    Icons.delete,
                    color: _selectedNotifications.isNotEmpty ? Colors.red : Colors.grey,
                  ),
                  tooltip: 'Delete selected notifications',
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selection mode toggle
                StreamBuilder<List<NotificationData>>(
                  stream: _notificationService.getNotificationHistory(),
                  builder: (context, snapshot) {
                    final hasNotifications = snapshot.hasData && snapshot.data!.isNotEmpty;
                    return IconButton(
                      onPressed: hasNotifications ? _enterSelectionMode : null,
                      icon: Icon(
                        Icons.checklist,
                        color: hasNotifications ? const Color(0xFF4CAF50) : Colors.grey,
                      ),
                      tooltip: hasNotifications ? 'Select notifications' : 'No notifications to select',
                    );
                  },
                ),
                // Clear all notifications button
                StreamBuilder<List<NotificationData>>(
  stream: _notificationService.getNotificationHistory(),
  builder: (context, snapshot) {
    final hasNotifications = snapshot.hasData && snapshot.data!.isNotEmpty;
    return TooltipTheme(
      data: const TooltipThemeData(
        textStyle: TextStyle(fontSize: 12), // ✅ font size 12
      ),
     child: TooltipTheme(
  data: const TooltipThemeData(
    textStyle: TextStyle(fontSize: 12), // ✅ font size 12
  ),
  child: IconButton(
    onPressed: hasNotifications ? _clearAllNotifications : null,
    icon: Icon(
      Icons.clear_all,
      color: hasNotifications ? Colors.red : Colors.grey,
    ),
    tooltip: hasNotifications
        ? 'Clear all notifications'
        : 'No notifications to clear',
  ),
),

    );
  },
),
                // Mark all as read button
                StreamBuilder<int>(
                  stream: _notificationService.getUnreadCountStream(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return IconButton(
                      onPressed: unreadCount > 0 ? _markAllAsRead : null,
                      icon: Icon(
                        Icons.done_all, 
                        color: unreadCount > 0 ? const Color(0xFF4CAF50) : Colors.grey,
                      ),
                      tooltip: unreadCount > 0 ? 'Mark all as read' : 'All notifications read',
                    );
                  },
                ),
              ],
            ),
      ),
      body: StreamBuilder<List<NotificationData>>(
        stream: _notificationService.getNotificationHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: LottieLoadingWidget(
                        assetPath: 'assets/lottie-loading-json/Grocery shopping bag pickup and delivery.json',
                        width: 100,
                        height: 100,
                        showText: false,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading notifications...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications here when you receive them',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;
          
          return Stack(
            children: [
              ListView.builder(
                padding: EdgeInsets.all(screenWidth * 0.04),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationCard(notification, screenWidth);
                },
              ),
              // Floating Action Button for Clear All
              Positioned(
                bottom: 20,
                right: 20,
                child: TooltipTheme(
                  data: const TooltipThemeData(
                    textStyle: TextStyle(fontSize: 12), // ✅ font size 12
                  ),
                  child: FloatingActionButton(
                    onPressed: _clearAllNotifications,
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    tooltip: 'Clear all notifications',
                    child: const Icon(Icons.clear_all),
                  ),
                ),
              ),
            ],
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
        leading: _isSelectionMode 
          ? Checkbox(
              value: _selectedNotifications.contains(notification.id),
              onChanged: (value) => _toggleNotificationSelection(notification.id),
              activeColor: const Color(0xFF4CAF50),
            )
          : _getNotificationIcon(notification.type, screenWidth, notification.isRead),
        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
            color: notification.isRead ? const Color(0xFF666666) : const Color(0xFF333333),
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
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleNotificationAction(value, notification),
          itemBuilder: (context) => [
            if (!notification.isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, color: Color(0xFF6CA04A)),
                    SizedBox(width: 8),
                    Text('Mark as read'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
          child: Icon(
            Icons.more_vert,
            color: Colors.grey[600],
            size: screenWidth * 0.04,
          ),
        ),
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
      case 'pickup_ready':
        iconData = Icons.notifications_active;
        iconColor = Colors.green;
        break;
      case 'chat':
        iconData = Icons.chat_bubble;
        iconColor = Colors.blue;
        break;
      case 'payment':
        iconData = Icons.text_fields; // Will be replaced with ₱ symbol
        iconColor = Colors.green;
        break;
      case 'product_approval':
        iconData = Icons.check_circle;
        iconColor = Colors.orange;
        break;
      case 'product_auto_approved':
        iconData = Icons.auto_awesome;
        iconColor = Colors.green;
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
      case 'order_cancelled':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'system':
        iconData = Icons.info;
        iconColor = Colors.blue;
        break;
      case 'product_submission':
        iconData = Icons.add_box;
        iconColor = Colors.orange;
        break;
      case 'farm_location_request':
        iconData = Icons.location_on;
        iconColor = Colors.green;
        break;
      case 'supplier_report':
        iconData = Icons.report;
        iconColor = Colors.red;
        break;
      case 'user_registration':
        iconData = Icons.person_add;
        iconColor = Colors.blue;
        break;
      case 'high_value_order':
        iconData = Icons.trending_up;
        iconColor = Colors.purple;
        break;
      case 'auto_approval':
        iconData = Icons.auto_awesome;
        iconColor = Colors.green;
        break;
      case 'payment_dispute':
        iconData = Icons.error_outline;
        iconColor = Colors.orange;
        break;
      case 'system_error':
        iconData = Icons.bug_report;
        iconColor = Colors.red;
        break;
      case 'suspicious_activity':
        iconData = Icons.security;
        iconColor = Colors.red;
        break;
      case 'multiple_reports':
        iconData = Icons.warning;
        iconColor = Colors.red;
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
      child: _buildPesoIcon(
        iconData,
        isRead ? iconColor.withOpacity(0.7) : iconColor,
        screenWidth * 0.05,
      ),
    );
  }

  Widget _buildPesoIcon(IconData icon, Color color, double size) {
    // Check if this is a money-related icon that should be replaced with ₱
    if (icon == Icons.text_fields) { // Our placeholder for money icons
      return Text(
        '₱',
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Icon(icon, color: color, size: size);
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
    final type = data['type'] as String?;
    final screen = data['screen'] as String?;
    
    debugPrint('Notification tapped: type=$type, screen=$screen, data=$data');
    
    if (type == 'pickup_ready' || screen == 'navigation') {
      final orderId = data['orderId']?.toString();
      final supplierName = data['supplierName']?.toString() ?? 'Store';
      final supplierUserId = data['supplierUserId']?.toString();
      final customerUserId = data['customerUserId']?.toString();
      
      debugPrint('Navigation parameters:');
      debugPrint('  orderId: $orderId');
      debugPrint('  supplierName: $supplierName');
      debugPrint('  supplierUserId: $supplierUserId');
      debugPrint('  customerUserId: $customerUserId');
      
      if (orderId != null) {
        try {
          Navigator.of(context).pushNamed(
            '/navigation',
            arguments: {
              'orderId': orderId,
              'supplierName': supplierName,
              'supplierUserId': supplierUserId,
              'customerUserId': customerUserId,
            },
          );
          debugPrint('Navigation to /navigation successful');
        } catch (e) {
          debugPrint('Navigation failed: $e');
          // Try alternative navigation method
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NavigationScreen(
                orderId: orderId,
                supplierName: supplierName,
                supplierUserId: supplierUserId,
                customerUserId: customerUserId,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Missing order information'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (screen != null) {
      // Handle other screen navigations
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

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Clear All Notifications',
                style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
          style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _notificationService.clearAllNotifications();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications cleared'),
                    backgroundColor: Color(0xFF6CA04A),
                  ),
                );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationAction(String action, NotificationData notification) {
    switch (action) {
      case 'mark_read':
        _markAsRead(notification.id);
        break;
      case 'clear':
        _deleteNotification(notification);
        break;
    }
  }

  void _deleteNotification(NotificationData notification) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Notification', style: GoogleFonts.quicksand(fontWeight: FontWeight.w400)),
          ],
        ),
        content: Text('Are you sure you want to delete "${notification.title}"?', 
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _notificationService.deleteNotification(notification.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification deleted'),
                    backgroundColor: Color(0xFF6CA04A),
                  ),
                );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Selection mode methods
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedNotifications.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNotifications.clear();
    });
  }

  void _toggleNotificationSelection(String notificationId) {
    setState(() {
      if (_selectedNotifications.contains(notificationId)) {
        _selectedNotifications.remove(notificationId);
      } else {
        _selectedNotifications.add(notificationId);
      }
    });
  }

  void _deleteSelectedNotifications() {
    if (_selectedNotifications.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Selected Notifications', style: GoogleFonts.quicksand(fontWeight: FontWeight.w400)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedNotifications.length} notification${_selectedNotifications.length > 1 ? 's' : ''}? This action cannot be undone.',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // Delete all selected notifications
              for (final notificationId in _selectedNotifications) {
                await _notificationService.deleteNotification(notificationId);
              }
              
              // Exit selection mode
              _exitSelectionMode();
              
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_selectedNotifications.length} notification${_selectedNotifications.length > 1 ? 's' : ''} deleted'),
                    backgroundColor: const Color(0xFF6CA04A),
                  ),
                );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
