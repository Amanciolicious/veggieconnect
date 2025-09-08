// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/location_map_widget.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../models/farm_location.dart';

class PickupLocationFinder extends StatefulWidget {
  const PickupLocationFinder({super.key});

  @override
  State<PickupLocationFinder> createState() => _PickupLocationFinderState();
}

class _PickupLocationFinderState extends State<PickupLocationFinder> {
  final LocationService _locationService = LocationService();
  final MapService _mapService = MapService();
  
  List<FarmLocation> _farmLocations = [];
  List<SupplierLocationData> _supplierLocations = [];
  LatLng? _currentLocation;
  bool _isLoading = true;
  String _selectedFilter = 'All';
  double _maxDistance = 5.0; // km
  
  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _refreshCurrentLocation() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current location with address
      final data = await _mapService.getCurrentLocationWithAddress();
      if (data != null) {
        final location = data['location'] as LatLng?;
        final address = data['address'] as String?;
        
        if (location != null) {
          _currentLocation = location;
          
          // Recalculate distances
          _calculateDistances();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location updated: ${address != null && address.length > 40 ? '${address.substring(0, 40)}...' : address ?? 'Current location'}'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to get current location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocations() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current location
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _currentLocation = LatLng(position.latitude, position.longitude);
      }
      
      // Load farm locations
      final farmSnapshot = await FirebaseFirestore.instance
          .collection('farm_locations')
          .get();
      
      _farmLocations = farmSnapshot.docs.map((doc) {
        final data = doc.data();
        return FarmLocation(
          id: doc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          latitude: data['latitude']?.toDouble() ?? 0.0,
          longitude: data['longitude']?.toDouble() ?? 0.0,
          supplierId: data['supplierId'] ?? '',
          supplierName: data['supplierName'] ?? '',
          address: data['address'] ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      
      // Load supplier locations
      final supplierSnapshot = await FirebaseFirestore.instance
          .collection('supplier_locations')
          .where('isActive', isEqualTo: true)
          .get();
      
      _supplierLocations = supplierSnapshot.docs.map((doc) {
        final data = doc.data();
        return SupplierLocationData(
          id: doc.id,
          supplierId: data['supplierId'] ?? '',
          supplierName: data['supplierName'] ?? '',
          locationName: data['locationName'] ?? '',
          description: data['description'] ?? '',
          latitude: data['latitude']?.toDouble() ?? 0.0,
          longitude: data['longitude']?.toDouble() ?? 0.0,
          address: data['address'] ?? '',
          rating: data['rating']?.toDouble(),
        );
      }).toList();
      
      // Calculate distances if current location is available
      if (_currentLocation != null) {
        _calculateDistances();
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading locations: $e')),
      );
    }
  }

  void _calculateDistances() {
    if (_currentLocation == null) return;
    
    for (var farm in _farmLocations) {
      farm.distanceFromUser = _mapService.calculateDistance(
        _currentLocation!,
        LatLng(farm.latitude, farm.longitude),
      );
    }
    
    for (var supplier in _supplierLocations) {
      supplier.distanceFromUser = _mapService.calculateDistance(
        _currentLocation!,
        LatLng(supplier.latitude, supplier.longitude),
      );
    }
    
    // Sort by distance
    _farmLocations.sort((a, b) => (a.distanceFromUser ?? double.infinity)
        .compareTo(b.distanceFromUser ?? double.infinity));
    _supplierLocations.sort((a, b) => (a.distanceFromUser ?? double.infinity)
        .compareTo(b.distanceFromUser ?? double.infinity));
  }

  List<Marker> _buildMapMarkers() {
    List<Marker> markers = [];
    
    // Add farm markers
    if (_selectedFilter == 'All' || _selectedFilter == 'Farms') {
      for (var farm in _getFilteredFarms()) {
        markers.add(
          Marker(
            point: LatLng(farm.latitude, farm.longitude),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showFarmDetails(farm),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.agriculture,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }
    }
    
    // Add supplier markers
    if (_selectedFilter == 'All' || _selectedFilter == 'Suppliers') {
      for (var supplier in _getFilteredSuppliers()) {
        markers.add(
          Marker(
            point: LatLng(supplier.latitude, supplier.longitude),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showSupplierDetails(supplier),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
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
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return markers;
  }

  List<FarmLocation> _getFilteredFarms() {
    return _farmLocations.where((farm) {
      if (farm.distanceFromUser == null) return true;
      return farm.distanceFromUser! <= _maxDistance;
    }).toList();
  }

  List<SupplierLocationData> _getFilteredSuppliers() {
    return _supplierLocations.where((supplier) {
      if (supplier.distanceFromUser == null) return true;
      return supplier.distanceFromUser! <= _maxDistance;
    }).toList();
  }

  void _showFarmDetails(FarmLocation farm) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.agriculture,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farm.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Managed by ${farm.supplierName}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (farm.description.isNotEmpty) ...[
              Text(
                farm.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    farm.address.isNotEmpty ? farm.address : 'Address not available',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            if (farm.distanceFromUser != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.navigation, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${farm.distanceFromUser!.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToLocation(LatLng(farm.latitude, farm.longitude));
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to farm products or contact supplier
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('View Products'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSupplierDetails(SupplierLocationData supplier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.supplierName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (supplier.rating != null) ...[
                            const Icon(Icons.star, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              supplier.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ] else
                            const Text(
                              'No ratings yet',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (supplier.description.isNotEmpty) ...[
              Text(
                supplier.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    supplier.address.isNotEmpty ? supplier.address : 'Address not available',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            if (supplier.distanceFromUser != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.navigation, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${supplier.distanceFromUser!.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.payments, color: Color(0xFF4CAF50), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Cash on Pickup Available',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToLocation(LatLng(supplier.latitude, supplier.longitude));
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to supplier products
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Shop Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLocation(LatLng destination) {
    if (_currentLocation != null) {
      _mapService.setDestination(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pickup Locations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Locations')),
              const PopupMenuItem(value: 'Suppliers', child: Text('Suppliers Only')),
              const PopupMenuItem(value: 'Farms', child: Text('Farms Only')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshCurrentLocation,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        tooltip: 'Use Current Location',
        child: const Icon(Icons.my_location),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Distance filter
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search within ${_maxDistance.toStringAsFixed(0)} km',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _maxDistance,
                        min: 1.0,
                        max: 10.0,
                        divisions: 9,
                        label: '${_maxDistance.toStringAsFixed(0)} km',
                        activeColor: const Color(0xFF4CAF50),
                        onChanged: (value) {
                          setState(() {
                            _maxDistance = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                // Map
                Expanded(
                  child: LocationMapWidget(
                    showCurrentLocation: true,
                    enableLocationTracking: true,
                    showAccuracyCircle: false,
                    initialZoom: 13.0,
                    additionalMarkers: _buildMapMarkers(),
                    onLocationUpdate: (location) {
                      _currentLocation = location;
                      _calculateDistances();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// Helper class for supplier location data
class SupplierLocationData {
  final String id;
  final String supplierId;
  final String supplierName;
  final String locationName;
  final String description;
  final double latitude;
  final double longitude;
  final String address;
  final double? rating;
  double? distanceFromUser;

  SupplierLocationData({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.locationName,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.rating,
    this.distanceFromUser,
  });
}
