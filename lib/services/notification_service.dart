import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

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

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(generalChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(orderChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _fcmToken != null) {
        await FirebaseFirestore.instance
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

      // Add to history
      _addToHistory(notificationData);

      // Show local notification
      _showLocalNotification(notificationData);

      // Broadcast to in-app notifications
      _notificationController.add(notificationData);
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    // Handle navigation based on notification type
    _handleNotificationNavigation(message.data);
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      final data = json.decode(response.payload!);
      _handleNotificationNavigation(data);
    }
  }

  // Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // This will be implemented based on your app's navigation structure
    final type = data['type'] ?? 'general';
    final targetScreen = data['screen'];
    
    debugPrint('Navigating to: $targetScreen (type: $type)');
    // Navigation logic will be implemented in the main app
  }

  // Show local notification
  Future<void> _showLocalNotification(NotificationData notification) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
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
  void sendInAppNotification({
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) {
    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      data: data ?? {},
    );

    _addToHistory(notification);
    _notificationController.add(notification);
  }

  // Send order update notification
  void sendOrderUpdateNotification({
    required String orderId,
    required String status,
    String? message,
  }) {
    sendInAppNotification(
      title: 'Order Update',
      body: message ?? 'Your order #$orderId status has been updated to $status',
      type: 'order_update',
      data: {
        'orderId': orderId,
        'status': status,
        'screen': 'order_details',
      },
    );
  }

  // Send chat message notification
  void sendChatNotification({
    required String senderName,
    required String message,
    String? chatId,
  }) {
    sendInAppNotification(
      title: 'New Message from $senderName',
      body: message,
      type: 'chat',
      data: {
        'senderName': senderName,
        'chatId': chatId,
        'screen': 'chat',
      },
    );
  }

  // Get notification history stream
  Stream<List<NotificationData>> getNotificationHistory() {
    return Stream.value(_notificationHistory);
  }

  // Dispose resources
  void dispose() {
    _notificationController.close();
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

// Notification data model
class NotificationData {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
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
    );
  }
} 