// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'location_service.dart';

class MapService {
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  MapController? _mapController;
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _locationSubscription;
  
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  final List<CircleMarker> _circles = [];
  
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePoints = [];
  
  // Getters
  MapController? get mapController => _mapController;
  List<Marker> get markers => _markers;
  List<Polyline> get polylines => _polylines;
  List<CircleMarker> get circles => _circles;
  LatLng? get currentLocation => _currentLocation;
  LatLng? get destinationLocation => _destinationLocation;
  List<LatLng> get routePoints => _routePoints;

  /// Initialize map controller
  void setMapController(MapController controller) {
    _mapController = controller;
  }

  /// Start real-time location tracking on map
  Future<bool> startLocationTracking({
    Function(LatLng)? onLocationUpdate,
    bool showAccuracyCircle = true,
  }) async {
    try {
      // Start location service tracking
      bool trackingStarted = await _locationService.startLocationTracking();
      if (!trackingStarted) {
        return false;
      }

      // Listen to location updates
      _locationSubscription = _locationService.positionStream.listen(
        (Position position) {
          LatLng newLocation = LatLng(position.latitude, position.longitude);
          _currentLocation = newLocation;
          
          // Update current location marker
          _updateCurrentLocationMarker(newLocation, position.accuracy);
          
          // Show accuracy circle if enabled
          if (showAccuracyCircle) {
            _updateAccuracyCircle(newLocation, position.accuracy);
          }
          
          // Move camera to current location
          _moveToLocation(newLocation);
          
          // Callback for location updates
          onLocationUpdate?.call(newLocation);
          
          // Update route if destination is set
          if (_destinationLocation != null) {
            _updateRouteToDestination();
          }
        },
        onError: (error) {
          print('Map location tracking error: $error');
        },
      );

      return true;
    } catch (e) {
      print('Error starting map location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopLocationTracking();
    
    // Remove accuracy circle
    _circles.removeWhere((circle) => circle.key == const ValueKey('accuracy_circle'));
  }

  /// Update current location marker
  void _updateCurrentLocationMarker(LatLng location, double accuracy) {
    _markers.removeWhere((marker) => marker.key == const ValueKey('current_location'));
    
    _markers.add(
      Marker(
        key: const ValueKey('current_location'),
        point: location,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.my_location,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// Update accuracy circle around current location
  void _updateAccuracyCircle(LatLng location, double accuracy) {
    _circles.removeWhere((circle) => circle.key == const ValueKey('accuracy_circle'));
    
    _circles.add(
      CircleMarker(
        key: const ValueKey('accuracy_circle'),
        point: location,
        radius: accuracy,
        color: Colors.blue.withOpacity(0.1),
        borderColor: Colors.blue.withOpacity(0.3),
        borderStrokeWidth: 1,
      ),
    );
  }

  /// Move camera to specific location
  Future<void> _moveToLocation(LatLng location, {double zoom = 16.0}) async {
    if (_mapController != null) {
      _mapController!.move(location, zoom);
    }
  }

  /// Set destination and create route
  Future<void> setDestination(LatLng destination, {String? title, String? snippet}) async {
    _destinationLocation = destination;
    
    // Add destination marker
    _markers.removeWhere((marker) => marker.key == const ValueKey('destination'));
    _markers.add(
      Marker(
        key: const ValueKey('destination'),
        point: destination,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
    
    // Create route if current location is available
    if (_currentLocation != null) {
      await _updateRouteToDestination();
    }
    
    // Adjust camera to show both locations
    if (_currentLocation != null) {
      _fitBothLocations();
    }
  }

  /// Update route to destination
  Future<void> _updateRouteToDestination() async {
    if (_currentLocation == null || _destinationLocation == null) return;
    
    // Create a simple straight line route for cash-on-pickup navigation
    _routePoints = [_currentLocation!, _destinationLocation!];
    
    // Remove existing route polylines
    _polylines.removeWhere((polyline) => polyline.points.length == 2 && 
        polyline.points.first == _currentLocation && 
        polyline.points.last == _destinationLocation);
    
    _polylines.add(
      Polyline(
        points: _routePoints,
        color: const Color(0xFF4CAF50),
        strokeWidth: 4.0,
      ),
    );
  }

  /// Fit camera to show both current location and destination
  void _fitBothLocations() {
    if (_currentLocation == null || _destinationLocation == null || _mapController == null) return;
    
    double minLat = min(_currentLocation!.latitude, _destinationLocation!.latitude);
    double maxLat = max(_currentLocation!.latitude, _destinationLocation!.latitude);
    double minLng = min(_currentLocation!.longitude, _destinationLocation!.longitude);
    double maxLng = max(_currentLocation!.longitude, _destinationLocation!.longitude);
    
    // Add padding
    double latPadding = (maxLat - minLat) * 0.1;
    double lngPadding = (maxLng - minLng) * 0.1;
    
    LatLng southwest = LatLng(minLat - latPadding, minLng - lngPadding);
    LatLng northeast = LatLng(maxLat + latPadding, maxLng + lngPadding);
    
    // Calculate center and zoom to fit bounds
    LatLng center = LatLng(
      (southwest.latitude + northeast.latitude) / 2,
      (southwest.longitude + northeast.longitude) / 2,
    );
    
    _mapController!.move(center, 14.0);
  }

  /// Add custom marker
  void addMarker({
    required String id,
    required LatLng position,
    String? title,
    String? snippet,
    Widget? child,
    VoidCallback? onTap,
  }) {
    _markers.removeWhere((marker) => marker.key == ValueKey(id));
    _markers.add(
      Marker(
        key: ValueKey(id),
        point: position,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: onTap,
          child: child ?? Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.place,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// Remove marker by id
  void removeMarker(String id) {
    _markers.removeWhere((marker) => marker.key == ValueKey(id));
  }

  /// Clear all markers except current location
  void clearMarkers({bool keepCurrentLocation = true}) {
    if (keepCurrentLocation) {
      _markers.removeWhere((marker) => marker.key != const ValueKey('current_location'));
    } else {
      _markers.clear();
    }
  }

  /// Clear route
  void clearRoute() {
    _destinationLocation = null;
    _routePoints.clear();
    _polylines.removeWhere((polyline) => polyline.points.length == 2 && 
        polyline.points.first == _currentLocation && 
        polyline.points.last == _destinationLocation);
    removeMarker('destination');
  }

  /// Get distance to destination in meters
  double? getDistanceToDestination() {
    if (_currentLocation == null || _destinationLocation == null) return null;
    
    return _locationService.calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );
  }

  /// Get bearing to destination in degrees
  double? getBearingToDestination() {
    if (_currentLocation == null || _destinationLocation == null) return null;
    
    return _locationService.calculateBearing(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );
  }

  /// Calculate distance between two points (using existing method from your app)
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLat = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLon = (point2.longitude - point1.longitude) * (pi / 180);

    double a = pow(sin(deltaLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(deltaLon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Get address from coordinates (using existing geocoding)
  Future<String> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';
        if (place.name != null && place.name!.isNotEmpty) address += '${place.name}, ';
        if (place.street != null && place.street!.isNotEmpty) address += '${place.street}, ';
        if (place.subLocality != null && place.subLocality!.isNotEmpty) address += '${place.subLocality}, ';
        if (place.locality != null && place.locality!.isNotEmpty) address += '${place.locality}, ';
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) address += '${place.subAdministrativeArea}, ';
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) address += '${place.administrativeArea}, ';
        if (place.postalCode != null && place.postalCode!.isNotEmpty) address += '${place.postalCode}, ';
        if (place.country != null && place.country!.isNotEmpty) address += '${place.country}';
        
        address = address.trim();
        if (address.endsWith(',')) address = address.substring(0, address.length - 1);
        return address;
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }

  /// Format distance for display
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Check if location is within Bogo City limits (from your existing code)
  bool isWithinBogoCityLimits(LatLng location) {
    const LatLng bogoCenter = LatLng(11.0474, 124.0051);
    const double maxRadius = 5.0; // 5km radius from city center
    
    double distance = calculateDistance(bogoCenter, location);
    return distance <= maxRadius;
  }

  /// Get current location with address
  Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) return null;
      
      LatLng location = LatLng(position.latitude, position.longitude);
      String address = await getAddressFromCoordinates(location);
      
      return {
        'location': location,
        'address': address,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp,
      };
    } catch (e) {
      print('Error getting current location with address: $e');
      return null;
    }
  }

  /// Get coordinates from address
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      print('Error getting coordinates from address: $e');
      return null;
    }
  }

  /// Get route between two points with enhanced routing
  Future<Map<String, dynamic>?> getRoute(LatLng start, LatLng end) async {
    try {
      double distance = calculateDistance(start, end);
      
      // Create a more realistic route with intermediate points for better visualization
      List<LatLng> routePoints = _generateRealisticRoute(start, end, distance);
      
      // Calculate different travel times for walking and driving
      double walkingSpeed = 5.0; // 5 km/h average walking speed
      double drivingSpeed = 30.0; // 30 km/h average local driving speed
      
      int walkingTimeMinutes = (distance / walkingSpeed * 60).round();
      int drivingTimeMinutes = (distance / drivingSpeed * 60).round();
      
      // Add some realistic variation based on distance
      if (distance > 2.0) {
        // For longer distances, add some extra time for traffic/terrain
        drivingTimeMinutes = (drivingTimeMinutes * 1.2).round();
        walkingTimeMinutes = (walkingTimeMinutes * 1.3).round();
      }
      
      return {
        'points': routePoints,
        'distance': distance * 1000, // Convert to meters
        'duration': walkingTimeMinutes * 60, // Default to walking time in seconds
        'distanceText': formatDistance(distance * 1000),
        'durationText': walkingTimeMinutes < 60 
            ? '$walkingTimeMinutes min'
            : '${(walkingTimeMinutes / 60).toStringAsFixed(1)} hr',
        'walkingTime': walkingTimeMinutes,
        'drivingTime': drivingTimeMinutes,
        'walkingTimeText': walkingTimeMinutes < 60 
            ? '$walkingTimeMinutes min'
            : '${(walkingTimeMinutes / 60).toStringAsFixed(1)} hr',
        'drivingTimeText': drivingTimeMinutes < 60 
            ? '$drivingTimeMinutes min'
            : '${(drivingTimeMinutes / 60).toStringAsFixed(1)} hr',
        'geometry': {
          'coordinates': routePoints.map((point) => [point.longitude, point.latitude]).toList(),
        },
      };
    } catch (e) {
      print('Error getting route: $e');
      return null;
    }
  }

  /// Generate a more realistic route with intermediate points
  List<LatLng> _generateRealisticRoute(LatLng start, LatLng end, double distance) {
    List<LatLng> routePoints = [start];
    
    if (distance < 0.5) {
      // For very short distances, just use start and end
      routePoints.add(end);
    } else if (distance < 2.0) {
      // For medium distances, add 1-2 intermediate points
      int intermediatePoints = (distance * 2).round();
      for (int i = 1; i <= intermediatePoints; i++) {
        double ratio = i / (intermediatePoints + 1);
        double lat = start.latitude + (end.latitude - start.latitude) * ratio;
        double lng = start.longitude + (end.longitude - start.longitude) * ratio;
        
        // Add some realistic variation to avoid straight lines
        double variation = 0.0001 * distance; // Small variation based on distance
        lat += (Random().nextDouble() - 0.5) * variation;
        lng += (Random().nextDouble() - 0.5) * variation;
        
        routePoints.add(LatLng(lat, lng));
      }
      routePoints.add(end);
    } else {
      // For longer distances, add more intermediate points
      int intermediatePoints = (distance * 3).round();
      for (int i = 1; i <= intermediatePoints; i++) {
        double ratio = i / (intermediatePoints + 1);
        double lat = start.latitude + (end.latitude - start.latitude) * ratio;
        double lng = start.longitude + (end.longitude - start.longitude) * ratio;
        
        // Add more variation for longer routes
        double variation = 0.0002 * distance;
        lat += (Random().nextDouble() - 0.5) * variation;
        lng += (Random().nextDouble() - 0.5) * variation;
        
        routePoints.add(LatLng(lat, lng));
      }
      routePoints.add(end);
    }
    
    return routePoints;
  }

  /// Get location accuracy from current position
  Future<double?> getLocationAccuracy() async {
    try {
      Position? position = await _locationService.getCurrentLocation();
      return position?.accuracy;
    } catch (e) {
      print('Error getting location accuracy: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
    _mapController = null;
    _markers.clear();
    _polylines.clear();
    _circles.clear();
  }
}