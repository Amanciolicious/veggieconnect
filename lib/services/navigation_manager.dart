// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'location_service.dart';
import 'notification_service.dart';

enum TravelMode { driving, walking }

class NavigationStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;

  NavigationStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class NavigationState {
  final LatLng? customerLocation;
  final LatLng? supplierLocation;
  final List<LatLng> routePoints;
  final List<LatLng> traveledPoints;
  final double distanceMeters;
  final double durationSeconds;
  final List<NavigationStep> steps;
  final TravelMode mode;
  final bool arrived;
  final bool isRouteLocked;
  final String? lockedOrderId;
  final String? lockedSupplierId;

  NavigationState({
    required this.customerLocation,
    required this.supplierLocation,
    required this.routePoints,
    required this.traveledPoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    required this.mode,
    required this.arrived,
    required this.isRouteLocked,
    this.lockedOrderId,
    this.lockedSupplierId,
  });

  NavigationState copyWith({
    LatLng? customerLocation,
    LatLng? supplierLocation,
    List<LatLng>? routePoints,
    List<LatLng>? traveledPoints,
    double? distanceMeters,
    double? durationSeconds,
    List<NavigationStep>? steps,
    TravelMode? mode,
    bool? arrived,
    bool? isRouteLocked,
    String? lockedOrderId,
    String? lockedSupplierId,
  }) {
    return NavigationState(
      customerLocation: customerLocation ?? this.customerLocation,
      supplierLocation: supplierLocation ?? this.supplierLocation,
      routePoints: routePoints ?? this.routePoints,
      traveledPoints: traveledPoints ?? this.traveledPoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      steps: steps ?? this.steps,
      mode: mode ?? this.mode,
      arrived: arrived ?? this.arrived,
      isRouteLocked: isRouteLocked ?? this.isRouteLocked,
      lockedOrderId: lockedOrderId ?? this.lockedOrderId,
      lockedSupplierId: lockedSupplierId ?? this.lockedSupplierId,
    );
  }
}

class NavigationManager {
  static final NavigationManager _instance = NavigationManager._internal();
  factory NavigationManager() => _instance;
  NavigationManager._internal();

  final LocationService _locationService = LocationService();
  final _stateController = StreamController<NavigationState>.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  
  // Cache for routes to avoid repeated API calls
  final Map<String, Map<String, dynamic>> _routeCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  // Realistic speeds (meters per second)
  static const double _walkingSpeedMps = 1.3;   // ~4.7 km/h
  static const double _drivingSpeedMps = 11.11; // 40 km/h
  static const String _prefsModeKey = 'navigation_last_travel_mode';

  NavigationState _state = NavigationState(
    customerLocation: null,
    supplierLocation: null,
    routePoints: const [],
    traveledPoints: const [],
    distanceMeters: 0,
    durationSeconds: 0,
    steps: const [],
    mode: TravelMode.walking,
    arrived: false,
    isRouteLocked: false,
    lockedOrderId: null,
    lockedSupplierId: null,
  );

  Stream<NavigationState> get stream => _stateController.stream;
  NavigationState get current => _state;

