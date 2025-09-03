import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  Position? _lastKnownPosition;
  bool _isTracking = false;

  // Stream to listen to location updates
  Stream<Position> get positionStream => _positionController.stream;
  Position? get lastKnownPosition => _lastKnownPosition;
  bool get isTracking => _isTracking;

  /// Check if location services are enabled on the device
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current location permission status
  Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permissions with proper handling
  Future<LocationPermission> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }

  /// Comprehensive location permission and service check
  Future<LocationServiceResult> checkAndRequestLocationAccess() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationServiceResult(
          success: false,
          message: 'Location services are disabled. Please enable location services in your device settings.',
          errorType: LocationErrorType.serviceDisabled,
        );
      }

      // Check and request permissions
      LocationPermission permission = await checkLocationPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await requestLocationPermission();
      }

      if (permission == LocationPermission.denied) {
        return LocationServiceResult(
          success: false,
          message: 'Location permission denied. Please grant location access to use this feature.',
          errorType: LocationErrorType.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationServiceResult(
          success: false,
          message: 'Location permission permanently denied. Please enable location access in app settings.',
          errorType: LocationErrorType.permissionDeniedForever,
        );
      }

      return LocationServiceResult(
        success: true,
        message: 'Location access granted successfully.',
        errorType: LocationErrorType.none,
      );
    } catch (e) {
      return LocationServiceResult(
        success: false,
        message: 'Error checking location access: ${e.toString()}',
        errorType: LocationErrorType.unknown,
      );
    }
  }

  /// Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      final accessResult = await checkAndRequestLocationAccess();
      if (!accessResult.success) {
        throw Exception(accessResult.message);
      }

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      _lastKnownPosition = position;
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  Future<bool> startLocationTracking() async {
    try {
      if (_isTracking) {
        return true; // Already tracking
      }

      final accessResult = await checkAndRequestLocationAccess();
      if (!accessResult.success) {
        throw Exception(accessResult.message);
      }

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters for real-time tracking
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastKnownPosition = position;
          _positionController.add(position);
        },
        onError: (error) {
          print('Location tracking error: $error');
          _positionController.addError(error);
        },
      );

      _isTracking = true;
      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
  }

  /// Calculate distance between two positions in meters
  double calculateDistance(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculate bearing between two positions
  double calculateBearing(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Open device location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
    _positionController.close();
  }
}

/// Result class for location service operations
class LocationServiceResult {
  final bool success;
  final String message;
  final LocationErrorType errorType;

  LocationServiceResult({
    required this.success,
    required this.message,
    required this.errorType,
  });
}

/// Enum for different types of location errors
enum LocationErrorType {
  none,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unknown,
}
