import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import '../models/supplier_location.dart';
import 'map_service.dart';

class SupplierLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MapService _mapService = MapService();

  // Get all supplier locations
  Future<List<SupplierLocation>> getAllSupplierLocations() async {
    try {
      final snapshot = await _firestore
          .collection('supplier_locations')
          .where('isActive', isEqualTo: true)
          .get();

      final locations = <SupplierLocation>[];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final supplierId = data['supplierId'] ?? '';
        
        // Fetch real-time rating data from suppliers collection
        double? rating;
        int ratingCount = 0;
        
        try {
          final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
          if (supplierDoc.exists) {
            final supplierData = supplierDoc.data()!;
            rating = supplierData['averageRating']?.toDouble();
            ratingCount = supplierData['ratingCount'] ?? 0;
          }
        } catch (e) {
          // If supplier rating fetch fails, use fallback rating from location data
          rating = data['rating']?.toDouble();
        }

        locations.add(SupplierLocation(
          id: doc.id,
          supplierId: supplierId,
          supplierName: data['supplierName'] ?? '',
          locationName: data['locationName'] ?? '',
          description: data['description'] ?? '',
          address: data['address'] ?? '',
          latitude: data['latitude'] ?? 0.0,
          longitude: data['longitude'] ?? 0.0,
          rating: rating,
          ratingCount: ratingCount,
          isActive: data['isActive'] ?? true,
          createdAt: data['createdAt']?.toDate(),
          updatedAt: data['updatedAt']?.toDate(),
        ));
      }

      return locations;
    } catch (e) {
      throw Exception('Failed to get supplier locations: $e');
    }
  }

  // Get supplier location by supplier ID
  Future<SupplierLocation?> getSupplierLocationBySupplierId(String supplierId) async {
    try {
      final snapshot = await _firestore
          .collection('supplier_locations')
          .where('supplierId', isEqualTo: supplierId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final data = snapshot.docs.first.data();
      
      // Fetch real-time rating data from suppliers collection
      double? rating;
      int ratingCount = 0;
      
      try {
        final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
        if (supplierDoc.exists) {
          final supplierData = supplierDoc.data()!;
          rating = supplierData['averageRating']?.toDouble();
          ratingCount = supplierData['ratingCount'] ?? 0;
        }
      } catch (e) {
        // If supplier rating fetch fails, use fallback rating from location data
        rating = data['rating']?.toDouble();
      }

      return SupplierLocation(
        id: snapshot.docs.first.id,
        supplierId: data['supplierId'] ?? '',
        supplierName: data['supplierName'] ?? '',
        locationName: data['locationName'] ?? '',
        description: data['description'] ?? '',
        address: data['address'] ?? '',
        latitude: data['latitude'] ?? 0.0,
        longitude: data['longitude'] ?? 0.0,
        rating: rating,
        ratingCount: ratingCount,
        isActive: data['isActive'] ?? true,
        createdAt: data['createdAt']?.toDate(),
        updatedAt: data['updatedAt']?.toDate(),
      );
    } catch (e) {
      throw Exception('Failed to get supplier location: $e');
    }
  }

  // Create or update supplier location with automatic location detection
  Future<void> createOrUpdateSupplierLocation({
    required String supplierId,
    required String supplierName,
    required String locationName,
    required String description,
    LatLng? location,
    String? address,
  }) async {
    try {
      // If location is not provided, get current device location
      LatLng? finalLocation;
      String? finalAddress;

      if (location != null) {
        finalLocation = location;
        finalAddress = address ?? await _mapService.getAddressFromCoordinates(location);
      } else {
        // Get current device location
        final locationData = await _mapService.getCurrentLocationWithAddress();
        if (locationData != null) {
          finalLocation = locationData['location'] as LatLng?;
          finalAddress = locationData['address'] as String?;
          
          if (finalLocation == null || finalAddress == null) {
            throw Exception('Failed to get current location');
          }
        } else {
          throw Exception('Failed to get current location');
        }
      }

      // Validate if location is within Bogo City limits
      if (!_mapService.isWithinBogoCityLimits(finalLocation)) {
        throw Exception('Location must be within Bogo City limits');
      }

      // Check if supplier location already exists
      final existingLocation = await getSupplierLocationBySupplierId(supplierId);

      if (existingLocation != null) {
        // Update existing location
        await _firestore
            .collection('supplier_locations')
            .doc(existingLocation.id)
            .update({
          'locationName': locationName,
          'description': description,
          'address': finalAddress,
          'latitude': finalLocation.latitude,
          'longitude': finalLocation.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new location
        await _firestore.collection('supplier_locations').add({
          'supplierId': supplierId,
          'supplierName': supplierName,
          'locationName': locationName,
          'description': description,
          'address': finalAddress,
          'latitude': finalLocation.latitude,
          'longitude': finalLocation.longitude,
          'rating': 0.0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to create/update supplier location: $e');
    }
  }

  // Update supplier location manually (for suppliers to edit their location)
  Future<void> updateSupplierLocation({
    required String supplierId,
    required LatLng newLocation,
    String? newAddress,
    String? newLocationName,
    String? newDescription,
  }) async {
    try {
      // Validate if location is within Bogo City limits
      if (!_mapService.isWithinBogoCityLimits(newLocation)) {
        throw Exception('Location must be within Bogo City limits');
      }

      final existingLocation = await getSupplierLocationBySupplierId(supplierId);
      if (existingLocation == null) {
        throw Exception('Supplier location not found');
      }

      final finalAddress = newAddress ?? await _mapService.getAddressFromCoordinates(newLocation);

      await _firestore
          .collection('supplier_locations')
          .doc(existingLocation.id)
          .update({
        if (newLocationName != null) 'locationName': newLocationName,
        if (newDescription != null) 'description': newDescription,
        'address': finalAddress,
        'latitude': newLocation.latitude,
        'longitude': newLocation.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update supplier location: $e');
    }
  }

  // Delete supplier location
  Future<void> deleteSupplierLocation(String supplierId) async {
    try {
      final existingLocation = await getSupplierLocationBySupplierId(supplierId);
      if (existingLocation == null) {
        throw Exception('Supplier location not found');
      }

      await _firestore
          .collection('supplier_locations')
          .doc(existingLocation.id)
          .update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete supplier location: $e');
    }
  }

  // Get nearby supplier locations
  Future<List<SupplierLocation>> getNearbySupplierLocations({
    required LatLng userLocation,
    required double radiusKm,
  }) async {
    try {
      final allLocations = await getAllSupplierLocations();
      
      return allLocations.where((location) {
        final distance = _mapService.calculateDistance(
          userLocation,
          LatLng(location.latitude, location.longitude),
        );
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get nearby supplier locations: $e');
    }
  }

  // Get current user's supplier location (if they are a supplier)
  Future<SupplierLocation?> getCurrentUserSupplierLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      return await getSupplierLocationBySupplierId(user.uid);
    } catch (e) {
      throw Exception('Failed to get current user supplier location: $e');
    }
  }

  // Check if current user has a supplier location
  Future<bool> hasCurrentUserSupplierLocation() async {
    try {
      final location = await getCurrentUserSupplierLocation();
      return location != null;
    } catch (e) {
      return false;
    }
  }

  // Get location accuracy for current user
  Future<Map<String, dynamic>?> getCurrentLocationAccuracy() async {
    try {
      final locationData = await _mapService.getCurrentLocationWithAddress();
      if (locationData != null) {
        return {
          'accuracy': locationData['accuracy'],
          'timestamp': locationData['timestamp'],
          'location': locationData['location'],
        };
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get location accuracy: $e');
    }
  }

  // Start real-time location tracking for suppliers
  Future<bool> startLocationTracking() {
    return _mapService.startLocationTracking();
  }
} 