  Future<void> startNavigation({
    required String orderId,
    required String customerUserId,
    TravelMode initialMode = TravelMode.walking,
    int recalcEveryMeters = 8,
  }) async {
    _currentOrderId = orderId;
    _currentUserId = customerUserId;
    
    // Check if this order is in "ready_to_pickup" status to lock the route
    final isReadyForPickup = await _checkIfOrderIsReadyForPickup(orderId);
    final supplierId = await _getSupplierIdFromOrder(orderId);
    
    // Load last saved mode; fall back to provided initialMode
    final savedMode = await _loadSavedMode();
    final modeToUse = savedMode ?? initialMode;

    _state = _state.copyWith(
      mode: modeToUse, 
      arrived: false, 
      traveledPoints: [],
      isRouteLocked: isReadyForPickup,
      lockedOrderId: isReadyForPickup ? orderId : null,
      lockedSupplierId: isReadyForPickup ? supplierId : null,
    );

    final supplier = await _fetchSupplierPickupForOrder(orderId);
    if (supplier == null) {
      print('No supplier location found for order $orderId');
      return;
    }
    _state = _state.copyWith(supplierLocation: supplier);
    _emit();

    final hasTracking = await _locationService.startLocationTracking();
    if (!hasTracking) return;

    // Initial customer location
    final initialPos = _locationService.lastKnownPosition ?? await _locationService.getCurrentLocation();
    if (initialPos != null) {
      // Validate GPS coordinates before using them
      if (_isValidCoordinate(initialPos.latitude, initialPos.longitude)) {
        _state = _state.copyWith(customerLocation: LatLng(initialPos.latitude, initialPos.longitude));
        // Fetch route immediately when both locations are available
        await _fetchAndApplyRoute();
      } else {
        print('Invalid GPS coordinates: lat=${initialPos.latitude}, lng=${initialPos.longitude}');
      }
    }

    LatLng? lastRecalcPoint = _state.customerLocation;
    DateTime lastRecalcTime = DateTime.now();

    _positionSubscription = _locationService.positionStream.listen((pos) async {
      // Validate GPS coordinates before using them
      if (!_isValidCoordinate(pos.latitude, pos.longitude)) {
        print('Invalid GPS position update: lat=${pos.latitude}, lng=${pos.longitude} - skipping');
        return;
      }
      
      final curr = LatLng(pos.latitude, pos.longitude);
      _state = _state.copyWith(customerLocation: curr);

      // If this is the first location update and we have supplier location, fetch route immediately
      if (lastRecalcPoint == null && _state.supplierLocation != null) {
        await _fetchAndApplyRoute();
      }

      _updateTraveledPolyline();
      _checkArrivalAndMaybeStop();
      _emit();

      // Recalculate route if moved enough OR a time window elapsed (to stay accurate in traffic or map updates)
      final shouldRecalc = lastRecalcPoint == null
          ? false // Already handled above
          : _distanceMeters(lastRecalcPoint!, curr) >= recalcEveryMeters ||
            DateTime.now().difference(lastRecalcTime) >= const Duration(seconds: 5);
      if (shouldRecalc) {
        lastRecalcPoint = curr;
        lastRecalcTime = DateTime.now();
        await _fetchAndApplyRoute();
      }
    });
  }

  Future<void> changeMode(TravelMode mode) async {
    if (_state.mode == mode) return;
    print('Changing mode from ${_state.mode} to $mode');
    
    // Update mode immediately and emit state
    _state = _state.copyWith(mode: mode);
    _emit();

    // Persist selection
    await _saveMode(mode);
    
    // Invalidate any cached route for current start/end and this mode to force fresh fetch
    final start = _state.customerLocation;
    final end = _state.supplierLocation;
    if (start != null && end != null) {
      _invalidateCacheFor(start, end, mode);
    }

    // Show loading state
    _state = _state.copyWith(
      routePoints: [],
      steps: [NavigationStep(
        instruction: 'Calculating route...',
        distanceMeters: 0,
        durationSeconds: 0,
      )],
    );
    _emit();
    
    // Fetch new route
    await _fetchAndApplyRoute();
    print('Mode change completed. New mode: ${_state.mode}, Distance: ${_state.distanceMeters}m, Duration: ${_state.durationSeconds}s');
  }

