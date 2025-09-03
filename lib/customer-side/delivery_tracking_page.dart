// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/location_map_widget.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String orderId;
  final LatLng deliveryLocation;
  final String deliveryAddress;
  final String supplierName;

  const DeliveryTrackingPage({
    super.key,
    required this.orderId,
    required this.deliveryLocation,
    required this.deliveryAddress,
    required this.supplierName,
  });

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  final LocationService _locationService = LocationService();
  final MapService _mapService = MapService();
  
  LatLng? _currentLocation;
  double? _distanceToDelivery;
  double? _estimatedTimeMinutes;
  bool _isLocationTracking = false;
  String _deliveryStatus = 'Preparing';

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _mapService.stopLocationTracking();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    // Simulate delivery status updates
    _updateDeliveryStatus();
  }

  void _updateDeliveryStatus() {
    // Simulate different delivery statuses
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _deliveryStatus = 'Out for Delivery';
        });
      }
    });
  }

  void _onLocationUpdate(LatLng location) {
    setState(() {
      _currentLocation = location;
      _isLocationTracking = true;
      
      // Calculate distance and estimated time
      if (_currentLocation != null) {
        _distanceToDelivery = _mapService.getDistanceToDestination();
        if (_distanceToDelivery != null) {
          // Estimate time based on average speed (assuming 30 km/h for delivery)
          _estimatedTimeMinutes = (_distanceToDelivery! / 1000) * 2; // 2 minutes per km
        }
      }
    });
  }

  void _centerOnMyLocation() {
    if (_currentLocation != null) {
      // This will be handled by the LocationMapWidget's my location button
    }
  }

  void _callSupplier() {
    // Implement call functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Supplier'),
        content: Text('Call ${widget.supplierName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement actual call functionality here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling supplier...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Track Delivery',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _callSupplier,
            icon: const Icon(Icons.phone),
            tooltip: 'Call Supplier',
          ),
        ],
      ),
      body: Column(
        children: [
          // Delivery Status Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${widget.orderId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _deliveryStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_estimatedTimeMinutes != null)
                      Text(
                        'ETA: ${_estimatedTimeMinutes!.toInt()} min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Delivery Info Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.location_on,
                    title: 'Distance',
                    value: _distanceToDelivery != null 
                        ? _mapService.formatDistance(_distanceToDelivery!)
                        : 'Calculating...',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.person,
                    title: 'Supplier',
                    value: widget.supplierName,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: LocationMapWidget(
                destination: widget.deliveryLocation,
                destinationTitle: 'Delivery Location',
                destinationSnippet: widget.deliveryAddress,
                showCurrentLocation: true,
                enableLocationTracking: true,
                showAccuracyCircle: true,
                initialZoom: 14.0,
                onLocationUpdate: _onLocationUpdate,
                onMapTap: (location) {
                  // Handle map tap if needed
                },
              ),
            ),
          ),
          
          // Delivery Address
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.deliveryAddress,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
