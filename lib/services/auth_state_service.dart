// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Custom authentication state service to handle both Firebase Auth and Firestore auth
class AuthStateService extends ChangeNotifier {
  static final AuthStateService _instance = AuthStateService._internal();
  factory AuthStateService() => _instance;
  AuthStateService._internal() {
    print(' AuthStateService: Creating new instance');
  }

  String? _currentUserId;
  Map<String, dynamic>? _currentUserData;
  bool _isFirestoreAuth = false;
  bool _isAuthenticated = false;

  // Getters
  String? get currentUserId {
    print(' AuthStateService: Getting currentUserId: $_currentUserId');
    return _currentUserId;
  }
  
  Map<String, dynamic>? get currentUserData {
    print(' AuthStateService: Getting currentUserData: ${_currentUserData?['email']}');
    return _currentUserData;
  }
  
  bool get isFirestoreAuth {
    print(' AuthStateService: Getting isFirestoreAuth: $_isFirestoreAuth');
    return _isFirestoreAuth;
  }
  
  bool get isAuthenticated {
    print(' AuthStateService: Getting isAuthenticated: $_isAuthenticated');
    return _isAuthenticated;
  }

  /// Initialize auth state - call this on app startup
  Future<void> initialize() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      // User is authenticated via Firebase Auth
      await _setFirebaseAuthUser(firebaseUser);
    } else {
      // Check for stored Firestore auth session
      await _checkStoredFirestoreAuth();
    }
  }

  /// Reload user data (for email verification checks)
  Future<void> reloadUser() async {
    if (_isFirestoreAuth && _currentUserId != null) {
      // For Firestore auth, reload user data from Firestore
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId!)
            .get();
        if (doc.exists) {
          _currentUserData = doc.data();
          notifyListeners();
        }
      } catch (e) {
        print('Error reloading Firestore user: $e');
      }
    } else {
      // For Firebase auth, reload Firebase user
      await FirebaseAuth.instance.currentUser?.reload();
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await _setFirebaseAuthUser(firebaseUser);
      }
    }
  }

  /// Set Firebase Auth user
  Future<void> _setFirebaseAuthUser(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        _currentUserId = user.uid;
        _currentUserData = doc.data();
        _isFirestoreAuth = false;
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error setting Firebase auth user: $e');
    }
  }

  /// Set Firestore authenticated user
  Future<void> setFirestoreAuthUser(String userId, Map<String, dynamic> userData) async {
    print(' AuthStateService: Setting Firestore auth user - ID: $userId');
    print(' AuthStateService: User data: ${userData['email']} - Role: ${userData['role']}');
    
    _currentUserId = userId;
    _currentUserData = userData;
    _isFirestoreAuth = true;
    _isAuthenticated = true;
    
    // Store session for persistence
    await _storeFirestoreAuthSession(userId, userData);
    
    print(' AuthStateService: User set successfully - isAuthenticated: $_isAuthenticated');
    notifyListeners();
  }

  /// Check for stored Firestore auth session
  Future<void> _checkStoredFirestoreAuth() async {
    // Implementation for session persistence would go here
    // For now, we'll rely on the login flow
  }

  /// Store Firestore auth session for persistence
  Future<void> _storeFirestoreAuthSession(String userId, Map<String, dynamic> userData) async {
    // Store session data for app restarts
    // This could use SharedPreferences or secure storage
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'lastFirestoreLogin': DateTime.now(),
        'activeFirestoreSession': true,
      });
    } catch (e) {
      print('Error storing Firestore auth session: $e');
    }
  }

  /// Sign out user quickly by clearing local state first, then finishing in background
  Future<void> signOut() async {
    // 1) Clear local state immediately for instant UI response
    _currentUserId = null;
    _currentUserData = null;
    _isFirestoreAuth = false;
    _isAuthenticated = false;
    notifyListeners();

    // 2) Perform remote sign-out/session cleanup asynchronously (do not block UI)
    () async {
      try {
        // If previously FirebaseAuth user, sign out
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        print('Error during Firebase signOut: $e');
      }

      // Best-effort Firestore session cleanup if we still have an id cached somewhere
      try {
        // No-op: user id was cleared; this handles the case when called before clear
      } catch (e) {
        print('Error clearing Firestore auth session (background): $e');
      }
    }();
  }

  /// Update user data
  Future<void> updateUserData(Map<String, dynamic> newData) async {
    if (_currentUserId != null) {
      _currentUserData = {..._currentUserData ?? {}, ...newData};
      notifyListeners();
    }
  }

  /// Get current user for compatibility with existing code
  AuthUser? get currentUser {
    if (!_isAuthenticated || _currentUserId == null) return null;
    
    return AuthUser(
      uid: _currentUserId!,
      email: _currentUserData?['email'],
      userData: _currentUserData,
      isFirestoreAuth: _isFirestoreAuth,
    );
  }
}

/// Custom user class to replace Firebase User for our auth system
class AuthUser {
  final String uid;
  final String? email;
  final Map<String, dynamic>? userData;
  final bool isFirestoreAuth;

  AuthUser({
    required this.uid,
    this.email,
    this.userData,
    this.isFirestoreAuth = false,
  });

  // Add compatibility getters for Firebase User properties
  String? get displayName => userData?['name'] ?? userData?['firstName'] ?? email?.split('@').first;
  
  String get id => uid; // For compatibility with some existing code
  
  bool get emailVerified {
    if (isFirestoreAuth) {
      // For Firestore auth users, consider them verified if they exist
      return true;
    } else {
      // For Firebase auth users, we'd need to check Firebase Auth
      // This is a simplified implementation
      return userData?['emailVerified'] ?? false;
    }
  }
  
  /// Send email verification (for Firebase Auth users)
  Future<void> sendEmailVerification() async {
    if (!isFirestoreAuth) {
      // For Firebase Auth users, delegate to Firebase Auth
      final firebaseUser = FirebaseAuth.instance.currentUser;
      await firebaseUser?.sendEmailVerification();
    } else {
      // For Firestore auth users, this is not applicable
      throw UnsupportedError('Email verification not supported for Firestore auth users');
    }
  }
}
