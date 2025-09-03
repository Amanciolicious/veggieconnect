import 'package:cloud_firestore/cloud_firestore.dart';

class FarmLocationRequest {
  final String id;
  final String requesterId; // Supplier ID who made the request
  final String requesterName; // Supplier name
  final String farmName;
  final String farmDescription;
  final double latitude;
  final double longitude;
  final String address;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin ID who reviewed
  final String? reviewNotes;
  final DateTime? autoApprovalAt; // When auto-approval will trigger

  FarmLocationRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.farmName,
    required this.farmDescription,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.status = 'pending',
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
    this.autoApprovalAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'farmName': farmName,
      'farmDescription': farmDescription,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status,
      'requestedAt': requestedAt,
      'reviewedAt': reviewedAt,
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
      'autoApprovalAt': autoApprovalAt,
    };
  }

  factory FarmLocationRequest.fromMap(Map<String, dynamic> map) {
    return FarmLocationRequest(
      id: map['id'] ?? '',
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? '',
      farmName: map['farmName'] ?? '',
      farmDescription: map['farmDescription'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'] ?? '',
      status: map['status'] ?? 'pending',
      requestedAt: (map['requestedAt'] as Timestamp).toDate(),
      reviewedAt: map['reviewedAt'] != null ? (map['reviewedAt'] as Timestamp).toDate() : null,
      reviewedBy: map['reviewedBy'],
      reviewNotes: map['reviewNotes'],
      autoApprovalAt: map['autoApprovalAt'] != null ? (map['autoApprovalAt'] as Timestamp).toDate() : null,
    );
  }

  FarmLocationRequest copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? farmName,
    String? farmDescription,
    double? latitude,
    double? longitude,
    String? address,
    String? status,
    DateTime? requestedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewNotes,
    DateTime? autoApprovalAt,
  }) {
    return FarmLocationRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      farmName: farmName ?? this.farmName,
      farmDescription: farmDescription ?? this.farmDescription,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      autoApprovalAt: autoApprovalAt ?? this.autoApprovalAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isAutoApprovalDue => autoApprovalAt != null && DateTime.now().isAfter(autoApprovalAt!);
}
