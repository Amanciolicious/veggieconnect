// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  );

  Stream<NavigationState> get stream => _stateController.stream;
  NavigationState get current => _state;

  Future<void> startNavigation({
    required String orderId,
    TravelMode initialMode = TravelMode.walking,
    int recalcEveryMeters = 15,
  }) async {
    _state = _state.copyWith(mode: initialMode, arrived: false, traveledPoints: []);

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
      _state = _state.copyWith(customerLocation: LatLng(initialPos.latitude, initialPos.longitude));
      await _fetchAndApplyRoute();
    }

    LatLng? lastRecalcPoint = _state.customerLocation;

    _positionSubscription = _locationService.positionStream.listen((pos) async {
      final curr = LatLng(pos.latitude, pos.longitude);
      _state = _state.copyWith(customerLocation: curr);

      _updateTraveledPolyline();
      _checkArrivalAndMaybeStop();
      _emit();

      // Recalculate route if moved enough
      final shouldRecalc = lastRecalcPoint == null
          ? true
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

    try {
      final response = await _fetchRouteFromOsrm(start, end, _state.mode);
      if (response == null) return;

      final points = _decodeOsrmPolyline(response['routes'][0]['geometry']);
      final distance = (response['routes'][0]['distance'] as num).toDouble();
      final duration = (response['routes'][0]['duration'] as num).toDouble();
      final steps = _parseOsrmSteps(response);

      _state = _state.copyWith(
        routePoints: points,
        distanceMeters: distance,
        durationSeconds: duration,
        steps: steps,
      );
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

      coordinates.add(LatLng(lat / 1e6, lng / 1e6));
    }
    return coordinates;
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

    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _state.routePoints.length; i++) {
      final d = _distanceMeters(current, _state.routePoints[i]);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }
    final traveled = _state.routePoints.take(closestIdx + 1).toList();
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
      stop();
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


