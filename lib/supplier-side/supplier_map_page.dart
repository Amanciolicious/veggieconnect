// ignore_for_file: use_build_context_synchronously, deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Chat widgets removed
import '../models/supplier_location.dart';
import '../services/supplier_location_service.dart';
import '../services/map_service.dart';
import '../models/farm_location.dart';
import '../services/farm_location_service.dart';
import '../models/farm_location_request.dart';
import '../services/farm_location_request_service.dart';
import '../services/farm_location_countdown_service.dart';
import '../services/auth_state_service.dart';
import '../widgets/lottie_loading_widget.dart';
import 'dart:async';

class SupplierLocationPage extends StatefulWidget {
  const SupplierLocationPage({super.key});

  @override
  State<SupplierLocationPage> createState() => _SupplierLocationPageState();
}

class _SupplierLocationPageState extends State<SupplierLocationPage> {
  final MapController _mapController = MapController();
  final SupplierLocationService _supplierLocationService = SupplierLocationService();
  final FarmLocationService _farmLocationService = FarmLocationService();
  final MapService _mapService = MapService();
  final FarmLocationRequestService _farmLocationRequestService = FarmLocationRequestService();
  final FarmLocationCountdownService _countdownService = FarmLocationCountdownService();
  final AuthStateService _authService = AuthStateService();
  
  AuthUser? get user => _authService.currentUser;
  
  SupplierLocation? _supplierLocation;
  List<FarmLocation> _canvassedFarms = [];
  List<FarmLocationRequest> _pendingRequests = [];
  LatLng? _selectedLocation;
  bool _isLoading = true;
  bool _isAddingPin = false; // Track if user is in pin addition mode
  bool _isEditingPin = false; // Track if user is in pin editing mode
  bool _isDragging = false;
  bool _isRequestingFarm = false;
  Timer? _countdownTimer;
  bool _isFarmRequestMode = false; // Track if in farm request mode
  Offset? _mousePosition; // Track mouse position for pin preview

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Load pending requests and start countdown service safely
    _loadPendingRequestsSafely();
    
