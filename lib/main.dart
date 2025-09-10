// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'authentication/login_page.dart';
import 'customer-side/order_success_page.dart';
import 'customer-side/payment_test_page.dart';
import 'services/notification_service.dart';
import 'services/performance_service.dart';
import 'services/migration_service.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDQQoWOIpRRe2tVISTfPHLZZZYlEZSPAoM",
      authDomain: "vegieconnect-6bd73.firebaseapp.com",
      projectId: "vegieconnect-6bd73",
      storageBucket: "vegieconnect-6bd73.firebasestorage.app",
      messagingSenderId: "686566418513",
      appId: "1:686566418513:web:84f84c83127fe339547070",
      measurementId: "G-0WZB3ZJ4N0"
    ),
  );

  // Initialize services
  await NotificationService().initialize();
  await PerformanceService().initialize();

  // Run one-time migrations
  await MigrationService.migrateDeliveredToPickedUp();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLinks = AppLinks();
    
    // Handle deep links when app is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
    });
  }

  void _initDeepLinks() async {
    // Handle initial link if app was opened via deep link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('Initial deep link: $initialLink');
        _handleDeepLink(initialLink.toString());
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }

    // Listen for incoming links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('Incoming deep link: $uri');
        _handleDeepLink(uri.toString());
      },
      onError: (err) {
        print('Deep link error: $err');
      },
    );
  }

  void _handleDeepLink(String url) {
    print('Handling deep link: $url');
    DeepLinkService.handleDeepLink(url);
  }

  // Handle initial route for deep links

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App was resumed, check if we need to complete any pending orders
      _checkForPendingOrders();
    }
  }

  void _checkForPendingOrders() {
    // This could be enhanced to check for specific pending orders
    // For now, we'll rely on the deep link service to handle order completion
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VeggieConnect',
      debugShowCheckedModeBanner: false,
      navigatorKey: DeepLinkService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: GoogleFonts.quicksandTextTheme(),
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        ),
        home: const LoginPage(),
        routes: {
          '/order-success': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return OrderSuccessPage(
              orderId: args?['orderId'],
              status: args?['status'],
            );
          },
          '/payment-test': (context) => const PaymentTestPage(),
        },
      );
    }
  }