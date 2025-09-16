// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:veggieconnect/models/supplier_verification.dart';
import 'package:veggieconnect/services/cloudinary_service.dart';
import 'package:veggieconnect/services/notification_service.dart';

class SupplierVerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'supplier_verifications';

  /// Submit a new verification request with OCR processing
  static Future<String?> submitVerificationRequest({
    required String supplierId,
    required String supplierName,
    required String supplierEmail,
    required Uint8List frontIdImageBytes,
    required Uint8List backIdImageBytes,
  }) async {
    try {
      // Upload images to Cloudinary
      final frontImageUrl = await CloudinaryService.uploadBytes(
        frontIdImageBytes,
        fileName: 'verification_front_${supplierId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      final backImageUrl = await CloudinaryService.uploadBytes(
        backIdImageBytes,
        fileName: 'verification_back_${supplierId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (frontImageUrl.isEmpty || backImageUrl.isEmpty) {
        throw Exception('Failed to upload ID images');
      }

      // Process OCR on both images
      final frontOcrData = await _performOCR(frontIdImageBytes, 'front');
      final backOcrData = await _performOCR(backIdImageBytes, 'back');

      // Combine OCR results
      final combinedOcrData = _combineOcrResults(frontOcrData, backOcrData);

      // Schedule auto-approval for 24 hours from now
      final autoApprovalTime = DateTime.now().add(Duration(hours: 24));

      // Create verification request
      final verification = SupplierVerification(
        id: '', // Will be set by Firestore
        supplierId: supplierId,
        supplierName: supplierName,
        supplierEmail: supplierEmail,
        frontIdImageUrl: frontImageUrl,
        backIdImageUrl: backImageUrl,
        status: 'pending',
        submittedAt: DateTime.now(),
        autoApprovalScheduledAt: autoApprovalTime,
        extractedName: combinedOcrData['name'],
        extractedIdNumber: combinedOcrData['id_number'],
        extractedAddress: combinedOcrData['address'],
        extractedDateOfBirth: combinedOcrData['date_of_birth'],
        extractedGender: combinedOcrData['gender'],
        extractedNationality: combinedOcrData['nationality'],
        ocrConfidenceScore: combinedOcrData['confidence_score'],
        rawOcrData: combinedOcrData,
      );

      // Save to Firestore
      final docRef = await _firestore.collection(_collection).add(verification.toFirestore());

      // Update supplier status to pending_verification
      await _firestore.collection('users').doc(supplierId).update({
        'verificationStatus': 'pending_verification',
        'verificationRequestId': docRef.id,
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to admins
      final notificationService = NotificationService();
      await notificationService.sendVerificationRequestNotification(
        supplierName: supplierName,
        supplierId: supplierId,
        verificationId: docRef.id,
      );

      return docRef.id;
    } catch (e) {
      print('Error submitting verification request: $e');
      return null;
    }
  }

  /// Perform OCR on image bytes
  static Future<Map<String, dynamic>> _performOCR(Uint8List imageBytes, String side) async {
    try {
      // Preprocess image for better OCR results
      final processedBytes = await _preprocessImage(imageBytes);
      
      // Save temporary file for OCR processing
      final tempFile = File('${Directory.systemTemp.path}/temp_id_${side}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(processedBytes);

      // Perform OCR
      String ocrText = await FlutterTesseractOcr.extractText(
        tempFile.path,
        language: 'eng',
        args: {
          "psm": "6", // Assume uniform block of text
          "preserve_interword_spaces": "1",
        },
      );

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Extract structured data from OCR text
      final extractedData = _extractDataFromOcrText(ocrText, side);
      
      return extractedData;
    } catch (e) {
      print('OCR Error on $side: $e');
      return {
        'raw_text': '',
        'confidence_score': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Preprocess image for better OCR results
  static Future<Uint8List> _preprocessImage(Uint8List imageBytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Resize if too large (max 1500px width)
      if (image.width > 1500) {
        image = img.copyResize(image, width: 1500);
      }

      // Convert to grayscale for better OCR
      image = img.grayscale(image);

      // Increase contrast
      image = img.contrast(image, contrast: 1.2);

      // Encode back to bytes
      final processedBytes = img.encodeJpg(image, quality: 90);
      return Uint8List.fromList(processedBytes);
    } catch (e) {
      print('Image preprocessing error: $e');
      return imageBytes;
    }
  }

  /// Extract structured data from OCR text
  static Map<String, dynamic> _extractDataFromOcrText(String ocrText, String side) {
    final Map<String, dynamic> extractedData = {
      'raw_text': ocrText,
      'side': side,
      'confidence_score': 0.0,
    };

    try {
      final lines = ocrText.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
      
      // Philippine ID patterns
      final namePattern = RegExp(r'^([A-Z\s,]+)$');
      final idNumberPattern = RegExp(r'(\d{4}-\d{4}-\d{4})');
      final addressPattern = RegExp(r'(.*(?:CITY|PROVINCE|MUNICIPALITY|BARANGAY).*)');
      final dobPattern = RegExp(r'(\d{2}\/\d{2}\/\d{4})');
      final genderPattern = RegExp(r'(MALE|FEMALE|M|F)');

      double confidenceScore = 0.0;
      int matchedFields = 0;

      for (String line in lines) {
        final upperLine = line.toUpperCase();
        
        // Extract name (usually the longest line with only letters and spaces)
        if (namePattern.hasMatch(upperLine) && line.length > 10 && extractedData['name'] == null) {
          extractedData['name'] = _cleanName(line);
          matchedFields++;
        }

        // Extract ID number
        final idMatch = idNumberPattern.firstMatch(line);
        if (idMatch != null) {
          extractedData['id_number'] = idMatch.group(1);
          matchedFields++;
        }

        // Extract address
        if (addressPattern.hasMatch(upperLine) && extractedData['address'] == null) {
          extractedData['address'] = line;
          matchedFields++;
        }

        // Extract date of birth
        final dobMatch = dobPattern.firstMatch(line);
        if (dobMatch != null) {
          extractedData['date_of_birth'] = dobMatch.group(1);
          matchedFields++;
        }

        // Extract gender
        if (genderPattern.hasMatch(upperLine)) {
          final match = genderPattern.firstMatch(upperLine);
          extractedData['gender'] = match?.group(1);
          matchedFields++;
        }

        // Extract nationality (usually "FILIPINO" or "PHILIPPINES")
        if (upperLine.contains('FILIPINO') || upperLine.contains('PHILIPPINES')) {
          extractedData['nationality'] = 'Filipino';
          matchedFields++;
        }
      }

      // Calculate confidence score based on matched fields and text quality
      confidenceScore = (matchedFields / 6.0) * 0.8; // Base score from field matches
      if (ocrText.length > 50) confidenceScore += 0.1; // Bonus for sufficient text
      if (extractedData['name'] != null && extractedData['id_number'] != null) {
        confidenceScore += 0.1; // Bonus for critical fields
      }

      extractedData['confidence_score'] = confidenceScore.clamp(0.0, 1.0);
      extractedData['matched_fields'] = matchedFields;

    } catch (e) {
      print('Data extraction error: $e');
      extractedData['error'] = e.toString();
    }

    return extractedData;
  }

  /// Clean and format extracted name
  static String _cleanName(String rawName) {
    return rawName
        .split(' ')
        .map((word) => word.toLowerCase())
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ')
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .trim();
  }

  /// Combine OCR results from front and back images
  static Map<String, dynamic> _combineOcrResults(Map<String, dynamic> frontData, Map<String, dynamic> backData) {
    final combined = <String, dynamic>{
      'front_ocr': frontData,
      'back_ocr': backData,
    };

    // Prioritize data from front image, fallback to back
    combined['name'] = frontData['name'] ?? backData['name'];
    combined['id_number'] = frontData['id_number'] ?? backData['id_number'];
    combined['address'] = backData['address'] ?? frontData['address']; // Address usually on back
    combined['date_of_birth'] = frontData['date_of_birth'] ?? backData['date_of_birth'];
    combined['gender'] = frontData['gender'] ?? backData['gender'];
    combined['nationality'] = frontData['nationality'] ?? backData['nationality'];

    // Calculate combined confidence score
    final frontConfidence = (frontData['confidence_score'] ?? 0.0) as double;
    final backConfidence = (backData['confidence_score'] ?? 0.0) as double;
    combined['confidence_score'] = (frontConfidence + backConfidence) / 2.0;

    return combined;
  }

  /// Get verification request by ID
  static Future<SupplierVerification?> getVerificationById(String verificationId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(verificationId).get();
      if (doc.exists) {
        return SupplierVerification.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting verification: $e');
      return null;
    }
  }

  /// Get verification request by supplier ID
  static Future<SupplierVerification?> getVerificationBySupplier(String supplierId) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('supplierId', isEqualTo: supplierId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return SupplierVerification.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting supplier verification: $e');
      return null;
    }
  }

  /// Get all pending verification requests (for admin)
  static Stream<List<SupplierVerification>> getPendingVerifications() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupplierVerification.fromFirestore(doc))
            .toList());
  }

  /// Approve verification request (admin action)
  static Future<bool> approveVerification(String verificationId, String adminId, {String? notes}) async {
    try {
      final verification = await getVerificationById(verificationId);
      if (verification == null) return false;

      // Update verification status
      await _firestore.collection(_collection).doc(verificationId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
        'reviewNotes': notes,
      });

      // Update supplier verification status
      await _firestore.collection('users').doc(verification.supplierId).update({
        'isVerified': true,
        'verificationStatus': 'verified',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': adminId,
      });

      // Send approval notification to supplier
      final notificationService = NotificationService();
      await notificationService.sendVerificationApprovedNotification(
        supplierId: verification.supplierId,
        supplierName: verification.supplierName,
      );

      return true;
    } catch (e) {
      print('Error approving verification: $e');
      return false;
    }
  }

  /// Reject verification request (admin action)
  static Future<bool> rejectVerification(String verificationId, String adminId, {required String reason}) async {
    try {
      final verification = await getVerificationById(verificationId);
      if (verification == null) return false;

      // Update verification status
      await _firestore.collection(_collection).doc(verificationId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
        'reviewNotes': reason,
      });

      // Update supplier verification status
      await _firestore.collection('users').doc(verification.supplierId).update({
        'isVerified': false,
        'verificationStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });

      // Send rejection notification to supplier
      final notificationService = NotificationService();
      await notificationService.sendVerificationRejectedNotification(
        supplierId: verification.supplierId,
        supplierName: verification.supplierName,
        reason: reason,
      );

      return true;
    } catch (e) {
      print('Error rejecting verification: $e');
      return false;
    }
  }

  /// Auto-approve verification after 24 hours (called by Cloud Function)
  static Future<bool> autoApproveVerification(String verificationId) async {
    try {
      final verification = await getVerificationById(verificationId);
      if (verification == null || verification.status != 'pending') return false;

      // Check if 24 hours have passed
      final now = DateTime.now();
      if (verification.autoApprovalScheduledAt == null || 
          now.isBefore(verification.autoApprovalScheduledAt!)) {
        return false;
      }

      // Update verification status
      await _firestore.collection(_collection).doc(verificationId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'autoApproved': true,
        'reviewNotes': 'Auto-approved after 24 hours',
      });

      // Update supplier verification status
      await _firestore.collection('users').doc(verification.supplierId).update({
        'isVerified': true,
        'verificationStatus': 'verified',
        'verifiedAt': FieldValue.serverTimestamp(),
        'autoVerified': true,
      });

      // Send auto-approval notification
      final notificationService = NotificationService();
      await notificationService.sendVerificationAutoApprovedNotification(
        supplierId: verification.supplierId,
        supplierName: verification.supplierName,
      );

      return true;
    } catch (e) {
      print('Error auto-approving verification: $e');
      return false;
    }
  }

  /// Check if supplier can perform restricted actions
  static Future<bool> isSupplierVerified(String supplierId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(supplierId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['isVerified'] == true;
    } catch (e) {
      print('Error checking verification status: $e');
      return false;
    }
  }

  /// Get verification statistics for admin dashboard
  static Future<Map<String, int>> getVerificationStats() async {
    try {
      final pendingQuery = await _firestore.collection(_collection).where('status', isEqualTo: 'pending').get();
      final approvedQuery = await _firestore.collection(_collection).where('status', isEqualTo: 'approved').get();
      final rejectedQuery = await _firestore.collection(_collection).where('status', isEqualTo: 'rejected').get();

      return {
        'pending': pendingQuery.docs.length,
        'approved': approvedQuery.docs.length,
        'rejected': rejectedQuery.docs.length,
        'total': pendingQuery.docs.length + approvedQuery.docs.length + rejectedQuery.docs.length,
      };
    } catch (e) {
      print('Error getting verification stats: $e');
      return {'pending': 0, 'approved': 0, 'rejected': 0, 'total': 0};
    }
  }
}
