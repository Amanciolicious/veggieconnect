// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import './lottie_loading_widget.dart';

class LocationMapWidget extends StatefulWidget {
  final LatLng? initialLocation;
  final LatLng? destination;
  final String? destinationTitle;
  final String? destinationSnippet;
  final bool showCurrentLocation;
  final bool enableLocationTracking;
  final bool showAccuracyCircle;
  final double initialZoom;
  final Function(LatLng)? onLocationUpdate;
  final Function(LatLng)? onMapTap;
  final Function(MapController)? onMapCreated;
  final List<Marker>? additionalMarkers;
  final List<Polyline>? additionalPolylines;

  const LocationMapWidget({
    super.key,
    this.initialLocation,
    this.destination,
    this.destinationTitle,
    this.destinationSnippet,
    this.showCurrentLocation = true,
    this.enableLocationTracking = true,
    this.showAccuracyCircle = true,
    this.initialZoom = 16.0,
    this.onLocationUpdate,
    this.onMapTap,
    this.onMapCreated,
    this.additionalMarkers,
    this.additionalPolylines,
  });

  @override
  State<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  final LocationService _locationService = LocationService();
  final MapService _mapService = MapService();
  final MapController _mapController = MapController();
  
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  String _statusMessage = 'Initializing map...';
  LatLng? _currentLocation;
  double? _distanceToDestination;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _mapService.stopLocationTracking();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _statusMessage = 'Checking location permissions...';
      });

      // Check location access
      final accessResult = await _locationService.checkAndRequestLocationAccess();
      
      if (!accessResult.success) {
        setState(() {
          _isLoading = false;
          _hasLocationPermission = false;
          _statusMessage = accessResult.message;
        });
        return;
      }

      setState(() {
        _hasLocationPermission = true;
        _statusMessage = 'Getting your location...';
      });

      // Get initial location if needed
      if (widget.showCurrentLocation) {
        final position = await _locationService.getCurrentLocation();
        if (position != null) {
          _currentLocation = LatLng(position.latitude, position.longitude);
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = 'Map ready';
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasLocationPermission = false;
        _statusMessage = 'Error initializing map: ${e.toString()}';
      });
    }
  }

  void _onMapReady() {
    _mapService.setMapController(_mapController);
    
    // Set destination if provided
    if (widget.destination != null) {
      _mapService.setDestination(
        widget.destination!,
        title: widget.destinationTitle,
        snippet: widget.destinationSnippet,
      );
    }

    // Start location tracking if enabled
    if (widget.enableLocationTracking && _hasLocationPermission) {
      _startLocationTracking();
    }

    // Callback to parent
    widget.onMapCreated?.call(_mapController);
  }

  void _startLocationTracking() {
    _mapService.startLocationTracking(
      onLocationUpdate: (LatLng location) {
        setState(() {
          _currentLocation = location;
          
          // Calculate distance to destination if available
          if (widget.destination != null) {
            _distanceToDestination = _mapService.getDistanceToDestination();
          }
        });
        
        // Callback to parent
        widget.onLocationUpdate?.call(location);
      },
      showAccuracyCircle: widget.showAccuracyCircle,
    );
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) {
    widget.onMapTap?.call(location);
  }

  void _retryLocationAccess() {
    setState(() {
      _isLoading = true;
    });
    _initializeMap();
  }

  void _openLocationSettings() {
    _locationService.openLocationSettings();
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (!_hasLocationPermission) {
      return _buildPermissionDeniedWidget();
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initialLocation ?? 
                         _currentLocation ?? 
                         const LatLng(11.0474, 124.0051), // Default to Bogo City
            initialZoom: widget.initialZoom,
            onTap: _onMapTap,
            onMapReady: _onMapReady,
            maxZoom: 18.0,
            minZoom: 8.0,
          ),
          children: [
            // OpenStreetMap tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.veggieconnect',
              maxZoom: 19,
            ),
            
            // Bogo City boundary circle
            CircleLayer(
              circles: [
                CircleMarker(
                  point: const LatLng(11.0474, 124.0051),
                  radius: 5000, // 5km radius
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderColor: const Color(0xFF4CAF50).withOpacity(0.5),
                  borderStrokeWidth: 2,
                ),
                // Accuracy circles from MapService
                ..._mapService.circles,
              ],
            ),
            
            // Polylines (routes)
            PolylineLayer(
              polylines: [
                ..._mapService.polylines,
                if (widget.additionalPolylines != null) ...widget.additionalPolylines!,
              ],
            ),
            
            // Markers
            MarkerLayer(
              markers: [
                ..._mapService.markers,
                if (widget.additionalMarkers != null) ...widget.additionalMarkers!,
              ],
            ),
          ],
        ),
        
        // Location info overlay
        if (_currentLocation != null || _distanceToDestination != null)
          _buildLocationInfoOverlay(),
        
        // My location button
        if (_hasLocationPermission)
          _buildMyLocationButton(),
        
        // Bogo City boundary indicator
        _buildBoundaryIndicator(),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GroceryLoadingWidget(
              size: 100,
              showText: true,
              loadingText: 'Initializing map...'
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedWidget() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _retryLocationAccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
                ElevatedButton(
                  onPressed: _openLocationSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfoOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentLocation != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.my_location,
                    color: Color(0xFF4CAF50),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}, '
                      'Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (_distanceToDestination != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.navigation,
                    color: Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Distance: ${_mapService.formatDistance(_distanceToDestination!)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyLocationButton() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4CAF50),
        onPressed: _centerOnCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildBoundaryIndicator() {
    return Positioned(
      top: 80,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Bogo City Area',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
