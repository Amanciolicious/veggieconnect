import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class SubAdminService {
  static const int defaultMaxSubAdmins = 2;

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Create a sub admin under a given super admin account.
  /// - Sub admin will use username/password for Firestore-based auth
  /// - Email will be set to the super admin's email to link ownership
  /// - Role will be `sub_admin`, verified=true, and authMethod='sub_admin'
  static Future<String> createSubAdmin({
    required String superAdminUserId,
    required String superAdminEmail,
    required String username,
    required String password,
    int? maxSubAdmins,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // Enforce unique username
    final existing = await firestore
        .collection('users')
        .where('username', isEqualTo: username.trim().toLowerCase())
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Username already taken');
    }

    // Enforce per-super-admin limit
    final limit = maxSubAdmins ?? defaultMaxSubAdmins;
    final currentCount = await firestore
        .collection('users')
        .where('role', isEqualTo: 'sub_admin')
        .where('parentAdminId', isEqualTo: superAdminUserId)
        .count()
        .get();
    if ((currentCount.count ?? 0) >= limit) {
      throw Exception('Sub admin limit reached');
    }

    // Create sub admin document (no FirebaseAuth account)
    final docRef = await firestore.collection('users').add({
      'email': superAdminEmail.trim().toLowerCase(),
      'username': username.trim().toLowerCase(),
      'password': _hashPassword(password),
      'role': 'sub_admin',
      'parentAdminId': superAdminUserId,
      'verified': true, // skip PIN verification flow
      'authMethod': 'sub_admin',
      'createdAt': FieldValue.serverTimestamp(),
      'isNewlyRegistered': false,
      'onboardingCompleted': true,
      'activeFirestoreSession': false,
    });

    return docRef.id;
  }

  /// Delete a sub admin account owned by the given super admin.
  static Future<void> deleteSubAdmin({
    required String superAdminUserId,
    required String subAdminUserId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('users').doc(subAdminUserId).get();
    if (!doc.exists) {
      return;
    }
    final data = doc.data() as Map<String, dynamic>;
    if (data['role'] != 'sub_admin' || data['parentAdminId'] != superAdminUserId) {
      throw Exception('Not authorized to delete this sub admin');
    }
    await firestore.collection('users').doc(subAdminUserId).delete();
  }

  /// Change a sub admin's password
  static Future<void> updateSubAdminPassword({
    required String superAdminUserId,
    required String subAdminUserId,
    required String newPassword,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('users').doc(subAdminUserId).get();
    if (!doc.exists) {
      throw Exception('Sub admin not found');
    }
    final data = doc.data() as Map<String, dynamic>;
    if (data['role'] != 'sub_admin' || data['parentAdminId'] != superAdminUserId) {
      throw Exception('Not authorized to update this sub admin');
    }
    await firestore.collection('users').doc(subAdminUserId).update({
      'password': _hashPassword(newPassword),
    });
  }

  /// Get all sub admins for a super admin
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getSubAdmins({
    required String superAdminUserId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'sub_admin')
        .where('parentAdminId', isEqualTo: superAdminUserId)
        .get();
    return snapshot.docs;
  }
}


