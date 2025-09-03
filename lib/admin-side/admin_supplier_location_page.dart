// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/supplier_location.dart';
import '../services/supplier_location_service.dart';

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
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading supplier locations: $e')),
      );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final green = const Color(0xFFA7C957);
    final bg = const Color(0xFFF6F6F6);
    final cardRadius = BorderRadius.circular(screenWidth * 0.05);
    final neumorphicShadow = [
      BoxShadow(
        color: Colors.grey.shade300,
        offset: Offset(screenWidth * 0.015, screenWidth * 0.015),
        blurRadius: screenWidth * 0.04,
      ),
      BoxShadow(
        color: Colors.white,
        offset: Offset(-screenWidth * 0.015, -screenWidth * 0.015),
        blurRadius: screenWidth * 0.04,
      ),
    ];
    // Bogo City, Cebu, Philippines coordinates
    const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Supplier Locations - Bogo City', style: TextStyle(fontSize: screenWidth * 0.055, fontWeight: FontWeight.bold)),
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadSupplierLocations();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  margin: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: cardRadius,
                    boxShadow: neumorphicShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin, color: green, size: screenWidth * 0.06),
                          SizedBox(width: screenWidth * 0.02),
                          Text(
                            'Supplier Locations Summary',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                              color: green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenWidth * 0.02),
                      Text(
                        'Total Supplier Locations: ${_supplierLocations.length}',
                        style: TextStyle(fontSize: screenWidth * 0.04),
                      ),
                      if (_supplierLocations.isNotEmpty)
                        Text(
                          'Active Suppliers: ${_supplierLocations.map((loc) => loc.supplierName).toSet().length}',
                          style: TextStyle(fontSize: screenWidth * 0.04),
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
                          initialZoom: 12,
                          maxZoom: 16,
                          minZoom: 10,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.vegieconnect',
                          ),
                          // Bogo City boundary circle
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: bogoCityCenter,
                                radius: 5000, // 5km radius in meters
                                color: green.withOpacity(0.1),
                                borderColor: green.withOpacity(0.5),
                                borderStrokeWidth: 3,
                              ),
                            ],
                          ),
                          // Show supplier locations
                          MarkerLayer(
                            markers: _supplierLocations.map((location) {
                              return Marker(
                                point: LatLng(location.latitude, location.longitude),
                                width: screenWidth * 0.08,
                                height: screenWidth * 0.08,
                                child: GestureDetector(
                                  onTap: () => _showSupplierLocationDetails(location),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: green,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: neumorphicShadow,
                                    ),
                                    child: Icon(
                                      Icons.person_pin,
                                      color: Colors.white,
                                      size: screenWidth * 0.05,
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
                        top: screenWidth * 0.04,
                        left: screenWidth * 0.04,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenWidth * 0.02),
                          decoration: BoxDecoration(
                            color: green.withOpacity(0.9),
                            borderRadius: cardRadius,
                            boxShadow: neumorphicShadow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, color: Colors.white, size: screenWidth * 0.04),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                'Bogo City Boundary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.03,
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