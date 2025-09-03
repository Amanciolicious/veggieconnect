import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/farm_location.dart';
import 'dart:math';

class FarmLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'farm_locations';

  // Add a new farm location
  Future<void> addFarmLocation(FarmLocation farmLocation) async {
    try {
      await _firestore.collection(_collection).doc(farmLocation.id).set({
        ...farmLocation.toMap(),
        'createdAt': Timestamp.fromDate(farmLocation.createdAt),
      });
    } catch (e) {
      throw Exception('Failed to add farm location: $e');
    }
  }

  // Get all farm locations
  Future<List<FarmLocation>> getAllFarmLocations() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return FarmLocation.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get farm locations: $e');
    }
  }

  // Get farm locations by supplier
  Future<List<FarmLocation>> getFarmLocationsBySupplier(String supplierId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('supplierId', isEqualTo: supplierId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return FarmLocation.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get supplier farm locations: $e');
    }
  }

  // Get farm location by ID
  Future<FarmLocation?> getFarmLocationById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return FarmLocation.fromMap(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get farm location: $e');
    }
  }

  // Update farm location
  Future<void> updateFarmLocation(FarmLocation farmLocation) async {
    try {
      await _firestore.collection(_collection).doc(farmLocation.id).update({
        'name': farmLocation.name,
        'description': farmLocation.description,
        'latitude': farmLocation.latitude,
        'longitude': farmLocation.longitude,
        'address': farmLocation.address,
        'isActive': farmLocation.isActive,
      });
    } catch (e) {
      throw Exception('Failed to update farm location: $e');
    }
  }

  // Delete farm location (soft delete)
  Future<void> deleteFarmLocation(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to delete farm location: $e');
    }
  }

  // Get farm locations within a certain radius
  Future<List<FarmLocation>> getFarmLocationsInRadius({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) async {
    try {
      // Note: This is a simplified approach. For production, consider using
      // Firestore's GeoPoint and geohashing for more efficient geospatial queries
      List<FarmLocation> allLocations = await getAllFarmLocations();
      
      return allLocations.where((location) {
        double distance = _calculateDistance(
          centerLat, centerLng,
          location.latitude, location.longitude,
        );
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get farm locations in radius: $e');
    }
  }

  // Helper method to calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = lat1 * (pi / 180);
    double lat2Rad = lat2 * (pi / 180);
    double deltaLat = (lat2 - lat1) * (pi / 180);
    double deltaLon = (lon2 - lon1) * (pi / 180);

    double a = pow(sin(deltaLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(deltaLon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
} 