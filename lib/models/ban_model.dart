import 'package:cloud_firestore/cloud_firestore.dart';

class UserBan {
  final String userId;
  final String bannedBy;
  final String reason;
  final DateTime bannedAt;
  final DateTime? expiresAt; // null for permanent ban
  final bool isPermanent;
  final bool isActive;

  UserBan({
    required this.userId,
    required this.bannedBy,
    required this.reason,
    required this.bannedAt,
    this.expiresAt,
    required this.isPermanent,
    required this.isActive,
  });

  factory UserBan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserBan(
      userId: data['userId'] ?? '',
      bannedBy: data['bannedBy'] ?? '',
      reason: data['reason'] ?? '',
      bannedAt: (data['bannedAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null ? (data['expiresAt'] as Timestamp).toDate() : null,
      isPermanent: data['isPermanent'] ?? false,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'bannedBy': bannedBy,
      'reason': reason,
      'bannedAt': Timestamp.fromDate(bannedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isPermanent': isPermanent,
      'isActive': isActive,
    };
  }

  bool get isExpired {
    if (isPermanent) return false;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  String get banStatusText {
    if (isPermanent) {
      return 'Account permanently banned';
    } else if (expiresAt != null) {
      final remaining = expiresAt!.difference(DateTime.now());
      if (remaining.inDays > 0) {
        return 'Account temporarily banned for ${remaining.inDays} more days';
      } else if (remaining.inHours > 0) {
        return 'Account temporarily banned for ${remaining.inHours} more hours';
      } else {
        return 'Account ban expires soon';
      }
    }
    return 'Account banned';
  }
}
