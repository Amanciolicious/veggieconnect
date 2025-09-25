// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../customer-side/customer_dashboard.dart';
import '../customer-side/customer_onboarding_page.dart';
import '../admin-side/admin_dashboard.dart';
import '../supplier-side/supplier_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/ban_service.dart';
import '../models/ban_model.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../services/auth_state_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // First attempt Firebase Auth login
      UserCredential? credential;
      bool useFirestoreAuth = false;
      Map<String, dynamic>? firestoreAuthResult;
      
      try {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } on FirebaseAuthException catch (_) {
        // If Firebase Auth fails, try Firestore username/email + password
        firestoreAuthResult = await _tryFirestoreAuthentication(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (firestoreAuthResult['success']) {
          useFirestoreAuth = true;
        } else {
          rethrow;
        }
      }
      
      String userId;
      Map<String, dynamic>? userData;
      
      if (useFirestoreAuth) {
        // Handle Firestore-authenticated user
        userId = firestoreAuthResult!['userId'];
        userData = firestoreAuthResult['userData'];
        
        print(' Login: Setting Firestore auth user - ID: $userId, Email: ${userData?['email']}');
        
        // Set the user in our custom auth state service
        await AuthStateService().setFirestoreAuthUser(userId, userData!);
        
        print(' Login: AuthStateService state after setting user:');
        print('  - isAuthenticated: ${AuthStateService().isAuthenticated}');
        print('  - currentUserId: ${AuthStateService().currentUserId}');
        print('  - currentUser: ${AuthStateService().currentUser?.uid}');
      } else {
        // Handle Firebase-authenticated user
        userId = credential!.user!.uid;
        
        // Check Firestore for verification and role
        final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        userData = doc.data();
        
        if (userData == null || userData['verified'] != true) {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        // Check for password reset flags
        final forceReauth = userData['forceReauth'] ?? false;
        final oldAuthDisabled = userData['oldAuthDisabled'] ?? false;
        
        if (forceReauth || oldAuthDisabled) {
          // User needs to use new password, sign them out
          await FirebaseAuth.instance.signOut();
          setState(() {
            _isLoading = false;
          });
          _showErrorDialog('Authentication Required', 
            'Please use your new password to login. Your old password is no longer valid.');
          return;
        }
        
        print(' Login: Setting Firebase auth user in AuthStateService - ID: $userId');
        
        // Set the user in our custom auth state service for Firebase users too
        await AuthStateService().setFirestoreAuthUser(userId, userData);
        
        print(' Login: AuthStateService state after setting Firebase user:');
        print('  - isAuthenticated: ${AuthStateService().isAuthenticated}');
        print('  - currentUserId: ${AuthStateService().currentUserId}');
      }

      // Check if user is banned - First check user document directly
      final isBanned = userData['isBanned'] ?? false;
      print('User ban status from Firestore: $isBanned'); // Debug log
      
      if (isBanned) {
        // User is marked as banned in Firestore, check ban details
        final banType = userData['banType'] ?? '';
        final banExpiresAt = userData['banExpiresAt'] as Timestamp?;
        
        // Check if temporary ban has expired
        if (banType == 'temporary' && banExpiresAt != null) {
          final expiryDate = banExpiresAt.toDate();
          if (DateTime.now().isAfter(expiryDate)) {
            // Ban has expired, remove it
            await FirebaseFirestore.instance.collection('users').doc(userId).update({
              'isBanned': false,
              'banType': FieldValue.delete(),
              'banExpiresAt': FieldValue.delete(),
            });
            print('Temporary ban expired and removed'); // Debug log
          } else {
            // Ban is still active
            if (!useFirestoreAuth) {
              await FirebaseAuth.instance.signOut();
            }
            setState(() {
              _isLoading = false;
            });
            _showBanDialog(banType, banExpiresAt, 'Account banned by administrator');
            return;
          }
        } else if (banType == 'permanent') {
          // Permanent ban
          if (!useFirestoreAuth) {
            await FirebaseAuth.instance.signOut();
          }
          setState(() {
            _isLoading = false;
          });
          _showBanDialog(banType, null, 'Account permanently banned by administrator');
          return;
        }
      }

      // Additional check using BanService for comprehensive ban validation
      if (!useFirestoreAuth) {
        final banStatus = await BanService.checkUserBanStatus(userId);
        if (banStatus != null) {
          print('Ban found via BanService: ${banStatus.banStatusText}'); // Debug log
          await FirebaseAuth.instance.signOut();
          setState(() {
            _isLoading = false;
          });
          _showBanDialogFromBanStatus(banStatus);
          return;
        }
      }
      
      if (!mounted) return;
      
      // Clear password reset flags after successful login
      if (useFirestoreAuth) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'forceReauth': FieldValue.delete(),
          'oldAuthDisabled': FieldValue.delete(),
          'requirePasswordReset': FieldValue.delete(),
          'lastLoginAt': DateTime.now(),
          'loginMethod': 'firestore_auth',
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'lastLoginAt': DateTime.now(),
          'loginMethod': 'firebase_auth',
        });
      }
      
      // Route based on user role
      final userRole = userData['role'] ?? 'buyer';
      
      if (userRole == 'admin') {
        // Admins go directly to admin dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else if (userRole == 'supplier') {
        // Suppliers go to supplier dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SupplierDashboard()),
        );
        
        // Show verification notification for unverified suppliers
        _showVerificationNotificationIfNeeded(userId, userData);
      } else if (userRole == 'sub_admin') {
        // Sub admins go to admin dashboard but with limited access
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        // Buyers follow normal flow
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
        
        // Check if user is newly registered and needs onboarding
        final isNewlyRegistered = userData['isNewlyRegistered'] ?? false;
        final onboardingCompleted = userData['onboardingCompleted'] ?? false;
        
        if ((isNewlyRegistered && !onboardingCompleted) || !onboardingDone) {
          // Show onboarding for newly registered users
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => OnboardingPage(userId: userId)),
          );
        } else {
          // Navigate based on user role for existing users
          Widget destination;
          if (userRole == 'admin') {
            destination = AdminDashboard();
          } else if (userRole == 'supplier') {
            destination = SupplierDashboard();
          } else {
            destination = CustomerHomePage();
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => destination),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Login Failed', _getAuthErrorMessage(e.code));
    } catch (e) {
      print('Login error: $e'); // Debug log
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error', 'An unexpected error occurred. Please try again.');
    }
  }

  /// Try authentication using Firestore password for sub_admins and password-reset users
  Future<Map<String, dynamic>> _tryFirestoreAuthentication(String email, String password) async {
    try {
      // Hash the entered password
      final hashedPassword = _hashPassword(password);
      
      // Try by username first (for sub_admins), then fallback to email
      QuerySnapshot<Map<String, dynamic>> userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: email.toLowerCase().trim())
          .where('password', isEqualTo: hashedPassword)
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email.toLowerCase().trim())
            .where('password', isEqualTo: hashedPassword)
            .limit(1)
            .get();
      }
      
      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final userData = userDoc.data();
        
        // Check if this user has reset their password recently
        final authMethod = userData['authMethod'];
        final isSubAdmin = userData['role'] == 'sub_admin';
        final oldAuthDisabled = userData['oldAuthDisabled'] ?? false;
        
        if (authMethod == 'password_reset' || oldAuthDisabled || isSubAdmin) {
          return {
            'success': true,
            'userId': userDoc.id,
            'userData': userData,
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Invalid credentials',
      };
    } catch (e) {
      print('Firestore auth error: $e');
      return {
        'success': false,
        'message': 'Authentication error',
      };
    }
  }

  /// Hash password using SHA-256 (same as password reset service)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _showBanDialog(String banType, Timestamp? expiresAt, String reason) {
    String banMessage;
    if (banType == 'permanent') {
      banMessage = 'Account permanently banned';
    } else if (banType == 'temporary' && expiresAt != null) {
      final expiryDate = expiresAt.toDate();
      final remaining = expiryDate.difference(DateTime.now());
      if (remaining.inDays > 0) {
        banMessage = 'Account temporarily banned for ${remaining.inDays} more days';
      } else if (remaining.inHours > 0) {
        banMessage = 'Account temporarily banned for ${remaining.inHours} more hours';
      } else {
        banMessage = 'Account ban expires soon';
      }
    } else {
      banMessage = 'Account banned';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Account Banned',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      banMessage,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reason: $reason',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (banType == 'temporary' && expiresAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Your account will be automatically unbanned on ${_formatDate(expiresAt.toDate())}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBanDialogFromBanStatus(UserBan banStatus) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Account Banned',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      banStatus.banStatusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reason: ${banStatus.reason}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!banStatus.isPermanent && banStatus.expiresAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Your account will be automatically unbanned on ${_formatDate(banStatus.expiresAt!)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      default:
        return 'Login failed. Please check your credentials and try again.';
    }
  }

  /// Show verification notification for unverified suppliers
  void _showVerificationNotificationIfNeeded(String userId, Map<String, dynamic> userData) {
    // Check if supplier is verified
    final isVerified = userData['isVerified'] ?? false;
    final verificationStatus = userData['verificationStatus'] ?? '';
    
    if (!isVerified && verificationStatus != 'pending_verification') {
      // Show floating notification after a short delay to ensure UI is ready
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _showVerificationFloatingNotification();
        }
      });
    }
  }

  void _showVerificationFloatingNotification() {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF6CA04A),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Get Verified',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Complete ID verification to unlock all supplier features',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => overlayEntry.remove(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Auto-remove after 5 seconds
    Future.delayed(Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from closing the app on the login page
        return false;
      },
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 32,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // Logo and Title
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey.withOpacity(0.2),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'VeggieConnect',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A Mobile App Linking Suppliers to Local Markets',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Login Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey.withOpacity(0.2),
                ),
                child: Column(
                  
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Email Field
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.withOpacity(0.1),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: TextStyle(color: Colors.black),
                          prefixIcon: Icon(Icons.email, color: Colors.green),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: TextStyle(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Password Field
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.withOpacity(0.1),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.black),
                          prefixIcon: Icon(Icons.lock, color: Colors.green),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.green,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: TextStyle(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                   // Login Button
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    onPressed: _isLoading ? null : _handleLogin,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
    strokeWidth: 2.5, // adjust thickness
    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
            )
          : Text(
              'Login',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  ),
),
                    const SizedBox(height: 12),
                    // Or Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Sign Up Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  SignUpPage()),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}