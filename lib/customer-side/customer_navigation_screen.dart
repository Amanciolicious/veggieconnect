// ignore_for_file: deprecated_member_use, avoid_print

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
      print('Navigation state received: Mode=${s.mode}, Distance=${s.distanceMeters}m, Duration=${s.durationSeconds}s');
      
      // Force UI update by checking if state actually changed
      final hasChanged = _state?.mode != s.mode || 
                        _state?.distanceMeters != s.distanceMeters || 
                        _state?.durationSeconds != s.durationSeconds ||
                        _state?.steps.length != s.steps.length;
      
      if (hasChanged || _state != s) {
      setState(() => _state = s);
        print('UI state updated: Mode=${_state?.mode}, Distance=${_state?.distanceMeters}m, Duration=${_state?.durationSeconds}s');
      }
      
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

  void _toggleDrivingMode() {
    final s = _state;
    if (s == null) return;
    
    // Show detailed driving directions modal
    _showDrivingDirectionsModal();
  }

  void _showWalkingDirectionsModal() async {
    final s = _state;
    if (s?.customerLocation == null || s?.supplierLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location information not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ensure the route is recalculated for walking before showing modal
    await _manager.changeMode(TravelMode.walking);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Listen to navigation state changes
            return StreamBuilder<NavigationState>(
              stream: _manager.stream,
              builder: (context, snapshot) {
                final currentState = snapshot.data ?? s!;
                
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.directions_walk, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Walking Directions',
                        style: TextStyle(fontSize: 12),
              )
            ],
          ),
                  content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Route Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                            Text('Distance: ${_formatDistance(currentState.distanceMeters)}'),
                        Text('Mode: Walking'),
                        Text('Time: ${_formatDuration(_durationSecondsFor(currentState.distanceMeters, TravelMode.walking))}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Walking Time', style: TextStyle(fontSize: 12)),
                              Text(_formatDuration(_durationSecondsFor(currentState.distanceMeters, TravelMode.walking)), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Driving Time', style: TextStyle(fontSize: 12)),
                              Text(_formatDuration(_durationSecondsFor(currentState.distanceMeters, TravelMode.driving)), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Step-by-step Directions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                          child: _buildWalkingInstructionsFromState(currentState),
                    ),
                  ),
                ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('Close'),
            ),
          ],
          actionsPadding: EdgeInsets.all(16),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showDrivingDirectionsModal() async {
    final s = _state;
    if (s?.customerLocation == null || s?.supplierLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location information not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ensure the route is recalculated for driving before showing modal
    await _manager.changeMode(TravelMode.driving);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Listen to navigation state changes
            return StreamBuilder<NavigationState>(
              stream: _manager.stream,
              builder: (context, snapshot) {
                final currentState = snapshot.data ?? s!;
                
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                  'Driving Directions',
                        style: TextStyle(fontSize: 12),
                )
            ],
          ),
                  content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Route Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                            Text('Distance: ${_formatDistance(currentState.distanceMeters)}'),
                        Text('Mode: Driving'),
                        Text('Time: ${_formatDuration(_durationSecondsFor(currentState.distanceMeters, TravelMode.driving))}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Walking Time', style: TextStyle(fontSize: 12)),
                              Text(_formatDuration(_durationSecondsFor(currentState.distanceMeters, TravelMode.walking)), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Driving Time', style: TextStyle(fontSize: 12)),
                              Text(_formatDuration(_durationSecondsFor(currentState.distanceMeters, TravelMode.driving)), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Step-by-step Directions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                          child: _buildDrivingInstructionsFromState(currentState),
                    ),
                  ),
                ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('Close'),
            ),
          ],
          actionsPadding: EdgeInsets.all(16),
        );
      },
    );
          },
        );
      },
    );
  }



  Widget _buildWalkingStep(int stepNumber, String instruction, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    instruction,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrivingStep(int stepNumber, String instruction, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    instruction,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  String _formatDuration(double durationSeconds) {
    if (durationSeconds < 60) {
      return '${durationSeconds.toStringAsFixed(0)}s';
    } else {
      final minutes = (durationSeconds / 60).round();
      return minutes < 60 ? '$minutes min' : '${(minutes / 60).toStringAsFixed(1)} hr';
    }
  }

  double _durationSecondsFor(double distanceMeters, TravelMode mode) {
    const double walkingSpeedMps = 1.3;
    const double drivingSpeedMps = 11.11;
    final speed = mode == TravelMode.driving ? drivingSpeedMps : walkingSpeedMps;
    return distanceMeters / speed;
  }

  Widget _buildWalkingInstructionsFromState(NavigationState? s) {
    if (s == null || s.steps.isEmpty) {
      return const Text('No walking directions available');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: s.steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return _buildWalkingStep(
          index + 1,
          step.instruction,
          Icons.directions_walk,
        );
      }).toList(),
    );
  }

  Widget _buildDrivingInstructionsFromState(NavigationState? s) {
    if (s == null || s.steps.isEmpty) {
      return const Text('No driving directions available');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: s.steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return _buildDrivingStep(
          index + 1,
          step.instruction,
          Icons.directions_car,
        );
      }).toList(),
    );
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
                            width: 36,
                            height: 36,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.25),
                                          blurRadius: 6 * _pulseAnimation.value,
                                          spreadRadius: 1.5 * _pulseAnimation.value,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 3,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (s?.supplierLocation != null)
                          Marker(
                            point: s!.supplierLocation!,
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.store,
                                color: Colors.white,
                                size: 18,
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
    print('UI Stats: Mode=${s?.mode}, Distance=${distance}m, Duration=${duration}s');
    final bool isWalking = s?.mode == TravelMode.walking;
    final bool isDriving = s?.mode == TravelMode.driving;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Left: stats in one tidy row
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.black54, size: 14),
                const SizedBox(width: 4),
                Text(etaText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 10),
                const Icon(Icons.social_distance, color: Colors.black54, size: 14),
                const SizedBox(width: 4),
                Text(distText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
          // Right: walking/driving buttons with labels in a single row, responsive with Wrap if needed
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Walking button with selected color state
              OutlinedButton.icon(
                onPressed: _showWalkingDirectionsModal,
                icon: Icon(Icons.directions_walk, size: 16, color: isWalking ? Colors.white : Colors.green),
                label: Text('Walking', style: TextStyle(fontSize: 12, color: isWalking ? Colors.white : Colors.green)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  foregroundColor: isWalking ? Colors.white : Colors.green,
                  backgroundColor: isWalking ? Colors.green : Colors.transparent,
                  side: BorderSide(color: Colors.green.withOpacity(0.6)),
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                ),
              ),
              const SizedBox(width: 8),
              // Driving button with selected color state
              OutlinedButton.icon(
                onPressed: _toggleDrivingMode,
                icon: Icon(Icons.directions_car, size: 16, color: isDriving ? Colors.white : Colors.blue),
                label: Text('Driving', style: TextStyle(fontSize: 12, color: isDriving ? Colors.white : Colors.blue)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  foregroundColor: isDriving ? Colors.white : Colors.blue,
                  backgroundColor: isDriving ? Colors.blue : Colors.transparent,
                  side: BorderSide(color: Colors.blue.withOpacity(0.6)),
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
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
