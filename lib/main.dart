import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'authentication/login_page.dart';
import 'services/notification_service.dart';
import 'services/performance_service.dart';
import 'services/migration_service.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VeggieConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Poppins',
      ),
      home: const LoginPage(),
    );
  }
}