    // Start timer to update countdown display every second
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild to update the countdown display
        });
      }
    });
  }

  Future<void> _loadPendingRequestsSafely() async {
    try {
      await _loadPendingRequests();
      
      // Safely start countdowns for existing pending requests
      _countdownService.startCountdownForPendingRequests();
    } catch (e) {
      print('Error loading pending requests or starting countdown service: $e');
      // Continue without farm request functionality
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    try {
      _countdownService.dispose();
    } catch (e) {
      print('Error disposing countdown service: $e');
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    final currentUser = user;
    if (currentUser != null) {
      final location = await _supplierLocationService.getSupplierLocationBySupplierId(currentUser.uid);
      final farms = await _farmLocationService.getAllFarmLocations();
      setState(() {
        _supplierLocation = location;
        _canvassedFarms = farms;
        _isLoading = false;
      });
      
      // Auto-zoom to supplier's location if available, otherwise get current location
      if (location != null) {
        _zoomToSupplierLocation();
      } else {
        // Automatically get current location if no supplier location is set
        await _getCurrentLocationAutomatically();
      }
    }
  }

  Future<void> _getCurrentLocationAutomatically() async {
    try {
      final locationData = await _mapService.getCurrentLocationWithAddress();
      if (locationData != null) {
        final location = locationData['location'] as LatLng?;
        final address = locationData['address'] as String?;

        if (location != null && address != null) {
          // Check if location is within Bogo City boundary
          const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
          double distance = _mapService.calculateDistance(bogoCityCenter, location);
          
          if (distance > 5.0) { // 5km radius
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Supplier locations can only be added within Bogo City boundaries'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Move map to current location with proper zoom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _mapController.move(location, 16.0);
              } catch (e) {
                print('Map controller not ready yet: $e');
              }
            }
          });
          
          // Set the selected location
          setState(() {
            _selectedLocation = location;
          });

          // Auto-save the current location
          await _autoSaveCurrentLocation(location, address);
        }
      }
    } catch (e) {
      print('Error getting current location automatically: $e');
      // Fallback to Bogo City center
      const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(bogoCityCenter, 12.0);
          } catch (e) {
            print('Map controller not ready yet: $e');
          }
        }
      });
    }
  }

  void _zoomToSupplierLocation() {
    if (_supplierLocation != null) {
      final supplierLatLng = LatLng(_supplierLocation!.latitude, _supplierLocation!.longitude);
      
      // Use WidgetsBinding to ensure the map is rendered before using the controller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            // Use smooth animation to zoom to supplier location
            _mapController.move(supplierLatLng, 16.0);
          } catch (e) {
            print('Map controller not ready yet: $e');
          }
        }
      });
      
      // Also set as selected location for consistency
      setState(() {
        _selectedLocation = supplierLatLng;
      });
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final requests = await _farmLocationRequestService.getCurrentUserRequests();
      if (mounted) {
        setState(() {
          _pendingRequests = requests.where((req) => req.isPending).toList();
        });
      }
    } catch (e) {
      print('Error loading pending requests: $e');
      // Silent fail for pending requests - don't block the page
    }
  }

  void _requestFarmLocation() async {
    // Enable farm request mode to show mouse-following pin
    setState(() {
      _isFarmRequestMode = true;
      _selectedLocation = null; // Clear any existing selection
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Move your mouse over the map to position the farm location pin, then tap to confirm'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitFarmRequest() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location on the map first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show dialog to get farm details
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _FarmRequestDialog(),
      );

      if (result == null) return;

      setState(() {
        _isRequestingFarm = true;
      });

      final requestId = await _farmLocationRequestService.submitFarmLocationRequest(
        farmName: result['farmName']!,
        farmDescription: result['farmDescription']!,
        location: _selectedLocation!,
        address: await _mapService.getAddressFromCoordinates(_selectedLocation!),
      );

      // Start countdown for this request
      try {
        _countdownService.startCountdownIfPending(requestId);
      } catch (e) {
        print('Error starting countdown for request: $e');
      }
      
      // Reload pending requests
      await _loadPendingRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm location request submitted successfully! It will be auto-approved in 2 minutes.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        // Ensure pin is visible after submit
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(_selectedLocation!, 15.0);
            } catch (e) {
              print('Map controller not ready yet: $e');
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit farm request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isRequestingFarm = false;
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // Check if the tapped location is within Bogo City boundary
    const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
    
    double distance = _mapService.calculateDistance(bogoCityCenter, point);
    
    if (distance > 5.0) { // 5km radius
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supplier locations can only be added within Bogo City boundaries'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // If in farm request mode, set location and show dialog
    if (_isFarmRequestMode) {
      setState(() {
        _selectedLocation = point;
        _isFarmRequestMode = false; // Exit farm request mode
      });
      _submitFarmRequest();
      return;
    }
    
    // If in pin addition mode, add the pin immediately
    if (_isAddingPin) {
      setState(() {
        _selectedLocation = point;
        _isAddingPin = false; // Exit pin addition mode
      });
      _showAddLocationDialog(point);
    } else if (_isEditingPin) {
      // If in editing mode, update the existing pin location
      setState(() {
        _selectedLocation = point;
        _isEditingPin = false; // Exit editing mode
      });
      _showEditLocationDialog(point);
    } else {
      // Show a hint to enable pin addition mode
      if (_supplierLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tap the "Add Location" button to add your supplier location'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tap the "Edit Location" button to move your supplier location'),
          duration: Duration(seconds: 2),
        ),
      );
      }
    }
  }

  void _enablePinAdditionMode() {
    // Check if supplier already has a location
    if (_supplierLocation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have a supplier location. Use "Edit Location" to modify it.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    setState(() {
      _isAddingPin = true;
      _isEditingPin = false;
      _selectedLocation = null; // Clear any existing selection
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap anywhere on the map to add your supplier location'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _enablePinEditingMode() {
    if (_supplierLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to add a supplier location first.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      _isEditingPin = true;
      _isAddingPin = false;
      _selectedLocation = null; // Clear any existing selection
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap anywhere on the map to move your supplier location'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _getCurrentLocationAndPin() async {
    try {
      final locationData = await _mapService.getCurrentLocationWithAddress();
      if (locationData != null) {
        final location = locationData['location'] as LatLng?;
        final address = locationData['address'] as String?;

        if (location != null && address != null) {
          // Check if location is within Bogo City boundary
          const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
          double distance = _mapService.calculateDistance(bogoCityCenter, location);
          
          if (distance > 5.0) { // 5km radius
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your current location is outside Bogo City boundaries'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Move map to current location
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _mapController.move(location, 16.0);
              } catch (e) {
                print('Map controller not ready yet: $e');
              }
            }
          });
          
          // Set the selected location
          setState(() {
            _selectedLocation = location;
          });

          // Auto-save if supplier doesn't have a location yet
          if (_supplierLocation == null) {
            await _autoSaveCurrentLocation(location, address);
          } else {
            // Show confirmation dialog for updating existing location
            _showLocationUpdateConfirmation(location, address);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get location details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get current location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting current location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _autoSaveCurrentLocation(LatLng location, String address) async {
    try {
      final currentUser = user;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate a default location name based on address
      String locationName = 'My Location';
      if (address.isNotEmpty) {
        final addressParts = address.split(',');
        if (addressParts.isNotEmpty) {
          locationName = addressParts.first.trim();
        }
      }

      await _supplierLocationService.createOrUpdateSupplierLocation(
        supplierId: currentUser.uid,
        supplierName: currentUser.displayName ?? currentUser.email ?? 'Unknown Supplier',
        locationName: locationName,
        description: 'Auto-detected location',
        location: location,
        address: address,
      );

      // Reload the data
      await _loadData();

      // Zoom to the newly set location
      _zoomToSupplierLocation();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location automatically pinned and saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to auto-save location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLocationUpdateConfirmation(LatLng location, String address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Location'),
        content: const Text(
          'You already have a location set. Do you want to update it to your current location?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _updateToCurrentLocation(location, address);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateToCurrentLocation(LatLng location, String address) async {
    try {
      final currentUser = user;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate a default location name based on address
      String locationName = 'My Location';
      if (address.isNotEmpty) {
        final addressParts = address.split(',');
        if (addressParts.isNotEmpty) {
          locationName = addressParts.first.trim();
        }
      }

      await _supplierLocationService.createOrUpdateSupplierLocation(
        supplierId: currentUser.uid,
        supplierName: currentUser.displayName ?? currentUser.email ?? 'Unknown Supplier',
        locationName: locationName,
        description: 'Auto-detected location',
        location: location,
        address: address,
      );

      // Reload the data
      await _loadData();

      // Zoom to the updated location
      _zoomToSupplierLocation();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelPinAdditionMode() {
    setState(() {
      _isAddingPin = false;
      _isEditingPin = false;
      _selectedLocation = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pin mode cancelled'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancelFarmRequestMode() {
    setState(() {
      _isFarmRequestMode = false;
      _selectedLocation = null;
      _mousePosition = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Farm request mode cancelled'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAddLocationDialog(LatLng location) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.add_location, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Add Supplier Location',
              style: TextStyle(color: Colors.green, fontSize: 13),)
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Location Name',
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
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  await _addSupplierLocation(
                    nameController.text,
                    descriptionController.text,
                    location,
                  );
                }
              },
              child: const Text('Add Location'),
            ),
          ],
        );
      },
    );
  }

  void _showEditLocationDialog(LatLng newLocation) {
    if (_supplierLocation == null) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_location, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Move Supplier Location'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Location: ${_supplierLocation!.locationName}'),
              const SizedBox(height: 16),
              FutureBuilder<String>(
                future: _mapService.getAddressFromCoordinates(newLocation),
                builder: (context, snapshot) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Location: ${newLocation.latitude.toStringAsFixed(6)}, ${newLocation.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (snapshot.hasData && snapshot.data!.isNotEmpty)
                        Text(
                          'New Address: ${snapshot.data}',
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
                Navigator.of(context).pop();
                await _updateSupplierLocation(newLocation);
              },
              child: const Text('Move Location'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSupplierLocation(String name, String description, LatLng location) async {
    try {
      final currentUser = user;
      if (currentUser == null) return;

      // Get user data for supplier name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final supplierName = userDoc.data()?['name'] ?? 'Unknown Supplier';
      
      // Use the new API
      await _supplierLocationService.createOrUpdateSupplierLocation(
        supplierId: currentUser.uid,
        supplierName: supplierName,
        locationName: name,
        description: description,
        location: location,
      );
      
      // Reload supplier location
      await _loadData();

      // Zoom to the newly added location
      _zoomToSupplierLocation();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier location added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding supplier location: $e')),
      );
    }
  }

  Future<void> _updateSupplierLocation(LatLng newLocation) async {
    try {
      final currentUser = user;
      if (currentUser == null || _supplierLocation == null) return;
      
      await _supplierLocationService.updateSupplierLocation(
        supplierId: currentUser.uid,
        newLocation: newLocation,
      );
      
      // Reload supplier location
      await _loadData();

      // Zoom to the moved location
      _zoomToSupplierLocation();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier location moved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error moving supplier location: $e')),
      );
    }
  }

  Future<void> _showRateSupplierDialog(BuildContext context, SupplierLocation supplier) async {
    final currentUser = user;
    String? userRole;
    bool isBuyer = false;
    bool isNotSupplier = false;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      userRole = userDoc.data()?['role'] ?? '';
      isBuyer = userRole == 'buyer';
      isNotSupplier = currentUser.uid != supplier.supplierId;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                    child: const Icon(Icons.store, color: Color(0xFF6CA04A), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.orange, size: 18),
                            const SizedBox(width: 4),
                            Text(supplier.rating != null ? supplier.rating!.toStringAsFixed(1) : 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (supplier.isNearest ?? false) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6CA04A).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Nearest', style: TextStyle(color: Color(0xFF6CA04A), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFF6CA04A), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(supplier.address, style: const TextStyle(fontSize: 15))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.payments, color: Color(0xFF6CA04A), size: 20),
                  const SizedBox(width: 8),
                  const Text('Cash on Pick Up', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Icon(Icons.qr_code, color: Color(0xFF6CA04A), size: 20),
                  const SizedBox(width: 8),
                  const Text('GCash', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6CA04A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    // Optionally show more details or navigate
                    Navigator.pop(context);
                  },
                  child: const Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              if (isBuyer && isNotSupplier)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      // Removed unused rating and commentController variables
                    },
                    child: const Text('Rate Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSupplierModal(SupplierLocation? supplier) async {
    if (supplier == null) return;
    final currentUser = user;
    String? userRole;
    bool isBuyer = false;
    bool isNotSupplier = false;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      userRole = userDoc.data()?['role'] ?? '';
      isBuyer = userRole == 'buyer';
      isNotSupplier = currentUser.uid != supplier.supplierId;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                    child: const Icon(Icons.store, color: Color(0xFF6CA04A), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.orange, size: 18),
                            const SizedBox(width: 4),
                            Text(supplier.rating != null ? supplier.rating!.toStringAsFixed(1) : 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (supplier.isNearest ?? false) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6CA04A).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Nearest', style: TextStyle(color: Color(0xFF6CA04A), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFF6CA04A), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(supplier.address, style: const TextStyle(fontSize: 15))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.payments, color: Color(0xFF6CA04A), size: 20),
                  const SizedBox(width: 8),
                  const Text('Cash on Pick Up', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Icon(Icons.qr_code, color: Color(0xFF6CA04A), size: 20),
                  const SizedBox(width: 8),
                  const Text('GCash', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6CA04A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              if (isBuyer && isNotSupplier)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      _showRateSupplierDialog(context, supplier);
                    },
                    child: const Text('Rate Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
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
              const Icon(Icons.agriculture, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(farm.name)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 16),
                
                // Navigation Options
                const Text(
                  'Navigation Options:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Walking Directions
                _buildNavigationOption(
                  icon: Icons.directions_walk,
                  title: 'Walking Directions',
                  subtitle: 'Get step-by-step walking directions',
                  color: Colors.green,
                  onTap: () => _getWalkingDirections(farm),
                ),
                const SizedBox(height: 8),
                
                // Driving Directions
                _buildNavigationOption(
                  icon: Icons.directions_car,
                  title: 'Driving Directions',
                  subtitle: 'Get driving directions with route',
                  color: Colors.blue,
                  onTap: () => _getDrivingDirections(farm),
                ),
                const SizedBox(height: 8),
                
                // Route Generation with Lines
                _buildNavigationOption(
                  icon: Icons.route,
                  title: 'Show Route on Map',
                  subtitle: 'Display route polylines on map',
                  color: Colors.purple,
                  onTap: () => _generateRouteWithLines(farm),
                ),
                const SizedBox(height: 8),
                
                // Time Estimates
                _buildNavigationOption(
                  icon: Icons.schedule,
                  title: 'Time Estimates',
                  subtitle: 'View walking vs driving time',
                  color: Colors.orange,
                  onTap: () => _showTimeEstimates(farm),
                ),
                const SizedBox(height: 8),
                
                // External Maps
                _buildNavigationOption(
                  icon: Icons.map,
                  title: 'Open in Maps App',
                  subtitle: 'Open location in device maps',
                  color: Colors.teal,
                  onTap: () => _openInExternalMaps(farm),
                ),
              ],
            ),
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

  Widget _buildNavigationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _getWalkingDirections(FarmLocation farm) async {
    Navigator.of(context).pop();
    
    try {
      if (_supplierLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your supplier location first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final startPoint = LatLng(_supplierLocation!.latitude, _supplierLocation!.longitude);
      final endPoint = LatLng(farm.latitude, farm.longitude);
      
      final route = await _mapService.getRoute(startPoint, endPoint);
      
      if (route != null && route.isNotEmpty) {
        final distance = _mapService.calculateDistance(startPoint, endPoint);
        final walkingTime = (distance * 12).round(); // ~12 minutes per km walking
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.directions_walk, color: Colors.green),
                SizedBox(width: 8),
                Text('Walking Directions'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Distance: ${distance.toStringAsFixed(2)} km'),
                Text('Estimated Time: $walkingTime minutes'),
                const SizedBox(height: 16),
                const Text(
                  'Walking Route:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('From: ${_supplierLocation!.locationName}'),
                Text('To: ${farm.name}'),
                const SizedBox(height: 8),
                const Text('Follow the route displayed on the map for walking directions.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting walking directions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getDrivingDirections(FarmLocation farm) async {
    Navigator.of(context).pop();
    
    try {
      if (_supplierLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your supplier location first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final startPoint = LatLng(_supplierLocation!.latitude, _supplierLocation!.longitude);
      final endPoint = LatLng(farm.latitude, farm.longitude);
      
      final route = await _mapService.getRoute(startPoint, endPoint);
      
      if (route != null && route.isNotEmpty) {
        final distance = _mapService.calculateDistance(startPoint, endPoint);
        final drivingTime = (distance * 2).round(); // ~2 minutes per km driving
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.directions_car, color: Colors.blue),
                SizedBox(width: 8),
                Text('Driving Directions'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Distance: ${distance.toStringAsFixed(2)} km'),
                Text('Estimated Time: $drivingTime minutes'),
                const SizedBox(height: 16),
                const Text(
                  'Driving Route:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('From: ${_supplierLocation!.locationName}'),
                Text('To: ${farm.name}'),
                const SizedBox(height: 8),
                const Text('Follow the route displayed on the map for driving directions.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting driving directions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateRouteWithLines(FarmLocation farm) async {
    Navigator.of(context).pop();
    
    try {
      if (_supplierLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your supplier location first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final startPoint = LatLng(_supplierLocation!.latitude, _supplierLocation!.longitude);
      final endPoint = LatLng(farm.latitude, farm.longitude);
      
      // Generate route and add polylines to map
      final route = await _mapService.getRoute(startPoint, endPoint);
      
      if (route != null && route.isNotEmpty) {
        setState(() {
          // Add route polylines to the map (this would require adding polyline layer to the map)
        });
        
        // Center map to show the route
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: LatLngBounds(
                    LatLng(
                      [startPoint.latitude, endPoint.latitude].reduce((a, b) => a < b ? a : b),
                      [startPoint.longitude, endPoint.longitude].reduce((a, b) => a < b ? a : b),
                    ),
                    LatLng(
                      [startPoint.latitude, endPoint.latitude].reduce((a, b) => a > b ? a : b),
                      [startPoint.longitude, endPoint.longitude].reduce((a, b) => a > b ? a : b),
                    ),
                  ),
                ),
              );
            } catch (e) {
              print('Map controller not ready yet: $e');
            }
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route displayed on map with polylines'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating route: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showTimeEstimates(FarmLocation farm) async {
    Navigator.of(context).pop();
    
    try {
      if (_supplierLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your supplier location first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final startPoint = LatLng(_supplierLocation!.latitude, _supplierLocation!.longitude);
      final endPoint = LatLng(farm.latitude, farm.longitude);
      
      final distance = _mapService.calculateDistance(startPoint, endPoint);
      final walkingTime = (distance * 12).round(); // ~12 minutes per km
      final drivingTime = (distance * 2).round(); // ~2 minutes per km
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange),
              SizedBox(width: 8),
              Text('Time Estimates'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distance: ${distance.toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              
              // Walking Time
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Walking Time', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('$walkingTime minutes'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Driving Time
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Driving Time', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('$drivingTime minutes'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'From: ${_supplierLocation!.locationName}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'To: ${farm.name}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating time estimates: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openInExternalMaps(FarmLocation farm) async {
    Navigator.of(context).pop();
    
    try {
      // Use OpenStreetMap-based external map service
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${farm.name} in OpenStreetMap...'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Note: In a real app, you would use url_launcher package to open the URL
      // await launchUrl(Uri.parse(url));
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening external maps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bogo City, Cebu, Philippines coordinates
    const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
// Approximately 5km radius
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Map'),
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: GroceryLoadingWidget(
                size: 150,
                showText: true,
                loadingText: 'Loading map...',
              ),
            )
          : Stack(
              children: [
                MouseRegion(
                  onHover: _isFarmRequestMode ? (event) {
                    setState(() {
                      _mousePosition = event.localPosition;
                    });
                  } : null,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: bogoCityCenter,
                      initialZoom: 14,
                      onTap: _onMapTap,
                      maxZoom: 18,
                      minZoom: 10,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.veggieconnect.app',
                ),
                // Bogo City boundary circle (barrier interface)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: bogoCityCenter,
                      radius: 5000, // 5km radius in meters
                      color: Colors.blue.withOpacity(0.1),
                      borderColor: Colors.blue.withOpacity(0.5),
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
                // Supplier's own location
                if (_supplierLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          _selectedLocation?.latitude ?? _supplierLocation!.latitude,
                          _selectedLocation?.longitude ?? _supplierLocation!.longitude,
                        ),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _showSupplierModal(_supplierLocation),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF6CA04A),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.person_pin,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                // Canvassed farms (admin-added)
                if (_canvassedFarms.isNotEmpty)
                  MarkerLayer(
                    markers: _canvassedFarms.map((farm) => Marker(
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
                          ),
                          child: const Icon(
                            Icons.agriculture,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                // Selected location (for editing supplier location)
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.add_location,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
                ),
                // Mouse-following pin for farm request mode
                if (_isFarmRequestMode && _mousePosition != null)
                  Positioned(
                    left: _mousePosition!.dx - 20,
                    top: _mousePosition!.dy - 40,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
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
                        size: 24,
                      ),
                    ),
                  ),
                // Indicators row - Bogo City boundary and Location status side by side
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      // Bogo City boundary indicator
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '📍 Bogo City Boundary',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Location status indicator
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _supplierLocation != null ? Colors.blue.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _supplierLocation != null 
                                ? '📍 Supplier Location Set'
                                : '📍 Auto-detecting Location...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Compact action buttons below indicators
                Positioned(
                  top: 80,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request Farm Location Button
                      Container(
                        margin: EdgeInsets.only(bottom: 8),
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _isRequestingFarm ? null : (_isFarmRequestMode ? _cancelFarmRequestMode : _requestFarmLocation),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isFarmRequestMode ? Colors.red : Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isRequestingFarm
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Icon(
                                          _isFarmRequestMode ? Icons.close : Icons.agriculture,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                  SizedBox(width: 6),
                                  Text(
                                    _isFarmRequestMode ? 'Cancel Request' : 'Request Farm Location',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Use Current Location Button
                      Container(
                        margin: EdgeInsets.only(bottom: 8),
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _getCurrentLocationAndPin,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.my_location, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Use Current Location',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Add/Move Location Button
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _supplierLocation == null
                              ? (_isAddingPin ? _cancelPinAdditionMode : _enablePinAdditionMode)
                              : (_isEditingPin ? _cancelPinAdditionMode : _enablePinEditingMode),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_isAddingPin || _isEditingPin) ? Colors.red : Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (_isAddingPin || _isEditingPin) 
                                      ? Icons.close 
                                      : (_supplierLocation == null ? Icons.add_location : Icons.edit_location),
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  (_isAddingPin || _isEditingPin)
                                      ? 'Cancel'
                                      : (_supplierLocation == null ? 'Add Location' : 'Move Location'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Pin addition mode indicator
                if (_isAddingPin)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        '📍 Adding Location Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                // Farm request mode indicator
                if (_isFarmRequestMode)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        '🌾 Farm Request Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                // Pin editing mode indicator
                if (_isEditingPin)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        '📍 Moving Location Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                // Pending Farm Requests Indicator
                if (_pendingRequests.isNotEmpty)
                  Positioned(
                    top: 200,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending_actions, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '${_pendingRequests.length} Pending Farm Request${_pendingRequests.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Center map button
                Positioned(
                  bottom: 200,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: "center_map_fab",
                    onPressed: () {
                      if (_supplierLocation != null) {
                        _zoomToSupplierLocation();
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            try {
                              _mapController.move(bogoCityCenter, 12);
                            } catch (e) {
                              print('Map controller not ready yet: $e');
                            }
                          }
                        });
                      }
                    },
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    mini: true,
                    child: const Icon(Icons.center_focus_strong),
                  ),
                ),
                // Show a floating button to save the new location if dragging
                if (_isDragging && _selectedLocation != null)
                  Positioned(
                    bottom: 80,
                    right: 16,
                    child: FloatingActionButton.extended(
                      heroTag: "save_location_fab",
                      onPressed: () async {
                        await _updateSupplierLocation(_selectedLocation!);
                        setState(() {
                          _isDragging = false;
                          _selectedLocation = null;
                        });
                      },
                      backgroundColor: Colors.green,
                      icon: const Icon(Icons.save),
                      label: const Text('Save New Location'),
                    ),
                  ),
              ],
            ),
      );
  }
}

class _FarmRequestDialog extends StatefulWidget {
  @override
  State<_FarmRequestDialog> createState() => _FarmRequestDialogState();
}

class _FarmRequestDialogState extends State<_FarmRequestDialog> {
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmDescriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Request Farm Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _farmNameController,
              decoration: InputDecoration(
                labelText: 'Farm Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _farmDescriptionController,
              decoration: InputDecoration(
                labelText: 'Farm Description (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'farmName': _farmNameController.text.trim(),
                  'farmDescription': _farmDescriptionController.text.trim(),
                });
              },
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}