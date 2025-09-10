// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/navigation_manager.dart';

class NavigationScreen extends StatefulWidget {
  final String orderId;
  final String supplierName;
  final String? supplierUserId; // for arrival confirmation

  const NavigationScreen({
    super.key,
    required this.orderId,
    required this.supplierName,
    this.supplierUserId,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final NavigationManager _manager = NavigationManager();
  final MapController _mapController = MapController();
  late StreamSubscription _sub;
  NavigationState? _state;

  @override
  void initState() {
    super.initState();
    _sub = _manager.stream.listen((s) async {
      setState(() => _state = s);
      if (s.arrived && mounted) {
        await _showArrivalDialog();
      }
    });
    scheduleMicrotask(() {
      _manager.startNavigation(orderId: widget.orderId);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
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
        title: Text('Navigate to ${widget.supplierName}'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: s?.customerLocation ?? const LatLng(11.0474, 124.0051),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.veggieconnect.app',
                ),
                if (s?.routePoints.isNotEmpty == true)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: s!.routePoints,
                        color: Colors.green,
                        strokeWidth: 5,
                      ),
                      if (s.traveledPoints.isNotEmpty)
                        Polyline(
                          points: s.traveledPoints,
                          color: Colors.green.withOpacity(0.35),
                          strokeWidth: 7,
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    if (s?.supplierLocation != null)
                      Marker(
                        point: s!.supplierLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                  ],
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


