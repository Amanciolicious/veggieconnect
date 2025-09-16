// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_state_service.dart';
import 'deep_link_service.dart';
import '../customer-side/customer_navigation_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final AuthStateService _authService = AuthStateService();

  static AuthUser? get _currentUser => _authService.currentUser;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Stream controllers for in-app notifications
  final StreamController<NotificationData> _notificationController = StreamController<NotificationData>.broadcast();
  Stream<NotificationData> get notificationStream => _notificationController.stream;

  // Notification settings
  bool _isInitialized = false;
  String? _fcmToken;
  final List<NotificationData> _notificationHistory = [];

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permissions
      await _requestPermissions();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();
      
      // Load notification history
      await _loadNotificationHistory();
      
      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
        'general',
        'General Notifications',
        description: 'General app notifications',
        importance: Importance.high,
      );

      const AndroidNotificationChannel orderChannel = AndroidNotificationChannel(
        'orders',
        'Order Updates',
        description: 'Order status updates and notifications',
        importance: Importance.high,
      );

      const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
        'chat',
        'Chat Messages',
        description: 'In-app chat messages',
        importance: Importance.high,
      );

      const AndroidNotificationChannel arrivalChannel = AndroidNotificationChannel(
        'arrival',
        'Arrival Notifications',
        description: 'Notifications when you arrive at pickup locations',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(generalChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(orderChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(arrivalChannel);
    } catch (e) {
      debugPrint('Error creating notification channels: $e');
    }
  }

  // Initialize Firebase messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Save token to Firestore
      await _saveFcmToken();

      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken();
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages (Web requires a service worker at /firebase-messaging-sw.js)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    } catch (e) {
      debugPrint('Error initializing Firebase messaging: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFcmToken() async {
    try {
      final user = _currentUser;
      if (user != null && _fcmToken != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': _fcmToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint('Message also contained a notification: ${message.notification}');
      
      // Create notification data
      final notificationData = NotificationData(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        type: message.data['type'] ?? 'general',
        timestamp: DateTime.now(),
        data: message.data,
      );

      // Add to history (local)
      _addToHistory(notificationData);

      // Persist to Firestore per-recipient for cross-device visibility
      try {
        final recipientId = message.data['recipientId'] as String?;
        if (recipientId != null && recipientId.isNotEmpty) {
          _firestore
              .collection('users')
              .doc(recipientId)
              .collection('notifications')
              .doc(notificationData.id)
              .set({
            'title': notificationData.title,
            'body': notificationData.body,
            'type': notificationData.type,
            'timestamp': FieldValue.serverTimestamp(),
            'data': notificationData.data,
            'isRead': false,
          });
        }
      } catch (e) {
        debugPrint('Failed to persist notification: $e');
      }

      // Show local notification
      _showLocalNotification(notificationData);

      // Broadcast to in-app notifications
      _notificationController.add(notificationData);
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    // Add a small delay to ensure app is fully loaded
    Future.delayed(Duration(milliseconds: 500), () {
      _handleNotificationNavigation(message.data);
    });
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      final data = json.decode(response.payload!);
      // Add a small delay to ensure app is fully loaded
      Future.delayed(Duration(milliseconds: 500), () {
        _handleNotificationNavigation(data);
      });
    }
  }

  // Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Navigate to NavigationScreen when order pickup ready
    final type = data['type'] ?? 'general';
    final targetScreen = data['screen'];
    debugPrint('Navigating to: $targetScreen (type: $type)');
    debugPrint('Notification data: $data');
    
    try {
      if (type == 'pickup_ready' || targetScreen == 'navigation') {
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
          final context = DeepLinkService.navigatorKey.currentContext;
          if (context != null) {
            debugPrint('Navigator context found, proceeding with navigation...');
            try {
              Navigator.of(context, rootNavigator: true).pushNamed(
                '/navigation',
                arguments: {
                  'orderId': orderId,
                  'supplierName': supplierName,
                  'supplierUserId': supplierUserId,
                  'customerUserId': customerUserId,
                },
              );
              debugPrint('Navigation command sent successfully');
            } catch (navError) {
              debugPrint('Navigation failed: $navError');
              // Try alternative navigation method
              _tryAlternativeNavigation(context, orderId, supplierName, supplierUserId, customerUserId);
            }
          } else {
            debugPrint('ERROR: Navigator context is null');
            // Try to get context after a delay
            Future.delayed(Duration(seconds: 1), () {
              final delayedContext = DeepLinkService.navigatorKey.currentContext;
              if (delayedContext != null) {
                debugPrint('Delayed context found, retrying navigation...');
                _tryAlternativeNavigation(delayedContext, orderId, supplierName, supplierUserId, customerUserId);
              }
            });
          }
        } else {
          debugPrint('ERROR: orderId is null');
        }
      } else {
        debugPrint('Notification type or screen does not match navigation criteria');
      }
    } catch (e) {
      debugPrint('Navigation error on notification tap: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  // Alternative navigation method
  void _tryAlternativeNavigation(BuildContext context, String orderId, String supplierName, String? supplierUserId, String? customerUserId) {
    try {
      debugPrint('Trying alternative navigation method...');
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
      debugPrint('Alternative navigation successful');
    } catch (e) {
      debugPrint('Alternative navigation also failed: $e');
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(NotificationData notification) async {
    try {
      final isArrivalConfirmation = notification.type == 'arrival_confirmation';
      
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        isArrivalConfirmation ? 'arrival' : 'general',
        isArrivalConfirmation ? 'Arrival Notifications' : 'General Notifications',
        channelDescription: isArrivalConfirmation 
            ? 'Notifications when you arrive at pickup locations'
            : 'General app notifications',
        importance: isArrivalConfirmation ? Importance.max : Importance.high,
        priority: isArrivalConfirmation ? Priority.max : Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        color: isArrivalConfirmation ? const Color(0xFF4CAF50) : null,
        ledColor: isArrivalConfirmation ? const Color(0xFF4CAF50) : null,
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      final DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: isArrivalConfirmation ? 'arrival_sound.caf' : 'default',
        badgeNumber: 1,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: json.encode(notification.data),
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  // Add notification to history
  void _addToHistory(NotificationData notification) {
    _notificationHistory.insert(0, notification);
    
    // Keep only last 50 notifications
    if (_notificationHistory.length > 50) {
      _notificationHistory.removeRange(50, _notificationHistory.length);
    }
    
    _saveNotificationHistory();
  }

  // Save notification history to SharedPreferences
  Future<void> _saveNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _notificationHistory
          .map((notification) => notification.toJson())
          .toList();
      await prefs.setString('notification_history', json.encode(historyJson));
    } catch (e) {
      debugPrint('Error saving notification history: $e');
    }
  }

  // Load notification history from SharedPreferences
  Future<void> _loadNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('notification_history');
      if (historyString != null) {
        final historyJson = json.decode(historyString) as List;
        _notificationHistory.clear();
        _notificationHistory.addAll(
          historyJson.map((json) => NotificationData.fromJson(json)),
        );
      }
    } catch (e) {
      debugPrint('Error loading notification history: $e');
    }
  }

  // Get notification history
  List<NotificationData> get notificationHistory => List.unmodifiable(_notificationHistory);

  // Clear notification history
  Future<void> clearNotificationHistory() async {
    _notificationHistory.clear();
    await _saveNotificationHistory();
  }

  // Send in-app notification
  Future<void> sendInAppNotification({
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
    String? targetUserId,
    String? targetUserRole,
  }) async {
    // Check if notification should be filtered by user role
    if (targetUserId != null) {
      final currentUser = _currentUser;
      if (currentUser == null) return;
      
      // Only send to the specific user if targetUserId matches current user
      if (currentUser.uid != targetUserId) return;
      
      // If targetUserRole is specified, check if current user has that role
      if (targetUserRole != null) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data();
            final userRole = userData?['role']?.toString().toLowerCase();
            if (userRole != targetUserRole.toLowerCase()) {
              return; // Don't send notification if user doesn't have the required role
            }
          } else {
            return; // User document doesn't exist
          }
        } catch (e) {
          debugPrint('Error checking user role for notification: $e');
          return;
        }
      }
    }

    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      data: data ?? {},
    );

    // Save to Firestore for persistence
    try {
      final currentUser = _currentUser;
      if (currentUser != null) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .doc(notification.id)
            .set({
          'title': notification.title,
          'body': notification.body,
          'type': notification.type,
          'timestamp': FieldValue.serverTimestamp(),
          'data': notification.data,
          'isRead': false,
        });
      }
    } catch (e) {
      debugPrint('Error saving in-app notification to Firestore: $e');
    }

    _addToHistory(notification);
    _notificationController.add(notification);
  }

  // Send order update notification
  void sendOrderUpdateNotification({
    required String orderId,
    required String status,
    String? message,
    String? recipientId,
    String? recipientName,
    String? recipientRole,
  }) {
    String title = 'Order Update';
    String body = message ?? 'Your order #$orderId status has been updated to $status';
    
    // Customize message based on status
    switch (status.toLowerCase()) {
      case 'pending':
        title = 'New Order Received';
        body = 'You have a new order #$orderId';
        break;
      case 'processing':
        title = 'Order Processing';
        body = 'Your order #$orderId is being prepared';
        break;
      case 'picked_up':
      case 'completed':
        title = 'Order Completed';
        body = 'Your order #$orderId has been completed';
        break;
      case 'cancelled':
        title = 'Order Cancelled';
        body = 'Your order #$orderId has been cancelled';
        break;
    }

    sendInAppNotification(
      title: title,
      body: body,
      type: 'order_update',
      targetUserId: recipientId,
      targetUserRole: recipientRole,
      data: {
        'orderId': orderId,
        'status': status,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'screen': 'order_details',
      },
    );
  }

  // Send chat message notification
  void sendChatNotification({
    required String senderName,
    required String message,
    String? chatId,
    String? recipientId,
  }) {
    sendInAppNotification(
      title: 'New Message from $senderName',
      body: message,
      type: 'chat',
      targetUserId: recipientId,
      data: {
        'senderName': senderName,
        'chatId': chatId,
        'recipientId': recipientId,
        'screen': 'chat',
      },
    );
  }

  // Send payment notification
  void sendPaymentNotification({
    required String orderId,
    required String status,
    required String amount,
    String? recipientId,
    String? recipientRole,
  }) {
    String title = 'Payment Update';
    String body = 'Payment for order #$orderId: $status';
    
    switch (status.toLowerCase()) {
      case 'paid':
        title = 'Payment Received';
        body = 'Payment of ₱$amount for order #$orderId has been received';
        break;
      case 'failed':
        title = 'Payment Failed';
        body = 'Payment for order #$orderId failed. Please try again';
        break;
      case 'pending':
        title = 'Payment Pending';
        body = 'Payment of ₱$amount for order #$orderId is pending';
        break;
    }

    sendInAppNotification(
      title: title,
      body: body,
      type: 'payment',
      targetUserId: recipientId,
      targetUserRole: recipientRole,
      data: {
        'orderId': orderId,
        'status': status,
        'amount': amount,
        'recipientId': recipientId,
        'screen': 'order_details',
      },
    );
  }

  // Send product approval notification
  void sendProductApprovalNotification({
    required String productName,
    required String status,
    required String supplierId,
    String? reason,
  }) {
    String title = 'Product $status';
    String body = 'Your product "$productName" has been $status';
    
    if (status.toLowerCase() == 'rejected' && reason != null) {
      body += ': $reason';
    }

    sendInAppNotification(
      title: title,
      body: body,
      type: 'product_approval',
      targetUserId: supplierId,
      targetUserRole: 'supplier',
      data: {
        'productName': productName,
        'status': status,
        'supplierId': supplierId,
        'reason': reason,
        'screen': 'products',
      },
    );
  }

  // Send promo notification
  void sendPromoNotification({
    required String title,
    required String body,
    required String recipientId,
    String? promoType,
  }) {
    sendInAppNotification(
      title: title,
      body: body,
      type: 'promo',
      data: {
        'recipientId': recipientId,
        'promoType': promoType,
        'screen': 'profile',
      },
    );
  }

  // Send admin notification
  void sendAdminNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) {
    sendInAppNotification(
      title: title,
      body: body,
      type: 'admin_$type',
      data: data ?? {},
    );
  }

  // Send low stock notification
  void sendLowStockNotification({
    required String productName,
    required int currentStock,
    required String supplierId,
  }) {
    sendInAppNotification(
      title: 'Low Stock Alert',
      body: 'Your product "$productName" is running low ($currentStock left)',
      type: 'low_stock',
      targetUserId: supplierId,
      targetUserRole: 'supplier',
      data: {
        'productName': productName,
        'currentStock': currentStock,
        'supplierId': supplierId,
        'screen': 'products',
      },
    );
  }

  // Send rating notification
  void sendRatingNotification({
    required String orderId,
    required String customerName,
    required int rating,
    String? supplierId,
  }) {
    sendInAppNotification(
      title: 'New Rating Received',
      body: 'You received a $rating-star rating from $customerName for order #$orderId',
      type: 'rating',
      targetUserId: supplierId,
      targetUserRole: 'supplier',
      data: {
        'orderId': orderId,
        'customerName': customerName,
        'rating': rating,
        'supplierId': supplierId,
        'screen': 'orders',
      },
    );
  }

  // Send system notification
  void sendSystemNotification({
    required String title,
    required String body,
    String? recipientId,
    Map<String, dynamic>? data,
  }) {
    sendInAppNotification(
      title: title,
      body: body,
      type: 'system',
      data: {
        'recipientId': recipientId,
        ...?data,
      },
    );
  }

  // Send FCM notification to specific user
  Future<void> sendFCMNotification({
    required String recipientId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
    bool showBadge = true,
  }) async {
    try {
      // Persist to Firestore so it appears in in-app notification lists (drives badges)
      try {
        final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
        await _firestore
            .collection('users')
            .doc(recipientId)
            .collection('notifications')
            .doc(notificationId)
            .set({
          'title': title,
          'body': body,
          'type': type,
          'timestamp': FieldValue.serverTimestamp(),
          'data': {
            ...?data,
            'recipientId': recipientId,
          },
          'isRead': false,
          'showBadge': showBadge,
          'priority': type == 'arrival_confirmation' ? 'high' : 'normal',
        });
      } catch (e) {
        debugPrint('Error saving notification to Firestore: $e');
      }

      // Try to send the push notification via FCM if token exists
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(recipientId)
            .get();
        if (!userDoc.exists) {
          debugPrint('User $recipientId not found');
          return;
        }
        final userData = userDoc.data() as Map<String, dynamic>;
        final fcmToken = userData['fcmToken'] as String?;
        if (fcmToken == null) {
          debugPrint('No FCM token found for user $recipientId');
          return;
        }
        await _sendFCMToToken(
          token: fcmToken,
          title: title,
          body: body,
          type: type,
          data: data,
        );
        debugPrint('FCM notification sent to $recipientId');
      } catch (e) {
        debugPrint('Skipping FCM send due to error: $e');
      }
    } catch (e) {
      debugPrint('Error sending FCM notification: $e');
    }
  }

  // Send FCM notification to multiple users
  Future<void> sendFCMNotificationToMultiple({
    required List<String> recipientIds,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    for (final recipientId in recipientIds) {
      await sendFCMNotification(
        recipientId: recipientId,
        title: title,
        body: body,
        type: type,
        data: data,
      );
    }
  }

  // Send FCM notification to all users of a specific role
  Future<void> sendFCMNotificationToRole({
    required String role,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    try {
      print('🔍 Searching for users with role: $role');
      
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      
      print('🔍 Found ${usersSnapshot.docs.length} users with role: $role');
      
      if (usersSnapshot.docs.isEmpty) {
        print('⚠️ No users found with role: $role. Checking all users...');
        
        // Debug: Check all users and their roles
        final allUsersSnapshot = await _firestore.collection('users').get();
        print('📊 Total users in database: ${allUsersSnapshot.docs.length}');
        
        for (final doc in allUsersSnapshot.docs.take(5)) { // Show first 5 users
          final userData = doc.data();
          print('👤 User ${doc.id}: role = "${userData['role']}", email = "${userData['email']}"');
        }
        
        return;
      }
      
      final recipientIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      print('📤 Sending notifications to admin users: $recipientIds');
      
      await sendFCMNotificationToMultiple(
        recipientIds: recipientIds,
        title: title,
        body: body,
        type: type,
        data: data,
      );
      
      print('✅ Admin notifications sent successfully');
    } catch (e) {
      print('❌ Error sending FCM notification to role $role: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Internal method to send FCM to specific token using V1 API
  Future<void> _sendFCMToToken({
    required String token,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    try {
      // For FCM V1 API, we need to use a different approach
      // Since client-side FCM V1 requires OAuth2 tokens, we'll use a hybrid approach
      
      // Option 1: Use Firebase Functions (Recommended for production)
      await _sendViaFirebaseFunction(token, title, body, type, data);
      
      // Option 2: Fallback to local notifications for immediate testing
      await _showLocalNotificationForTesting(title, body, type, data);
      
    } catch (e) {
      debugPrint('Error sending FCM notification: $e');
      // Fallback: Show local notification for testing
      await _showLocalNotificationForTesting(title, body, type, data);
    }
  }

  // Send notification via Firebase Function (recommended approach)
  Future<void> _sendViaFirebaseFunction(
    String token,
    String title,
    String body,
    String type,
    Map<String, dynamic>? data,
  ) async {
    try {
      // For now, we'll use local notifications as the primary method
      // In production, you would implement Firebase Functions here
      debugPrint('FCM V1 notification would be sent to $token: $title - $body');
      debugPrint('Using local notification as fallback for immediate testing');
      
      // Show local notification for immediate testing
      await _showLocalNotificationForTesting(title, body, type, data);
      
    } catch (e) {
      debugPrint('Error in Firebase Function approach: $e');
      await _showLocalNotificationForTesting(title, body, type, data);
    }
  }

  // Fallback method to show local notification for testing
  Future<void> _showLocalNotificationForTesting(
    String title,
    String body,
    String type,
    Map<String, dynamic>? data,
  ) async {
    try {
      final notificationData = NotificationData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        type: type,
        timestamp: DateTime.now(),
        data: data ?? {},
      );

      await _showLocalNotification(notificationData);
      debugPrint('Local notification shown as fallback: $title - $body');
    } catch (e) {
      debugPrint('Error showing local notification fallback: $e');
    }
  }

  // Get notification history stream from Firestore
  Stream<List<NotificationData>> getNotificationHistory() {
    final user = _currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationData(
          id: doc.id,
          title: data['title'] ?? 'Notification',
          body: data['body'] ?? '',
          type: data['type'] ?? 'general',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          data: Map<String, dynamic>.from(data['data'] ?? {}),
          isRead: data['isRead'] ?? false,
        );
      }).toList();
    });
  }

  // Get unread notifications count from Firestore
  Stream<int> getUnreadCountStream() {
    final user = _currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      
      debugPrint('Notification $notificationId marked as read');
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      debugPrint('All notifications marked as read');
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Mark notification as read when viewed
  void markAsReadWhenViewed(String notificationId) {
    markAsRead(notificationId);
  }

  // Dispose resources
  void dispose() {
    _notificationController.close();
  }

  // Send new product submission notification to all admins
  Future<void> sendNewProductSubmissionNotification({
    required String productName,
    required String supplierName,
    required String supplierId,
    required String productId,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'New Product Submission',
      body: '$supplierName submitted "$productName" for approval',
      type: 'product_submission',
      data: {
        'productName': productName,
        'supplierName': supplierName,
        'supplierId': supplierId,
        'productId': productId,
        'screen': 'verify_listings',
      },
    );
  }

  // Send farm location request notification to all admins
  Future<void> sendFarmLocationRequestNotification({
    required String farmName,
    required String supplierName,
    required String supplierId,
    required String requestId,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'New Farm Location Request',
      body: '$supplierName requested to add "$farmName" to the map',
      type: 'farm_location_request',
      data: {
        'farmName': farmName,
        'supplierName': supplierName,
        'supplierId': supplierId,
        'requestId': requestId,
        'screen': 'farm_requests',
      },
    );
  }

  // Send supplier report notification to all admins
  Future<void> sendSupplierReportNotification({
    required String supplierName,
    required String customerName,
    required String reason,
    required String supplierId,
    required String reportId,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'Supplier Reported',
      body: '$customerName reported $supplierName for: $reason',
      type: 'supplier_report',
      data: {
        'supplierName': supplierName,
        'customerName': customerName,
        'reason': reason,
        'supplierId': supplierId,
        'reportId': reportId,
        'screen': 'manage_accounts',
      },
    );
  }

  // Send new user registration notification to all admins
  Future<void> sendNewUserRegistrationNotification({
    required String userName,
    required String userEmail,
    required String userRole,
    required String userId,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'New User Registration',
      body: '$userName ($userRole) registered with email: $userEmail',
      type: 'user_registration',
      data: {
        'userName': userName,
        'userEmail': userEmail,
        'userRole': userRole,
        'userId': userId,
        'screen': 'manage_accounts',
      },
    );
  }

  // Send high-value order notification to all admins
  Future<void> sendHighValueOrderNotification({
    required String customerName,
    required String supplierName,
    required double orderAmount,
    required String orderId,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'High-Value Order Alert',
      body: '$customerName placed a ₱${orderAmount.toStringAsFixed(2)} order with $supplierName',
      type: 'high_value_order',
      data: {
        'customerName': customerName,
        'supplierName': supplierName,
        'orderAmount': orderAmount,
        'orderId': orderId,
        'screen': 'analytics',
      },
    );
  }

  // Send auto-approval notification to all admins
  Future<void> sendAutoApprovalNotification({
    required String itemType,
    required String itemName,
    required String supplierName,
    required String itemId,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'Auto-Approval Triggered',
      body: '$itemType "$itemName" by $supplierName was automatically approved',
      type: 'auto_approval',
      data: {
        'itemType': itemType,
        'itemName': itemName,
        'supplierName': supplierName,
        'itemId': itemId,
        'screen': itemType == 'Product' ? 'verify_listings' : 'farm_requests',
      },
    );
  }

  // Send payment dispute notification to all admins
  Future<void> sendPaymentDisputeNotification({
    required String customerName,
    required String orderId,
    required String disputeReason,
    required double orderAmount,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'Payment Dispute',
      body: '$customerName disputed ₱${orderAmount.toStringAsFixed(2)} payment for order #$orderId',
      type: 'payment_dispute',
      data: {
        'customerName': customerName,
        'orderId': orderId,
        'disputeReason': disputeReason,
        'orderAmount': orderAmount,
        'screen': 'analytics',
      },
    );
  }

  // Send system error notification to all admins
  Future<void> sendSystemErrorNotification({
    required String errorType,
    required String errorMessage,
    String? userId,
    String? orderId,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'System Error Alert',
      body: '$errorType: $errorMessage',
      type: 'system_error',
      data: {
        'errorType': errorType,
        'errorMessage': errorMessage,
        'userId': userId,
        'orderId': orderId,
        'screen': 'dashboard',
      },
    );
  }

  // Send suspicious activity notification to all admins
  Future<void> sendSuspiciousActivityNotification({
    required String activityType,
    required String description,
    required String userId,
    String? userName,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'Suspicious Activity Detected',
      body: '$activityType: $description',
      type: 'suspicious_activity',
      data: {
        'activityType': activityType,
        'description': description,
        'userId': userId,
        'userName': userName,
        'screen': 'manage_accounts',
      },
    );
  }

  // Send multiple reports threshold notification to all admins
  Future<void> sendMultipleReportsNotification({
    required String supplierName,
    required String supplierId,
    required int reportCount,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'Multiple Reports Alert',
      body: '$supplierName has received $reportCount reports and may need review',
      type: 'multiple_reports',
      data: {
        'supplierName': supplierName,
        'supplierId': supplierId,
        'reportCount': reportCount,
        'screen': 'manage_accounts',
      },
    );
  }

  // Verification-related notifications
  Future<void> sendVerificationRequestNotification({
    required String supplierName,
    required String supplierId,
    required String verificationId,
  }) async {
    await sendFCMNotificationToRole(
      role: 'admin',
      title: 'New Verification Request',
      body: '$supplierName submitted ID verification documents for review',
      type: 'verification_request',
      data: {
        'supplierName': supplierName,
        'supplierId': supplierId,
        'verificationId': verificationId,
        'screen': 'verification_requests',
      },
    );
  }

  Future<void> sendVerificationApprovedNotification({
    required String supplierId,
    required String supplierName,
  }) async {
    await sendFCMNotification(
      recipientId: supplierId,
      title: 'Verification Approved',
      body: 'Congratulations! Your ID verification has been approved. You can now access all supplier features.',
      type: 'verification_approved',
      data: {
        'supplierName': supplierName,
        'screen': 'profile',
      },
    );
  }

  Future<void> sendVerificationRejectedNotification({
    required String supplierId,
    required String supplierName,
    required String reason,
  }) async {
    await sendFCMNotification(
      recipientId: supplierId,
      title: 'Verification Rejected',
      body: 'Your ID verification was rejected: $reason. Please submit new documents.',
      type: 'verification_rejected',
      data: {
        'supplierName': supplierName,
        'reason': reason,
        'screen': 'profile',
      },
    );
  }

  Future<void> sendVerificationAutoApprovedNotification({
    required String supplierId,
    required String supplierName,
  }) async {
    await sendFCMNotification(
      recipientId: supplierId,
      title: 'Verification Auto-Approved',
      body: 'Your ID verification has been automatically approved after 24 hours. Welcome to VeggieConnect!',
      type: 'verification_auto_approved',
      data: {
        'supplierName': supplierName,
        'screen': 'profile',
      },
    );
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();
  
  // Handle the background message
  if (message.notification != null) {
    debugPrint('Background notification: ${message.notification!.title} - ${message.notification!.body}');
    
    // Save notification to Firestore for persistence
    try {
      final recipientId = message.data['recipientId'] as String?;
      if (recipientId != null && recipientId.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(recipientId)
            .collection('notifications')
            .doc(message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString())
            .set({
          'title': message.notification!.title ?? 'New Notification',
          'body': message.notification!.body ?? '',
          'type': message.data['type'] ?? 'general',
          'timestamp': FieldValue.serverTimestamp(),
          'data': message.data,
          'isRead': false,
        });
      }
    } catch (e) {
      debugPrint('Error saving background notification: $e');
    }
  }
}

// Notification data model
class NotificationData {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final bool isRead;

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    required this.data,
    this.isRead = false,
  });

  NotificationData copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    DateTime? timestamp,
    Map<String, dynamic>? data,
    bool? isRead,
  }) {
    return NotificationData(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'isRead': isRead,
    };
  }

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      data: Map<String, dynamic>.from(json['data']),
      isRead: json['isRead'] ?? false,
    );
  }
} 