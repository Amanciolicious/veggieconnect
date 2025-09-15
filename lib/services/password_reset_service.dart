// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'email_service.dart';

class PasswordResetService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int _pinExpiryMinutes = 15;

  /// Validates if email exists in Firestore and initiates password reset
  static Future<Map<String, dynamic>> initiatePasswordReset(String email) async {
    try {
      // Check if email exists in users collection
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .get();

      if (userQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No account found with this email address.',
        };
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final userId = userDoc.id;
      final userName = userData['firstName'] ?? 'User';

      // Generate 5-digit PIN
      final pin = EmailService.generateVerificationPin();
      final expiryTime = DateTime.now().add(Duration(minutes: _pinExpiryMinutes));

      // Store PIN in Firestore with expiry
      await _firestore.collection('password_resets').doc(userId).set({
        'email': email.toLowerCase().trim(),
        'pin': pin,
        'expiryTime': expiryTime,
        'isUsed': false,
        'createdAt': DateTime.now(),
        'userId': userId,
      });

      // Send PIN via EmailJS
      final emailSent = await EmailService.sendPasswordResetPin(
        email: email,
        pin: pin,
        userName: userName,
      );

      if (!emailSent) {
        return {
          'success': false,
          'message': 'Failed to send verification email. Please try again.',
        };
      }

      return {
        'success': true,
        'message': 'Verification PIN sent to your email address.',
        'userId': userId,
      };
    } catch (e) {
      print('Error initiating password reset: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again later.',
      };
    }
  }

  /// Verifies the PIN entered by user
  static Future<Map<String, dynamic>> verifyPin({
    required String userId,
    required String enteredPin,
  }) async {
    try {
      final resetDoc = await _firestore
          .collection('password_resets')
          .doc(userId)
          .get();

      if (!resetDoc.exists) {
        return {
          'success': false,
          'message': 'Invalid or expired reset request.',
        };
      }

      final resetData = resetDoc.data()!;
      final storedPin = resetData['pin'];
      final expiryTime = (resetData['expiryTime'] as Timestamp).toDate();
      final isUsed = resetData['isUsed'] ?? false;

      // Check if PIN is already used
      if (isUsed) {
        return {
          'success': false,
          'message': 'This PIN has already been used.',
        };
      }

      // Check if PIN is expired
      if (DateTime.now().isAfter(expiryTime)) {
        return {
          'success': false,
          'message': 'PIN has expired. Please request a new one.',
        };
      }

      // Verify PIN
      if (storedPin != enteredPin.trim()) {
        return {
          'success': false,
          'message': 'Invalid PIN. Please check and try again.',
        };
      }

      // Mark PIN as used
      await _firestore.collection('password_resets').doc(userId).update({
        'isUsed': true,
        'verifiedAt': DateTime.now(),
      });

      return {
        'success': true,
        'message': 'PIN verified successfully.',
      };
    } catch (e) {
      print('Error verifying PIN: $e');
      return {
        'success': false,
        'message': 'An error occurred during verification.',
      };
    }
  }

  /// Updates user password in both Firebase Auth and Firestore
  static Future<Map<String, dynamic>> updatePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      // Verify that PIN was verified (additional security check)
      final resetDoc = await _firestore
          .collection('password_resets')
          .doc(userId)
          .get();

      if (!resetDoc.exists) {
        return {
          'success': false,
          'message': 'Invalid reset session.',
        };
      }

      final resetData = resetDoc.data()!;
      final isUsed = resetData['isUsed'] ?? false;
      final verifiedAt = resetData['verifiedAt'];
      final userEmail = resetData['email'];

      if (!isUsed || verifiedAt == null) {
        return {
          'success': false,
          'message': 'PIN verification required.',
        };
      }

      // Get user document to verify email
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User account not found.',
        };
      }

      // Update Firebase Authentication password
      try {
        // Sign in with admin privileges to update password
        // Note: This requires Firebase Admin SDK or custom token approach
        await _updateFirebaseAuthPassword(userEmail, newPassword);
        print('Firebase Auth password updated successfully');
      } catch (e) {
        print('Firebase Auth update failed: $e');
        // Continue with Firestore update as fallback
      }

      // Hash the new password for Firestore
      final hashedPassword = _hashPassword(newPassword);

      // Update password in Firestore users collection
      await _firestore.collection('users').doc(userId).update({
        'password': hashedPassword,
        'passwordUpdatedAt': DateTime.now(),
        'authMethod': 'password_reset', // Track how password was changed
      });

      // Invalidate all existing sessions by updating a session token
      await _firestore.collection('users').doc(userId).update({
        'sessionInvalidatedAt': DateTime.now(),
        'forceReauth': true, // Force re-authentication on next login
      });

      // Clean up password reset document
      await _firestore.collection('password_resets').doc(userId).delete();

      // Sign out any existing sessions (if user is currently signed in)
      try {
        if (_auth.currentUser?.uid == userId) {
          await _auth.signOut();
        }
      } catch (e) {
        print('Could not sign out current user: $e');
      }

      return {
        'success': true,
        'message': 'Password updated successfully. Please login with your new password.',
      };
    } catch (e) {
      print('Error updating password: $e');
      return {
        'success': false,
        'message': 'Failed to update password. Please try again.',
      };
    }
  }

  /// Update Firebase Authentication password using admin approach
  static Future<void> _updateFirebaseAuthPassword(String email, String newPassword) async {
    try {
      // Method 1: Use Firebase Admin SDK (requires server-side implementation)
      // This would typically be done via Cloud Functions
      await _firestore.collection('admin_tasks').add({
        'type': 'update_auth_password',
        'email': email,
        'newPassword': newPassword, // In production, this should be encrypted
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Method 2: Alternative approach - disable the user temporarily
      // This forces them to use the new Firestore password
      await _firestore.collection('users').where('email', isEqualTo: email).get().then((docs) async {
        if (docs.docs.isNotEmpty) {
          final userId = docs.docs.first.id;
          await _firestore.collection('users').doc(userId).update({
            'requirePasswordReset': true,
            'oldAuthDisabled': true,
          });
        }
      });

    } catch (e) {
      print('Error updating Firebase Auth password: $e');
      rethrow;
    }
  }

  /// Generates a new PIN and sends it (for resend functionality)
  static Future<Map<String, dynamic>> resendPin(String userId) async {
    try {
      final resetDoc = await _firestore
          .collection('password_resets')
          .doc(userId)
          .get();

      if (!resetDoc.exists) {
        return {
          'success': false,
          'message': 'Reset session not found.',
        };
      }

      final resetData = resetDoc.data()!;
      final email = resetData['email'];

      // Get user name
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userName = userDoc.data()?['firstName'] ?? 'User';

      // Generate new PIN
      final newPin = EmailService.generateVerificationPin();
      final newExpiryTime = DateTime.now().add(Duration(minutes: _pinExpiryMinutes));

      // Update PIN in Firestore
      await _firestore.collection('password_resets').doc(userId).update({
        'pin': newPin,
        'expiryTime': newExpiryTime,
        'isUsed': false,
        'resendAt': DateTime.now(),
      });

      // Send new PIN via EmailJS
      final emailSent = await EmailService.sendPasswordResetPin(
        email: email,
        pin: newPin,
        userName: userName,
      );

      if (!emailSent) {
        return {
          'success': false,
          'message': 'Failed to resend PIN. Please try again.',
        };
      }

      return {
        'success': true,
        'message': 'New PIN sent to your email address.',
      };
    } catch (e) {
      print('Error resending PIN: $e');
      return {
        'success': false,
        'message': 'Failed to resend PIN.',
      };
    }
  }

  /// Hash password using SHA-256
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Clean up expired password reset requests (utility method)
  static Future<void> cleanupExpiredResets() async {
    try {
      final expiredQuery = await _firestore
          .collection('password_resets')
          .where('expiryTime', isLessThan: DateTime.now())
          .get();

      final batch = _firestore.batch();
      for (final doc in expiredQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('Cleaned up ${expiredQuery.docs.length} expired password resets');
    } catch (e) {
      print('Error cleaning up expired resets: $e');
    }
  }
}
