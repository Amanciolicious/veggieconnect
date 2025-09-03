import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ban_model.dart';

class BanService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _bansCollection = 'user_bans';

  // Apply temporary ban
  static Future<void> applyTemporaryBan({
    required String userId,
    required String bannedBy,
    required String reason,
    required int durationDays,
  }) async {
    final banData = UserBan(
      userId: userId,
      bannedBy: bannedBy,
      reason: reason,
      bannedAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: durationDays)),
      isPermanent: false,
      isActive: true,
    );

    // Add ban record
    await _firestore.collection(_bansCollection).add(banData.toFirestore());
    
    // Update user status
    await _firestore.collection('users').doc(userId).update({
      'isBanned': true,
      'banType': 'temporary',
      'banExpiresAt': Timestamp.fromDate(banData.expiresAt!),
    });
  }

  // Apply permanent ban
  static Future<void> applyPermanentBan({
    required String userId,
    required String bannedBy,
    required String reason,
  }) async {
    final banData = UserBan(
      userId: userId,
      bannedBy: bannedBy,
      reason: reason,
      bannedAt: DateTime.now(),
      expiresAt: null,
      isPermanent: true,
      isActive: true,
    );

    // Add ban record
    await _firestore.collection(_bansCollection).add(banData.toFirestore());
    
    // Update user status
    await _firestore.collection('users').doc(userId).update({
      'isBanned': true,
      'banType': 'permanent',
      'banExpiresAt': null,
    });
  }

  // Remove ban
  static Future<void> removeBan(String userId) async {
    // Deactivate all active bans for this user
    final bansQuery = await _firestore
        .collection(_bansCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in bansQuery.docs) {
      batch.update(doc.reference, {'isActive': false});
    }
    await batch.commit();

    // Update user status
    await _firestore.collection('users').doc(userId).update({
      'isBanned': false,
      'banType': FieldValue.delete(),
      'banExpiresAt': FieldValue.delete(),
    });
  }

  // Check if user is currently banned
  static Future<UserBan?> checkUserBanStatus(String userId) async {
    try {
      // First check user document for quick ban status
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      
      final userData = userDoc.data()!;
      final isBanned = userData['isBanned'] ?? false;
      
      if (!isBanned) return null;

      // Check if temporary ban has expired
      if (userData['banType'] == 'temporary' && userData['banExpiresAt'] != null) {
        final expiresAt = (userData['banExpiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          // Ban has expired, remove it
          await removeBan(userId);
          return null;
        }
      }

      // Get the latest active ban record
      final banQuery = await _firestore
          .collection(_bansCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('bannedAt', descending: true)
          .limit(1)
          .get();

      if (banQuery.docs.isEmpty) {
        // No active ban found, update user status
        await removeBan(userId);
        return null;
      }

      final banDoc = banQuery.docs.first;
      final ban = UserBan.fromFirestore(banDoc);

      // Check if ban has expired
      if (!ban.isPermanent && ban.isExpired) {
        await removeBan(userId);
        return null;
      }

      return ban;
    } catch (e) {
      return null;
    }
  }

  // Get all bans for a user (for admin view)
  static Future<List<UserBan>> getUserBanHistory(String userId) async {
    final banQuery = await _firestore
        .collection(_bansCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('bannedAt', descending: true)
        .get();

    return banQuery.docs.map((doc) => UserBan.fromFirestore(doc)).toList();
  }

  // Get all currently banned users (for admin dashboard)
  static Future<List<String>> getBannedUserIds() async {
    final usersQuery = await _firestore
        .collection('users')
        .where('isBanned', isEqualTo: true)
        .get();

    return usersQuery.docs.map((doc) => doc.id).toList();
  }
}