  Future<void> stop() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationService.stopLocationTracking();
  }

  Future<LatLng?> _fetchSupplierPickupForOrder(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      final lat = (data?['pickupLat'] as num?)?.toDouble();
      final lng = (data?['pickupLng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      
      // Validate coordinates before creating LatLng
      if (!_isValidCoordinate(lat, lng)) {
        print('Invalid supplier pickup coordinates: lat=$lat, lng=$lng');
        return null;
      }
      
      return LatLng(lat, lng);
    } catch (e) {
      print('Error fetching supplier pickup: $e');
      return null;
    }
  }

  Future<void> _fetchAndApplyRoute() async {
    final start = _state.customerLocation;
    final end = _state.supplierLocation;
    if (start == null || end == null) {
      print('Cannot fetch route: missing locations');
      return;
    }
    final currentMode = _state.mode;
    print('Fetching route for mode: $currentMode');
    
    // Validate both coordinates before fetching route
    if (!_isValidCoordinate(start.latitude, start.longitude) || 
        !_isValidCoordinate(end.latitude, end.longitude)) {
      print('Invalid coordinates for route: start=(${start.latitude}, ${start.longitude}), end=(${end.latitude}, ${end.longitude})');
      return;
    }

    // Check if locations are very close (less than 50 meters)
    final distance = _distanceMeters(start, end);
    if (distance < 50) {
      print('Locations are very close ($distance meters), creating direct route');
      
      // Calculate duration based on selected mode
      final speed = currentMode == TravelMode.driving ? _drivingSpeedMps : _walkingSpeedMps;
      final duration = distance / speed;
      
      // Create a simple direct route for very close locations
      _state = _state.copyWith(
        routePoints: [start, end],
        distanceMeters: distance,
        durationSeconds: duration,
        steps: [
          NavigationStep(
            instruction: _state.mode == TravelMode.driving 
                ? 'Drive directly to destination'
                : 'Walk directly to destination',
            distanceMeters: distance,
            durationSeconds: duration,
          ),
        ],
      );
      _updateTraveledPolyline();
      _emit();
      
      // Check for immediate arrival if very close
      if (distance <= 30) {
        _state = _state.copyWith(arrived: true);
        _emit();
        _sendArrivalNotification();
      }
      return;
    }

    try {
      print('Fetching route from OSRM: start=(${start.latitude}, ${start.longitude}), end=(${end.latitude}, ${end.longitude})');
      final response = await _fetchRouteFromOsrm(start, end, currentMode);
      if (response == null) {
        print('OSRM response is null, creating fallback route');
        
        // Calculate duration based on selected mode
        final speed = currentMode == TravelMode.driving ? _drivingSpeedMps : _walkingSpeedMps;
        final duration = distance / speed;
        
        // Create fallback route with more detailed instructions
        final steps = <NavigationStep>[];
        
        if (distance < 100) {
          // Very short distance
          steps.add(NavigationStep(
            instruction: currentMode == TravelMode.driving 
                ? 'Drive directly to destination'
                : 'Walk directly to destination',
            distanceMeters: distance,
            durationSeconds: duration,
          ));
        } else if (distance < 500) {
          // Short distance
          steps.addAll([
            NavigationStep(
              instruction: currentMode == TravelMode.driving 
                  ? 'Start driving towards destination'
                  : 'Start walking towards destination',
              distanceMeters: distance * 0.3,
              durationSeconds: duration * 0.3,
            ),
            NavigationStep(
              instruction: currentMode == TravelMode.driving 
                  ? 'Continue driving to destination'
                  : 'Continue walking to destination',
              distanceMeters: distance * 0.7,
              durationSeconds: duration * 0.7,
            ),
          ]);
        } else {
          // Longer distance
          steps.addAll([
            NavigationStep(
              instruction: currentMode == TravelMode.driving 
                  ? 'Start driving towards destination'
                  : 'Start walking towards destination',
              distanceMeters: distance * 0.2,
              durationSeconds: duration * 0.2,
            ),
            NavigationStep(
              instruction: currentMode == TravelMode.driving 
                  ? 'Continue driving on main road'
                  : 'Continue walking on main path',
              distanceMeters: distance * 0.6,
              durationSeconds: duration * 0.6,
            ),
            NavigationStep(
              instruction: currentMode == TravelMode.driving 
                  ? 'Approach destination'
                  : 'Approach destination',
              distanceMeters: distance * 0.2,
              durationSeconds: duration * 0.2,
            ),
          ]);
        }
        
        _state = _state.copyWith(
          routePoints: [start, end],
          distanceMeters: distance,
          durationSeconds: duration,
          steps: steps,
        );
        _updateTraveledPolyline();
        _emit();
        return;
      }

      final geometry = response['routes'][0]['geometry'] as String;
      print('OSRM geometry received: ${geometry.length} characters');
      
      // Check if geometry is too short (likely malformed for close distances)
      if (geometry.length < 10) {
        print('Geometry too short, creating direct route');
        
        // Calculate duration based on selected mode
        final speed = currentMode == TravelMode.driving ? _drivingSpeedMps : _walkingSpeedMps;
        final duration = distance / speed;
        
        _state = _state.copyWith(
          routePoints: [start, end],
          distanceMeters: distance,
          durationSeconds: duration,
          steps: [
            NavigationStep(
              instruction: currentMode == TravelMode.driving 
                  ? 'Drive directly to destination'
                  : 'Walk directly to destination',
              distanceMeters: distance,
              durationSeconds: duration,
            ),
          ],
        );
        _updateTraveledPolyline();
        _emit();
        return;
      }
      
      final points = _decodeOsrmPolyline(geometry);
      final routeDistance = (response['routes'][0]['distance'] as num).toDouble();
      // Always compute display duration using realistic speed per mode so
      // walking is slower than driving even on very short routes.
      final speed = currentMode == TravelMode.driving ? _drivingSpeedMps : _walkingSpeedMps; // m/s
      final double duration = routeDistance / speed;
      final steps = _parseOsrmSteps(response);
      
      print('OSRM route fetched: Distance=${routeDistance}m, Duration=${duration}s, Steps=${steps.length}');

      // Validate route points before applying
      final validRoute = points.where((point) => _isValidCoordinate(point.latitude, point.longitude)).toList();
      // Ensure the polyline starts with current position for smooth traveled fade
      if (validRoute.isNotEmpty && _state.customerLocation != null) {
        if (_distanceMeters(_state.customerLocation!, validRoute.first) > 5) {
          validRoute.insert(0, _state.customerLocation!);
        }
      }
      
      if (validRoute.isEmpty) {
        print('No valid route points found, creating fallback route');
        // Create a simple straight-line route as fallback
        final fallbackRoute = [start, end];
        _state = _state.copyWith(
          routePoints: fallbackRoute,
          distanceMeters: routeDistance,
          durationSeconds: duration,
          steps: steps,
        );
      } else {
        _state = _state.copyWith(
          routePoints: validRoute,
          distanceMeters: routeDistance,
          durationSeconds: duration,
          steps: steps,
        );
      }
      _updateTraveledPolyline();
      _emit();
      print('Route applied: Mode=$currentMode, Distance=${_state.distanceMeters}m, Duration=${_state.durationSeconds}s');
    } catch (e) {
      print('OSRM routing failed: $e');
      
      // Calculate duration based on selected mode
      final speed = currentMode == TravelMode.driving ? _drivingSpeedMps : _walkingSpeedMps;
      final duration = distance / speed;
      
      // Create fallback route on any error
      _state = _state.copyWith(
        routePoints: [start, end],
        distanceMeters: distance,
        durationSeconds: duration,
        steps: [
          NavigationStep(
            instruction: currentMode == TravelMode.driving 
                ? 'Drive to destination'
                : 'Walk to destination',
            distanceMeters: distance,
            durationSeconds: duration,
          ),
        ],
      );
      _updateTraveledPolyline();
      _emit();
    }
  }

  Future<Map<String, dynamic>?> _fetchRouteFromOsrm(LatLng start, LatLng end, TravelMode mode) async {
    try {
      final profile = mode == TravelMode.driving ? 'driving' : 'foot';
      final cacheKey = '${start.latitude},${start.longitude}-${end.latitude},${end.longitude}-$profile';
      
      // Check cache first
      if (_routeCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null && DateTime.now().difference(cacheTime) < _cacheExpiry) {
          print('Using cached route for $profile mode');
          return _routeCache[cacheKey];
        } else {
          // Remove expired cache
          _routeCache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
      }
      
      final url = Uri.parse('https://router.project-osrm.org/route/v1/$profile/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=polyline6&steps=true');
      print('OSRM URL: $url');
      
      final res = await http.get(url, headers: { 
        'Accept': 'application/json',
        'User-Agent': 'VeggieConnect/1.0',
      }).timeout(Duration(seconds: 8));
      
      if (res.statusCode != 200) {
        print('OSRM error: ${res.statusCode} ${res.body}');
        return null;
      }
      
      final result = json.decode(res.body) as Map<String, dynamic>;
      
      // Check if the response has valid route data
      if (result['code'] != 'Ok') {
        print('OSRM returned error code: ${result['code']}');
        return null;
      }
      
      final routes = result['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        print('OSRM returned no routes');
        return null;
      }
      
      // Cache the result
      _routeCache[cacheKey] = result;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      print('OSRM response received for $profile mode: ${routes.length} routes');
      return result;
    } catch (e) {
      print('OSRM API call failed: $e');
      return null;
    }
  }

  void _invalidateCacheFor(LatLng start, LatLng end, TravelMode mode) {
    final profile = mode == TravelMode.driving ? 'driving' : 'foot';
    final cacheKey = '${start.latitude},${start.longitude}-${end.latitude},${end.longitude}-$profile';
    if (_routeCache.containsKey(cacheKey)) {
      _routeCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      print('Invalidated route cache for key: $cacheKey');
    }
  }

  List<LatLng> _decodeOsrmPolyline(String encoded) {
    // Polyline6 decoder with proper bounds checking
    int index = 0, lat = 0, lng = 0;
    final List<LatLng> coordinates = [];

    try {
      while (index < encoded.length) {
        int b, shift = 0, result = 0;
        
        // Decode latitude with bounds checking
        do {
          if (index >= encoded.length) {
            print('Polyline decoding error: index $index exceeds string length ${encoded.length}');
            return coordinates; // Return what we have so far
          }
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < encoded.length);
        
        int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        lat += dlat;

        shift = 0;
        result = 0;
        
        // Decode longitude with bounds checking
        do {
          if (index >= encoded.length) {
            print('Polyline decoding error: index $index exceeds string length ${encoded.length}');
            return coordinates; // Return what we have so far
          }
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < encoded.length);
        
        int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        lng += dlng;

        final decodedLat = lat / 1e6;
        final decodedLng = lng / 1e6;
        
        // Validate coordinates before adding
        if (_isValidCoordinate(decodedLat, decodedLng)) {
          coordinates.add(LatLng(decodedLat, decodedLng));
        } else {
          print('Invalid coordinate detected in polyline: lat=$decodedLat, lng=$decodedLng - skipping');
        }
      }
    } catch (e) {
      print('Error decoding polyline: $e');
      print('Encoded string length: ${encoded.length}, current index: $index');
      // Return coordinates decoded so far instead of empty list
    }
    
    return coordinates;
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  List<NavigationStep> _parseOsrmSteps(Map<String, dynamic> jsonBody) {
    try {
      final routes = jsonBody['routes'] as List;
      if (routes.isEmpty) return [];
      
      final legs = routes.first['legs'] as List;
      final List<NavigationStep> steps = [];
      
      for (final leg in legs) {
        final legSteps = leg['steps'] as List;
        for (final step in legSteps) {
          final maneuver = step['maneuver'];
          final streetName = step['name'] as String?;
          final distance = (step['distance'] as num).toDouble();
          final duration = (step['duration'] as num).toDouble();
          
          // Only include steps with meaningful distance (more than 10 meters)
          if (distance > 10) {
            final instruction = _formatInstruction(maneuver, streetName);
            steps.add(NavigationStep(
              instruction: instruction,
              distanceMeters: distance,
              durationSeconds: duration,
            ));
          }
        }
      }
      
      // If no meaningful steps found, create a simple direct route
      if (steps.isEmpty) {
        final totalDistance = (routes.first['distance'] as num).toDouble();
        final totalDuration = (routes.first['duration'] as num).toDouble();
        steps.add(NavigationStep(
          instruction: 'Follow the route to your destination',
          distanceMeters: totalDistance,
          durationSeconds: totalDuration,
        ));
      }
      
      return steps;
    } catch (e) {
      print('Error parsing OSRM steps: $e');
      return [];
    }
  }

  String _formatInstruction(dynamic maneuver, String? street) {
    try {
      final type = (maneuver['type'] as String?) ?? 'continue';
      final modifier = (maneuver['modifier'] as String?) ?? '';
      
      // Use street name if available, otherwise use generic direction
      String streetName = (street ?? '').trim();
      if (streetName.isEmpty) {
        streetName = 'the road';
      }
      
      switch (type) {
        case 'depart':
          return streetName.isNotEmpty ? 'Start on $streetName' : 'Start your journey';
        case 'arrive':
          return 'Arrive at your destination';
        case 'turn':
          if (modifier.isNotEmpty) {
            return 'Turn $modifier onto $streetName';
          } else {
            return 'Turn onto $streetName';
          }
        case 'new name':
          return 'Continue on $streetName';
        case 'roundabout':
          return 'Enter roundabout and take exit onto $streetName';
        case 'merge':
          return 'Merge onto $streetName';
        case 'ramp':
          return 'Take ramp onto $streetName';
        case 'fork':
          return 'Keep $modifier at fork onto $streetName';
        case 'end of road':
          return 'At end of road, turn $modifier onto $streetName';
        case 'continue':
          return 'Continue straight on $streetName';
        case 'notification':
          return 'Continue on $streetName';
        default:
          return 'Continue on $streetName';
      }
    } catch (e) {
      print('Error formatting instruction: $e');
      return 'Continue on the road';
    }
  }

  void _updateTraveledPolyline() {
    final current = _state.customerLocation;
    if (current == null || _state.routePoints.isEmpty) return;

    // Find the closest point on the route to current location
    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _state.routePoints.length; i++) {
      final d = _distanceMeters(current, _state.routePoints[i]);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    // Create traveled path up to the closest point, plus current location
    final traveled = <LatLng>[];
    
    // Add all route points up to the closest point
    for (int i = 0; i <= closestIdx; i++) {
      traveled.add(_state.routePoints[i]);
    }
    
    // Add current location if it's significantly different from the closest route point
    if (minDist > 10) { // 10 meters threshold
      traveled.add(current);
    }

    _state = _state.copyWith(traveledPoints: traveled);
  }

  void _checkArrivalAndMaybeStop() {
    final current = _state.customerLocation;
    final dest = _state.supplierLocation;
    if (current == null || dest == null || _state.arrived) return;

    final d = _distanceMeters(current, dest);
    if (d <= 30) {
      _state = _state.copyWith(arrived: true);
      _emit();
      
      // Send arrival notification immediately
      _sendArrivalNotification();
      
      // Don't stop tracking immediately - let user confirm pickup
      // Route remains locked until order is marked as picked up
    }
  }

  // Method to lock route for a specific order
  Future<void> lockRouteForOrder(String orderId, String supplierId) async {
    _state = _state.copyWith(
      isRouteLocked: true,
      lockedOrderId: orderId,
      lockedSupplierId: supplierId,
    );
    _emit();
  }

  // Method to unlock route when order is completed
  Future<void> unlockRoute() async {
    _state = _state.copyWith(
      isRouteLocked: false,
      lockedOrderId: null,
      lockedSupplierId: null,
    );
    _emit();
  }

  // Method to check if route is locked for a specific order
  bool isRouteLockedForOrder(String orderId) {
    return _state.isRouteLocked && _state.lockedOrderId == orderId;
  }

  Future<void> _sendArrivalNotification() async {
    try {
      // Send notification to customer's device
      await NotificationService().sendFCMNotification(
        recipientId: _getCurrentUserId(),
        title: '🎉 You\'ve Arrived!',
        body: 'You have reached the pickup location. Your order is ready for collection.',
        type: 'arrival_confirmation',
        data: {
          'orderId': _getCurrentOrderId(),
          'screen': 'navigation',
          'arrivalTime': DateTime.now().toIso8601String(),
        },
      );
      
      print('Arrival notification sent to customer');
    } catch (e) {
      print('Error sending arrival notification: $e');
    }
  }

  String _getCurrentUserId() {
    // This would typically come from the order data or current user context
    // For now, we'll need to pass this through the navigation manager
    return _currentUserId ?? '';
  }

  String _getCurrentOrderId() {
    return _currentOrderId ?? '';
  }

  String? _currentUserId;
  String? _currentOrderId;

  Future<bool> _checkIfOrderIsReadyForPickup(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (!doc.exists) return false;
      final data = doc.data();
      final status = data?['status'] as String?;
      return status == 'ready_to_pickup';
    } catch (e) {
      print('Error checking order status: $e');
      return false;
    }
  }

  Future<String?> _getSupplierIdFromOrder(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      return data?['sellerId'] as String?;
    } catch (e) {
      print('Error getting supplier ID: $e');
      return null;
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  void _emit() {
    if (!_stateController.isClosed) {
      print('Emitting state: Mode=${_state.mode}, Distance=${_state.distanceMeters}m, Duration=${_state.durationSeconds}s');
      _stateController.add(_state);
    } else {
      print('State controller is closed, cannot emit state');
    }
  }

  Future<void> sendArrivalConfirmation({
    required String orderId,
    required String recipientUserId,
  }) async {
    await NotificationService().sendFCMNotification(
      recipientId: recipientUserId,
      title: 'Arrival Confirmed',
      body: 'Customer has arrived for order #$orderId',
      type: 'arrival_confirmation',
      data: {
        'orderId': orderId,
        'screen': 'order_details',
      },
    );
  }

  // Clear cache when needed
  void clearCache() {
    _routeCache.clear();
    _cacheTimestamps.clear();
    print('Route cache cleared');
  }

  // Force refresh current route
  Future<void> refreshRoute() async {
    print('Refreshing current route...');
    await _fetchAndApplyRoute();
  }

  void dispose() {
    _stateController.close();
    stop();
  }

  // Persistence helpers
  Future<void> _saveMode(TravelMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsModeKey, mode == TravelMode.driving ? 'driving' : 'walking');
    } catch (_) {}
  }

  Future<TravelMode?> _loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefsModeKey);
      if (v == 'driving') return TravelMode.driving;
      if (v == 'walking') return TravelMode.walking;
      return null;
    } catch (_) {
      return null;
    }
  }
}
