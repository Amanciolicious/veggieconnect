// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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
    int recalcEveryMeters = 15,
  }) async {
    _currentOrderId = orderId;
    _currentUserId = customerUserId;
    
    // Check if this order is in "ready_to_pickup" status to lock the route
    final isReadyForPickup = await _checkIfOrderIsReadyForPickup(orderId);
    final supplierId = await _getSupplierIdFromOrder(orderId);
    
    _state = _state.copyWith(
      mode: initialMode, 
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

      // Recalculate route if moved enough
      final shouldRecalc = lastRecalcPoint == null
          ? false // Already handled above
          : _distanceMeters(lastRecalcPoint!, curr) >= recalcEveryMeters;
      if (shouldRecalc) {
        lastRecalcPoint = curr;
        await _fetchAndApplyRoute();
      }
    });
  }

  Future<void> changeMode(TravelMode mode) async {
    if (_state.mode == mode) return;
    _state = _state.copyWith(mode: mode);
    await _fetchAndApplyRoute();
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
    if (start == null || end == null) return;
    
    // Validate both coordinates before fetching route
    if (!_isValidCoordinate(start.latitude, start.longitude) || 
        !_isValidCoordinate(end.latitude, end.longitude)) {
      print('Invalid coordinates for route: start=(${start.latitude}, ${start.longitude}), end=(${end.latitude}, ${end.longitude})');
      return;
    }

    try {
      print('Fetching route from OSRM: start=(${start.latitude}, ${start.longitude}), end=(${end.latitude}, ${end.longitude})');
      final response = await _fetchRouteFromOsrm(start, end, _state.mode);
      if (response == null) return;

      final geometry = response['routes'][0]['geometry'] as String;
      print('OSRM geometry received: ${geometry.substring(0, 50)}...');
      final points = _decodeOsrmPolyline(geometry);
      final distance = (response['routes'][0]['distance'] as num).toDouble();
      final duration = (response['routes'][0]['duration'] as num).toDouble();
      final steps = _parseOsrmSteps(response);

      // Validate route points before applying
      final validRoute = points.where((point) => _isValidCoordinate(point.latitude, point.longitude)).toList();
      
      if (validRoute.isEmpty) {
        print('No valid route points found, creating fallback route');
        // Create a simple straight-line route as fallback
        final fallbackRoute = [start, end];
        _state = _state.copyWith(
          routePoints: fallbackRoute,
          distanceMeters: distance,
          durationSeconds: duration,
          steps: steps,
        );
      } else {
        _state = _state.copyWith(
          routePoints: validRoute,
          distanceMeters: distance,
          durationSeconds: duration,
          steps: steps,
        );
      }
      _updateTraveledPolyline();
      _emit();
    } catch (e) {
      print('OSRM routing failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchRouteFromOsrm(LatLng start, LatLng end, TravelMode mode) async {
    final profile = mode == TravelMode.driving ? 'driving' : 'foot';
    final url = Uri.parse('https://router.project-osrm.org/route/v1/$profile/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=polyline6&steps=true');
    final res = await http.get(url, headers: { 'Accept': 'application/json' });
    if (res.statusCode != 200) {
      print('OSRM error: ${res.statusCode} ${res.body}');
      return null;
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  List<LatLng> _decodeOsrmPolyline(String encoded) {
    // Polyline6 decoder
    int index = 0, lat = 0, lng = 0;
    final List<LatLng> coordinates = [];

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final decodedLat = lat / 1e6;
      final decodedLng = lng / 1e6;
      
      // Validate coordinates before adding
      if (_isValidCoordinate(decodedLat, decodedLng)) {
        coordinates.add(LatLng(decodedLat, decodedLng));
      } else {
        print('Invalid coordinate detected in polyline: lat=$decodedLat, lng=$decodedLng - skipping');
        print('Raw values: lat=$lat, lng=$lng, encoded=$encoded');
      }
    }
    return coordinates;
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  List<NavigationStep> _parseOsrmSteps(Map<String, dynamic> jsonBody) {
    final legs = (jsonBody['routes'] as List).first['legs'] as List;
    final List<NavigationStep> steps = [];
    for (final leg in legs) {
      for (final step in (leg['steps'] as List)) {
        final maneuver = step['maneuver'];
        final instruction = _formatInstruction(maneuver, step['name']);
        steps.add(NavigationStep(
          instruction: instruction,
          distanceMeters: (step['distance'] as num).toDouble(),
          durationSeconds: (step['duration'] as num).toDouble(),
        ));
      }
    }
    return steps;
  }

  String _formatInstruction(dynamic maneuver, String? street) {
    try {
      final type = (maneuver['type'] as String?) ?? 'continue';
      final modifier = (maneuver['modifier'] as String?) ?? '';
      final name = (street ?? '').isEmpty ? '' : ' onto $street';
      switch (type) {
        case 'depart':
          return 'Start$name';
        case 'arrive':
          return 'Arrive at destination';
        case 'turn':
          return 'Turn ${modifier.isNotEmpty ? modifier : ''}$name'.trim();
        case 'new name':
          return 'Continue$name';
        case 'roundabout':
          return 'Enter roundabout$name';
        default:
          return 'Continue$name';
      }
    } catch (_) {
      return 'Continue';
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
      _stateController.add(_state);
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

  void dispose() {
    _stateController.close();
    stop();
  }
}


