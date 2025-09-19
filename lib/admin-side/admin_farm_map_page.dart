// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veggieconnect/widgets/role_page_header.dart';
import '../models/farm_location.dart';
import '../models/farm_location_request.dart';
import '../services/farm_location_service.dart';
import '../services/farm_location_request_service.dart';
import '../services/map_service.dart';
import 'admin_supplier_location_page.dart';
import '../widgets/lottie_loading_widget.dart';
import 'admin_dashboard.dart';

class AdminFarmMapPage extends StatefulWidget {
  const AdminFarmMapPage({super.key});

  @override
  State<AdminFarmMapPage> createState() => _AdminFarmMapPageState();
}

class _AdminFarmMapPageState extends State<AdminFarmMapPage> {
  final MapController _mapController = MapController();
  final FarmLocationService _farmLocationService = FarmLocationService();
  final FarmLocationRequestService _requestService = FarmLocationRequestService();
  final MapService _mapService = MapService();
  
  List<FarmLocation> _farmLocations = [];
  List<FarmLocationRequest> _pendingRequests = [];
  bool _isLoading = true;
  bool _isAddingPin = false;
  String _selectedSupplierFilter = 'All Suppliers';
  List<String> _supplierNames = ['All Suppliers'];
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadFarmLocations();
    // Centering will run when map is ready
  }

  Future<void> _loadFarmLocations() async {
    try {
      final locations = await _farmLocationService.getAllFarmLocations();
      final pendingRequests = await _requestService.getPendingRequests();
      
      // Extract unique supplier names for filter
      final supplierNames = locations.map((loc) => loc.supplierName).toSet().toList();
      supplierNames.sort();
      
      setState(() {
        _farmLocations = locations;
        _pendingRequests = pendingRequests;
        _supplierNames = ['All Suppliers', ...supplierNames];
        _isLoading = false;
      });

      // Recenter after data loads
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
        SnackBar(content: Text('Error loading farm locations: $e')),
      );
    }
  }

  void _centerMapToBogoOrMarkers() {
    const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
    try {
      if (_farmLocations.isNotEmpty) {
        final lats = _farmLocations.map((e) => e.latitude).toList();
        final lngs = _farmLocations.map((e) => e.longitude).toList();
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
        _mapController.move(bogoCityCenter, 14.0);
      }
    } catch (_) {
      _mapController.move(bogoCityCenter, 14.0);
    }
  }

  List<FarmLocation> get _filteredFarmLocations {
    if (_selectedSupplierFilter == 'All Suppliers') {
      return _farmLocations;
    }
    return _farmLocations.where((farm) => farm.supplierName == _selectedSupplierFilter).toList();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // Check if the tapped location is within Bogo City boundary
    const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
    
    double distance = _mapService.calculateDistance(bogoCityCenter, point);
    
    if (distance > 5.0) { // 5km radius
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Farm locations can only be added within Bogo City boundaries'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // If in pin addition mode, add the pin immediately
    if (_isAddingPin) {
      setState(() {
        _isAddingPin = false; // Exit pin addition mode
      });
      _showAddFarmDialog(point);
    } else {
      // Show a hint to enable pin addition mode
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap the "Add Pin" button to add a new farm location'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _enablePinAdditionMode() {
    setState(() {
      _isAddingPin = true;
// Clear any existing selection
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap anywhere on the map to add a farm pin'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _cancelPinAdditionMode() {
    setState(() {
      _isAddingPin = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pin addition mode cancelled'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAddFarmDialog(LatLng location) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedSupplierId = '';
    String selectedSupplierName = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.add_location, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Add Farm Location'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Farm Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Supplier selection dropdown
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'supplier')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 80,
                      child: Center(
                        child: GroceryLoadingWidget(
                          size: 80,
                          showText: true,
                          loadingText: 'Loading suppliers...'
                        ),
                      ),
                    );
                  }
                  
                  final suppliers = snapshot.data?.docs ?? [];
                  
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Supplier (Required)',
                      border: OutlineInputBorder(),
                      hintText: 'Choose the supplier who canvassed this farm',
                    ),
                    value: selectedSupplierId.isEmpty ? null : selectedSupplierId,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Select a supplier...'),
                      ),
                      ...suppliers.map((supplier) {
                        final data = supplier.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: supplier.id,
                          child: Text(data['name'] ?? 'Unknown Supplier'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        final supplier = suppliers.firstWhere((s) => s.id == value);
                        final data = supplier.data() as Map<String, dynamic>;
                        selectedSupplierId = value;
                        selectedSupplierName = data['name'] ?? 'Unknown Supplier';
                      } else {
                        selectedSupplierId = '';
                        selectedSupplierName = '';
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              FutureBuilder<String>(
                future: _mapService.getAddressFromCoordinates(location),
                builder: (context, snapshot) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (snapshot.hasData && snapshot.data!.isNotEmpty)
                        Text(
                          'Address: ${snapshot.data}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && selectedSupplierId.isNotEmpty) {
                  Navigator.of(context).pop();
                  await _addFarmLocation(
                    nameController.text,
                    descriptionController.text,
                    location,
                    selectedSupplierId,
                    selectedSupplierName,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add Farm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addFarmLocation(String name, String description, LatLng location, String supplierId, String supplierName) async {
    try {
      // Get address from coordinates
      final address = await _mapService.getAddressFromCoordinates(location);

      final farmLocation = FarmLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        latitude: location.latitude,
        longitude: location.longitude,
        supplierId: supplierId,
        supplierName: supplierName,
        address: address,
        createdAt: DateTime.now(),
      );

      await _farmLocationService.addFarmLocation(farmLocation);
      
      // Sync to supplier_locations for supplier map
      await FirebaseFirestore.instance
        .collection('supplier_locations')
        .doc(farmLocation.supplierId)
        .set({
          'id': farmLocation.supplierId,
          'supplierId': farmLocation.supplierId,
          'supplierName': farmLocation.supplierName,
          'locationName': farmLocation.name,
          'description': farmLocation.description,
          'latitude': farmLocation.latitude,
          'longitude': farmLocation.longitude,
          'address': farmLocation.address,
          'createdAt': farmLocation.createdAt,
          'isActive': true,
        });
      
      // Reload farm locations
      await _loadFarmLocations();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farm location added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding farm location: $e')),
      );
    }
  }

  void _showPendingRequestDetails(FarmLocationRequest request) {
    final now = DateTime.now();
    final timeLeft = request.autoApprovalAt?.difference(now);
    String timeRemaining = 'Auto-approval overdue';
    
    if (timeLeft != null && !timeLeft.isNegative) {
      final minutes = timeLeft.inMinutes;
      final seconds = timeLeft.inSeconds % 60;
      timeRemaining = 'Auto-approval in ${minutes}m ${seconds}s';
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.pending_actions, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text('Pending: ${request.farmName}')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Farm Name: ${request.farmName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Requested By: ${request.requesterName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              
              if (request.farmDescription.isNotEmpty) ...[
                Text(
                  'Description: ${request.farmDescription}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
              ],
              
              if (request.address.isNotEmpty) ...[
                Text(
                  'Address: ${request.address}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
              ],
              
              Text(
                'Coordinates: ${request.latitude.toStringAsFixed(6)}, ${request.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Requested: ${request.requestedAt.toString().split('.')[0]}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              
              Text(
                timeRemaining,
                style: TextStyle(
                  fontSize: 14,
                  color: request.isAutoApprovalDue ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                // Manual approve inline
                try {
                  await _requestService.approveRequest(requestId: request.id, reviewNotes: 'Manually approved from map');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
                } finally {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Manually Approve', style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _requestService.rejectRequest(requestId: request.id, reviewNotes: 'Rejected from map');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
                } finally {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showFarmDetails(FarmLocation farm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.agriculture, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(farm.name)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Farm Name
              Text(
                'Farm Name: ${farm.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              
              // Canvassed By
              Text(
                'Canvassed By: ${farm.supplierName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              
              // Description
              if (farm.description.isNotEmpty) ...[
                Text(
                  'Description: ${farm.description}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
              ],
              
              // Address
              if (farm.address.isNotEmpty) ...[
                Text(
                  'Address: ${farm.address}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
              ],
              
              // Coordinates
              Text(
                'Coordinates: ${farm.latitude.toStringAsFixed(6)}, ${farm.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              
              // Added Date
              Text(
                'Added: ${farm.createdAt.toString().split('.')[0]}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteFarmLocation(farm.id);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFarmLocation(String farmId) async {
    try {
      // Fetch the farm location to get the supplierId
      final farmDoc = await FirebaseFirestore.instance
          .collection('farm_locations')
          .doc(farmId)
          .get();
      final supplierId = farmDoc.data()?['supplierId'];

      await _farmLocationService.deleteFarmLocation(farmId);

      // Also delete from supplier_locations
      if (supplierId != null) {
        await FirebaseFirestore.instance
            .collection('supplier_locations')
            .doc(supplierId)
            .delete();
      }

      await _loadFarmLocations();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farm location deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting farm location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
   
    // Bogo City, Cebu, Philippines coordinates
    const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
    return Scaffold(
      backgroundColor:Color(0xFFF6F6F6),
      appBar: RolePageHeader(
        title: 'Farm Locations',
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: Color(0xFF4CAF50)),
              onSelected: (value) {
                setState(() {
                  _selectedSupplierFilter = value;
                });
              },
              itemBuilder: (context) => _supplierNames.map((supplier) {
                return PopupMenuItem(
                  value: supplier,
                  child: Text(supplier),
                );
              }).toList(),
            ),
            IconButton(
              icon: Icon(Icons.person_pin, color: Color(0xFF4CAF50), size: 24,),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdminSupplierLocationPage(),
                  ),
                );
              },
              tooltip: 'Manage Supplier Locations',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: GroceryLoadingWidget(
                size: 140,
                showText: true,
                loadingText: 'Loading farm locations...'
              ),
            )
           : StreamBuilder<List<FarmLocationRequest>>(
              stream: _requestService.streamPendingRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _pendingRequests = snapshot.data!;
                }
                return Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: bogoCityCenter,
                    initialZoom: 14,
                    onTap: _onMapTap,
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
                    MarkerLayer(
                      markers: [
                        // Approved farm locations
                        ..._filteredFarmLocations.map((location) {
                          return Marker(
                            point: LatLng(location.latitude, location.longitude),
                            width: 33,
                            height: 33,
                            child: GestureDetector(
                              onTap: () => _showFarmDetails(location),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFA7C957),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(Icons.agriculture, color: Colors.white, size: 24),
                              ),
                            ),
                          );
                        }),
                        // Pending farm location requests
                        ..._pendingRequests.map((request) {
                          return Marker(
                            point: LatLng(request.latitude, request.longitude),
                            width: 33,
                            height: 33,
                            child: GestureDetector(
                              onTap: () => _showPendingRequestDetails(request),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(Icons.pending_actions, color: Colors.white, size: 24),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(bottom: 12),
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
                      Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pending_actions, color: Colors.white, size: 14),
                            SizedBox(width: 11),
                            Text(
                              'Pending Requests',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFFA7C957).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.agriculture, color: Colors.white, size: 14),
                            SizedBox(width: 11),
                            Text(
                              'Approved Farms',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAddingPin)
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: FloatingActionButton.extended(
                      backgroundColor: Color(0xFFA7C957),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      onPressed: _cancelPinAdditionMode,
                      label: Text('Cancel Pin', style: TextStyle(fontSize: 14)),
                      icon: Icon(Icons.cancel, size: 15),
                    ),
                  ),
                Positioned(
                  bottom: 14,
                  left: 14,
                  child: FloatingActionButton.extended(
                    backgroundColor: Color(0xFFA7C957),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    onPressed: _enablePinAdditionMode,
                    label: Text('Add Pin', style: TextStyle(fontSize: 14)),
                    icon: Icon(Icons.add_location, size: 15),
                  ),
                ),
              ],
            );
  }),
              
            
    );
  }
} 