import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierVerification {
  final String id;
  final String supplierId;
  final String supplierName;
  final String supplierEmail;
  final String frontIdImageUrl;
  final String backIdImageUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin ID who reviewed
  final String? reviewNotes;
  final bool autoApproved;
  final DateTime? autoApprovalScheduledAt;
  
  // OCR Extracted Data
  final String? extractedName;
  final String? extractedIdNumber;
  final String? extractedAddress;
  final String? extractedDateOfBirth;
  final String? extractedGender;
  final String? extractedNationality;
  final double? ocrConfidenceScore;
  final Map<String, dynamic>? rawOcrData;

  SupplierVerification({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.supplierEmail,
    required this.frontIdImageUrl,
    required this.backIdImageUrl,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
    this.autoApproved = false,
    this.autoApprovalScheduledAt,
    this.extractedName,
    this.extractedIdNumber,
    this.extractedAddress,
    this.extractedDateOfBirth,
    this.extractedGender,
    this.extractedNationality,
    this.ocrConfidenceScore,
    this.rawOcrData,
  });

  factory SupplierVerification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupplierVerification(
      id: doc.id,
      supplierId: data['supplierId'] ?? '',
      supplierName: data['supplierName'] ?? '',
      supplierEmail: data['supplierEmail'] ?? '',
      frontIdImageUrl: data['frontIdImageUrl'] ?? '',
      backIdImageUrl: data['backIdImageUrl'] ?? '',
      status: data['status'] ?? 'pending',
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      reviewedAt: data['reviewedAt'] != null 
          ? (data['reviewedAt'] as Timestamp).toDate() 
          : null,
      reviewedBy: data['reviewedBy'],
      reviewNotes: data['reviewNotes'],
      autoApproved: data['autoApproved'] ?? false,
      autoApprovalScheduledAt: data['autoApprovalScheduledAt'] != null
          ? (data['autoApprovalScheduledAt'] as Timestamp).toDate()
          : null,
      extractedName: data['extractedName'],
      extractedIdNumber: data['extractedIdNumber'],
      extractedAddress: data['extractedAddress'],
      extractedDateOfBirth: data['extractedDateOfBirth'],
      extractedGender: data['extractedGender'],
      extractedNationality: data['extractedNationality'],
      ocrConfidenceScore: data['ocrConfidenceScore']?.toDouble(),
      rawOcrData: data['rawOcrData'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierEmail': supplierEmail,
      'frontIdImageUrl': frontIdImageUrl,
      'backIdImageUrl': backIdImageUrl,
      'status': status,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
      'autoApproved': autoApproved,
      'autoApprovalScheduledAt': autoApprovalScheduledAt != null 
          ? Timestamp.fromDate(autoApprovalScheduledAt!) 
          : null,
      'extractedName': extractedName,
      'extractedIdNumber': extractedIdNumber,
      'extractedAddress': extractedAddress,
      'extractedDateOfBirth': extractedDateOfBirth,
      'extractedGender': extractedGender,
      'extractedNationality': extractedNationality,
      'ocrConfidenceScore': ocrConfidenceScore,
      'rawOcrData': rawOcrData,
    };
  }

  SupplierVerification copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    String? supplierEmail,
    String? frontIdImageUrl,
    String? backIdImageUrl,
    String? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewNotes,
    bool? autoApproved,
    DateTime? autoApprovalScheduledAt,
    String? extractedName,
    String? extractedIdNumber,
    String? extractedAddress,
    String? extractedDateOfBirth,
    String? extractedGender,
    String? extractedNationality,
    double? ocrConfidenceScore,
    Map<String, dynamic>? rawOcrData,
  }) {
    return SupplierVerification(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierEmail: supplierEmail ?? this.supplierEmail,
      frontIdImageUrl: frontIdImageUrl ?? this.frontIdImageUrl,
      backIdImageUrl: backIdImageUrl ?? this.backIdImageUrl,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      autoApproved: autoApproved ?? this.autoApproved,
      autoApprovalScheduledAt: autoApprovalScheduledAt ?? this.autoApprovalScheduledAt,
      extractedName: extractedName ?? this.extractedName,
      extractedIdNumber: extractedIdNumber ?? this.extractedIdNumber,
      extractedAddress: extractedAddress ?? this.extractedAddress,
      extractedDateOfBirth: extractedDateOfBirth ?? this.extractedDateOfBirth,
      extractedGender: extractedGender ?? this.extractedGender,
      extractedNationality: extractedNationality ?? this.extractedNationality,
      ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
      rawOcrData: rawOcrData ?? this.rawOcrData,
    );
  }
}
