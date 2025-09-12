// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/navigation_manager.dart';
import '../widgets/lottie_loading_widget.dart';

class NavigationScreen extends StatefulWidget {
  final String orderId;
  final String supplierName;
  final String? supplierUserId; // for arrival confirmation
  final String? customerUserId; // for arrival notifications

  const NavigationScreen({
    super.key,
    required this.orderId,
    required this.supplierName,
    this.supplierUserId,
    this.customerUserId,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with TickerProviderStateMixin {
  final NavigationManager _manager = NavigationManager();
  final MapController _mapController = MapController();
  late StreamSubscription _sub;
  NavigationState? _state;
  bool _hasInitialized = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    
    _sub = _manager.stream.listen((s) async {
      setState(() => _state = s);
      
      // Auto-zoom to fit route when first loaded
      if (!_hasInitialized && s.customerLocation != null && s.supplierLocation != null) {
        _hasInitialized = true;
        _fitToRoute();
      }
      
      // Smoothly follow customer location as they move
      if (s.customerLocation != null && _hasInitialized) {
        _smoothFollowLocation(s.customerLocation!);
      }
      
      if (s.arrived && mounted) {
        _pulseController.stop();
        await _showArrivalDialog();
      }
    });
    scheduleMicrotask(() {
      _manager.startNavigation(
        orderId: widget.orderId,
        customerUserId: widget.customerUserId ?? '',
      );
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _fitToRoute() {
    final s = _state;
    if (s?.customerLocation == null || s?.supplierLocation == null) return;
    
    // Calculate bounds to fit both locations with padding
    final customer = s!.customerLocation!;
    final supplier = s.supplierLocation!;
    
    final minLat = customer.latitude < supplier.latitude ? customer.latitude : supplier.latitude;
    final maxLat = customer.latitude > supplier.latitude ? customer.latitude : supplier.latitude;
    final minLng = customer.longitude < supplier.longitude ? customer.longitude : supplier.longitude;
    final maxLng = customer.longitude > supplier.longitude ? customer.longitude : supplier.longitude;
    
    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
    
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  void _smoothFollowLocation(LatLng location) {
    final s = _state;
    
    // If route is locked, keep camera focused on the locked route
    if (s?.isRouteLocked == true && s?.supplierLocation != null) {
      // Only move camera if customer moves significantly away from the route
      final currentCenter = _mapController.camera.center;
      final distance = _calculateDistance(currentCenter, location);
      
      // Keep camera centered on the route area, not following customer everywhere
      if (distance > 100) { // Larger threshold when route is locked
        _centerOnRoute();
      }
    } else {
      // Normal following behavior when route is not locked
      final currentCenter = _mapController.camera.center;
      final distance = _calculateDistance(currentCenter, location);
      
      if (distance > 50) { // Only move if more than 50 meters away
        _mapController.move(location, _mapController.camera.zoom);
      }
    }
  }

  void _centerOnRoute() {
    final s = _state;
    if (s?.customerLocation != null && s?.supplierLocation != null) {
      _fitToRoute();
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Simple distance calculation for camera movement decisions
    final latDiff = point1.latitude - point2.latitude;
    final lngDiff = point1.longitude - point2.longitude;
    return (latDiff * latDiff + lngDiff * lngDiff) * 111000; // Rough meters
  }

  void _centerOnMyLocation() {
    final s = _state;
    if (s?.customerLocation != null) {
      _mapController.move(s!.customerLocation!, 16.0);
    }
  }

  Future<void> _showArrivalDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("You've arrived! ✅"),
        content: const Text('Pick up your order here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (widget.supplierUserId != null) {
      await _manager.sendArrivalConfirmation(
        orderId: widget.orderId,
        recipientUserId: widget.supplierUserId!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Navigate to ${widget.supplierName}'),
            if (s?.isRouteLocked == true)
              const Text(
                'Route Locked - Ready for Pickup',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          if (s?.isRouteLocked == true)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'LOCKED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: s?.isRouteLocked == true ? _centerOnRoute : _centerOnMyLocation,
            icon: Icon(s?.isRouteLocked == true ? Icons.route : Icons.my_location),
            tooltip: s?.isRouteLocked == true ? 'Center on route' : 'Center on my location',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: s?.customerLocation ?? const LatLng(11.0474, 124.0051),
                    initialZoom: 15,
                    minZoom: 10,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.veggieconnect.app',
                    ),
                    if (s?.routePoints.isNotEmpty == true)
                      PolylineLayer(
                        polylines: [
                          // Remaining route (not traveled yet)
                          if (s!.traveledPoints.isNotEmpty)
                            Polyline(
                              points: s.routePoints.skip(s.traveledPoints.length - 1).toList(),
                              color: Colors.green,
                              strokeWidth: 5,
                            )
                          else
                            Polyline(
                              points: s.routePoints,
                              color: Colors.green,
                              strokeWidth: 5,
                            ),
                          // Traveled path with fading effect
                          if (s.traveledPoints.isNotEmpty)
                            Polyline(
                              points: s.traveledPoints,
                              color: Colors.green.withOpacity(0.6),
                              strokeWidth: 6,
                            ),
                          // Additional faded trail for better visual effect
                          if (s.traveledPoints.length > 2)
                            Polyline(
                              points: s.traveledPoints.take(s.traveledPoints.length - 1).toList(),
                              color: Colors.green.withOpacity(0.3),
                              strokeWidth: 8,
                            ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (s?.customerLocation != null)
                          Marker(
                            point: s!.customerLocation!,
                            width: 50,
                            height: 50,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.4),
                                          blurRadius: 8 * _pulseAnimation.value,
                                          spreadRadius: 2 * _pulseAnimation.value,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (s?.supplierLocation != null)
                          Marker(
                            point: s!.supplierLocation!,
                            width: 50,
                            height: 50,
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
                                Icons.store,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Loading indicator
                if (s?.routePoints.isEmpty == true)
                  const Center(
                    child: GroceryLoadingWidget(
                      size: 100,
                      showText: true,
                      loadingText: 'Loading route...'
                    ),
                  ),
              ],
            ),
          ),
          _buildControlsAndStats(s),
          Expanded(
            flex: 2,
            child: _buildStepsList(s?.steps ?? const []),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsAndStats(NavigationState? s) {
    final distance = s?.distanceMeters ?? 0;
    final duration = s?.durationSeconds ?? 0;
    String etaText;
    if (duration < 60) {
      etaText = '${duration.toStringAsFixed(0)}s';
    } else {
      final mins = (duration / 60).round();
      etaText = mins < 60 ? '$mins min' : '${(mins / 60).toStringAsFixed(1)} hr';
    }
    final distText = distance < 1000
        ? '${distance.toStringAsFixed(0)} m'
        : '${(distance / 1000).toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.black54),
                const SizedBox(width: 6),
                Text(etaText, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                const Icon(Icons.social_distance, color: Colors.black54),
                const SizedBox(width: 6),
                Text(distText, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          SegmentedButton<TravelMode>(
            segments: const [
              ButtonSegment(value: TravelMode.walking, icon: Icon(Icons.directions_walk), label: Text('Walk')),
              ButtonSegment(value: TravelMode.driving, icon: Icon(Icons.directions_car), label: Text('Drive')),
            ],
            selected: {s?.mode ?? TravelMode.walking},
            onSelectionChanged: (set) {
              final mode = set.first;
              _manager.changeMode(mode);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList(List<NavigationStep> steps) {
    if (steps.isEmpty) {
      return const Center(child: Text('Fetching directions...'));
    }
    return ListView.separated(
      itemCount: steps.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final step = steps[index];
        final dist = step.distanceMeters < 1000
            ? '${step.distanceMeters.toStringAsFixed(0)} m'
            : '${(step.distanceMeters / 1000).toStringAsFixed(1)} km';
        final dur = step.durationSeconds < 60
            ? '${step.durationSeconds.toStringAsFixed(0)}s'
            : '${(step.durationSeconds / 60).round()} min';
        return ListTile(
          leading: const Icon(Icons.turn_right, color: Colors.green),
          title: Text(step.instruction),
          subtitle: Text('$dist • $dur'),
        );
      },
    );
  }
}
