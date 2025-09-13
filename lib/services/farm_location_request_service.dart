import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/farm_location_request.dart';
import 'map_service.dart';
import 'notification_service.dart';

class FarmLocationRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MapService _mapService = MapService();
  final NotificationService _notificationService = NotificationService();

  // Submit a new farm location request
  Future<String> submitFarmLocationRequest({
    required String farmName,
    required String farmDescription,
    required LatLng location,
    String? address,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get address if not provided
      final finalAddress = address ?? await _mapService.getAddressFromCoordinates(location);

      // Calculate auto-approval time (2 minutes from now)
      final autoApprovalAt = DateTime.now().add(Duration(minutes: 2));

      // Create the request document
      final docRef = await _firestore.collection('farm_location_requests').add({
        'requesterId': user.uid,
        'requesterName': user.displayName ?? user.email ?? 'Unknown Supplier',
        'farmName': farmName,
        'farmDescription': farmDescription,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'address': finalAddress,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'autoApprovalAt': Timestamp.fromDate(autoApprovalAt),
        'notes': '',
      });

      // Send admin notification for new farm location request
      try {
        final supplierName = user.displayName ?? user.email ?? 'Unknown Supplier';
        await _notificationService.sendFarmLocationRequestNotification(
          farmName: farmName,
          supplierName: supplierName,
          supplierId: user.uid,
          requestId: docRef.id,
        );
      } catch (e) {
        debugPrint('Failed to send farm location request notification: $e');
      }

      // Update the document with its own ID
      await docRef.update({'id': docRef.id});

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit farm location request: $e');
    }
  }

  // Get all pending requests (for admin)
  Future<List<FarmLocationRequest>> getPendingRequests() async {
    try {
      final snapshot = await _firestore
          .collection('farm_location_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FarmLocationRequest.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get pending requests: $e');
    }
  }

  // Get all requests by requester ID
  Future<List<FarmLocationRequest>> getRequestsByRequester(String requesterId) async {
    try {
      final snapshot = await _firestore
          .collection('farm_location_requests')
          .where('requesterId', isEqualTo: requesterId)
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FarmLocationRequest.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get requests by requester: $e');
    }
  }

  // Get current user's requests
  Future<List<FarmLocationRequest>> getCurrentUserRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      return await getRequestsByRequester(user.uid);
    } catch (e) {
      throw Exception('Failed to get current user requests: $e');
    }
  }

  // Approve a farm location request
  Future<void> approveRequest({
    required String requestId,
    String? reviewNotes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the request
      final requestDoc = await _firestore.collection('farm_location_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final request = FarmLocationRequest.fromMap({...requestData, 'id': requestDoc.id});

      // Update request status
      await _firestore.collection('farm_location_requests').doc(requestId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': user.uid,
        'reviewNotes': reviewNotes,
      });

      // Create the actual farm location
      await _firestore.collection('farm_locations').add({
        'name': request.farmName,
        'description': request.farmDescription,
        'latitude': request.latitude,
        'longitude': request.longitude,
        'supplierId': request.requesterId,
        'supplierName': request.requesterName,
        'address': request.address,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

              // Send in-app notification to supplier about approval
        _notificationService.sendInAppNotification(
          title: 'Farm Location Approved!',
          body: 'Your farm location request "${request.farmName}" has been approved by admin.',
          type: 'farm_location_approved',
        );
    } catch (e) {
      throw Exception('Failed to approve request: $e');
    }
  }

  // Reject a farm location request
  Future<void> rejectRequest({
    required String requestId,
    String? reviewNotes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('farm_location_requests').doc(requestId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': user.uid,
        'reviewNotes': reviewNotes,
      });
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // Auto-approve requests that are past their auto-approval time
  Future<void> processAutoApprovals() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('farm_location_requests')
          .where('status', isEqualTo: 'pending')
          .where('autoApprovalAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      for (final doc in snapshot.docs) {
        final requestData = doc.data();
        final request = FarmLocationRequest.fromMap({...requestData, 'id': doc.id});

        // Auto-approve the request
        await _firestore.collection('farm_location_requests').doc(doc.id).update({
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': 'system_auto_approval',
          'reviewNotes': 'Automatically approved after 2 minutes',
        });

        // Create the actual farm location
        await _firestore.collection('farm_locations').add({
          'name': request.farmName,
          'description': request.farmDescription,
          'latitude': request.latitude,
          'longitude': request.longitude,
          'supplierId': request.requesterId,
          'supplierName': request.requesterName,
          'address': request.address,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send in-app notification to supplier about auto-approval
        _notificationService.sendInAppNotification(
          title: 'Farm Location Auto-Approved!',
          body: 'Your farm location request "${request.farmName}" has been automatically approved after 2 minutes.',
          type: 'farm_location_approved',
        );
      }
    } catch (e) {
      throw Exception('Failed to process auto-approvals: $e');
    }
  }

  // Get request by ID
  Future<FarmLocationRequest?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore.collection('farm_location_requests').doc(requestId).get();
      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      return FarmLocationRequest.fromMap(data);
    } catch (e) {
      throw Exception('Failed to get request: $e');
    }
  }

  // Get count of pending requests (for admin notifications)
  Future<int> getPendingRequestsCount() async {
    try {
      final snapshot = await _firestore
          .collection('farm_location_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Stream pending requests for real-time updates
  Stream<List<FarmLocationRequest>> streamPendingRequests() {
    return _firestore
        .collection('farm_location_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FarmLocationRequest.fromMap(data);
      }).toList();
    });
  }

  // Stream current user's requests
  Stream<List<FarmLocationRequest>> streamCurrentUserRequests() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('farm_location_requests')
        .where('requesterId', isEqualTo: user.uid)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FarmLocationRequest.fromMap(data);
      }).toList();
    });
  }
}
