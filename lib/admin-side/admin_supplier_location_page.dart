// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/supplier_location.dart';
import '../widgets/app_loader.dart';
import '../services/supplier_location_service.dart';
import '../widgets/role_page_header.dart';
import 'admin_dashboard.dart';

class AdminSupplierLocationPage extends StatefulWidget {
  const AdminSupplierLocationPage({super.key});

  @override
  State<AdminSupplierLocationPage> createState() => _AdminSupplierLocationPageState();
}

class _AdminSupplierLocationPageState extends State<AdminSupplierLocationPage> {
  final MapController _mapController = MapController();
  final SupplierLocationService _supplierLocationService = SupplierLocationService();
  
  List<SupplierLocation> _supplierLocations = [];
  bool _isLoading = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadSupplierLocations();
  }

  Future<void> _loadSupplierLocations() async {
    try {
      final locations = await _supplierLocationService.getAllSupplierLocations();
      setState(() {
        _supplierLocations = locations;
        _isLoading = false;
      });

      // Center map similarly to supplier map behavior
      if (_mapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerMapToBogoOrMarkers();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading supplier locations: $e')),
      );
    }
  }

  void _centerMapToBogoOrMarkers() {
    const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
    try {
      if (_supplierLocations.isNotEmpty) {
        // Fit bounds to all supplier markers with padding, limited zoom range
        final lats = _supplierLocations.map((e) => e.latitude).toList();
        final lngs = _supplierLocations.map((e) => e.longitude).toList();
        final southWest = LatLng(
          lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b),
        );
        final northEast = LatLng(
          lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b),
        );
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(southWest, northEast),
            padding: const EdgeInsets.all(24),
          ),
        );
      } else {
        // Default closer view on Bogo City
        _mapController.move(bogoCityCenter, 14.0);
      }
    } catch (_) {
      // Fallback to safe move
      _mapController.move(bogoCityCenter, 14.0);
    }
  }

  void _showSupplierLocationDetails(SupplierLocation location) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(location.locationName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supplier: ${location.supplierName}'),
              const SizedBox(height: 8),
              Text('Description: ${location.description}'),
              const SizedBox(height: 8),
              Text('Address: ${location.address}'),
              const SizedBox(height: 8),
              Text('Coordinates: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 8),
              Text('Added: ${location.createdAt.toString().split('.')[0]}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    
    // Bogo City, Cebu, Philippines coordinates
    const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
    return Scaffold(
      backgroundColor: Color(0xFFF6F6F6),
      appBar: RolePageHeader(
        title: 'Supplier Locations',
        onBackTap: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminDashboard()),
            );
          }
        },
        trailing: IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
          onPressed: _loadSupplierLocations,
          tooltip: 'Refresh',
        ),
      ),
      body: _isLoading
          ? const Center(child: AppLoader(width: 160, height: 160))
          : Column(
              children: [
                // Summary card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  margin: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin, color: Color(0xFFA7C957), size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Supplier Locations Summary',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA7C957),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Total Supplier Locations: ${_supplierLocations.length}',
                        style: TextStyle(fontSize: 14),
                      ),
                      if (_supplierLocations.isNotEmpty)
                        Text(
                          'Active Suppliers: ${_supplierLocations.map((loc) => loc.supplierName).toSet().length}',
                          style: TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ),
                // Map
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: bogoCityCenter,
                          initialZoom: 14,
                          onMapReady: () {
                            _mapReady = true;
                            _centerMapToBogoOrMarkers();
                          },
                          maxZoom: 18,
                          minZoom: 10,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.veggieconnect.app',
                          ),
                          // Bogo City boundary circle
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: bogoCityCenter,
                                radius: 5000, // 5km radius in meters
                                color: Color(0xFFA7C957).withOpacity(0.1),
                                borderColor: Color(0xFFA7C957).withOpacity(0.5),
                                borderStrokeWidth: 3,
                              ),
                            ],
                          ),
                          // Show supplier locations
                          MarkerLayer(
                            markers: _supplierLocations.map((location) {
                              return Marker(
                                point: LatLng(location.latitude, location.longitude),
                                width: 33,
                                height: 33,
                                child: GestureDetector(
                                  onTap: () => _showSupplierLocationDetails(location),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFFA7C957),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Icon(
                                      Icons.person_pin,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      // Boundary indicator
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Color(0xFFA7C957).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, color: Colors.white, size: 14),
                              SizedBox(width: 11),
                              Text(
                                'Bogo City Boundary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
} 