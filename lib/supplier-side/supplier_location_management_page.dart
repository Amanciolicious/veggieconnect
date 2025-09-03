// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:veggieconnect/models/supplier_location.dart';
import 'package:veggieconnect/models/farm_location_request.dart';
import 'package:veggieconnect/services/supplier_location_service.dart';
import 'package:veggieconnect/services/map_service.dart';
import 'package:veggieconnect/services/farm_location_request_service.dart';
import 'package:veggieconnect/services/farm_location_countdown_service.dart';

class SupplierLocationManagementPage extends StatefulWidget {
  const SupplierLocationManagementPage({super.key});

  @override
  State<SupplierLocationManagementPage> createState() => _SupplierLocationManagementPageState();
}

class _SupplierLocationManagementPageState extends State<SupplierLocationManagementPage> {
  final MapController _mapController = MapController();
  final SupplierLocationService _supplierLocationService = SupplierLocationService();
  final FarmLocationRequestService _farmLocationRequestService = FarmLocationRequestService();
  final FarmLocationCountdownService _countdownService = FarmLocationCountdownService();
  final MapService _mapService = MapService();
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  
  SupplierLocation? _currentLocation;
  LatLng? _selectedLocation;
  String _currentAddress = '';
  List<FarmLocationRequest> _pendingRequests = [];
  Timer? _countdownTimer;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isGettingCurrentLocation = false;
  bool _isRequestingFarm = false;
  String? _errorMessage;
  String _locationInputMode = 'map'; // 'map' or 'manual'

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadPendingRequests();
    // Start countdowns for existing pending requests
    _countdownService.startCountdownForPendingRequests();
    
    // Start timer to update countdown display every second
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild to update the countdown display
        });
      }
    });
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _countdownTimer?.cancel();
    _countdownService.dispose();
    super.dispose();
  }

  String _formatCountdown(FarmLocationRequest request) {
    if (request.autoApprovalAt == null) return '';
    
    final now = DateTime.now();
    final timeLeft = request.autoApprovalAt!.difference(now);
    
    if (timeLeft.isNegative) {
      return 'Auto-approval overdue';
    }
    
    final minutes = timeLeft.inMinutes;
    final seconds = timeLeft.inSeconds % 60;
    return 'Auto-approval in ${minutes}m ${seconds}s';
  }

  Future<void> _loadPendingRequests() async {
    try {
      final requests = await _farmLocationRequestService.getCurrentUserRequests();
      setState(() {
        _pendingRequests = requests.where((req) => req.isPending).toList();
      });
    } catch (e) {
      // Silent fail for pending requests
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final location = await _supplierLocationService.getCurrentUserSupplierLocation();
      
      if (location != null) {
        setState(() {
          _currentLocation = location;
          _selectedLocation = LatLng(location.latitude, location.longitude);
          _currentAddress = location.address;
          _locationNameController.text = location.locationName;
          _descriptionController.text = location.description;
        });
      } else {
        // No existing location, get current device location
        await _getCurrentDeviceLocation();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load location: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentDeviceLocation() async {
    try {
      setState(() {
        _isGettingCurrentLocation = true;
        _errorMessage = null;
      });

      final locationData = await _mapService.getCurrentLocationWithAddress();
      if (locationData != null) {
        final location = locationData['location'] as LatLng?;
        final address = locationData['address'] as String?;

        if (location != null && address != null) {
          setState(() {
            _selectedLocation = location;
            _currentAddress = address;
            _isGettingCurrentLocation = false;
            // If manual mode is active, fill the fields too
            if (_locationInputMode == 'manual') {
              _latController.text = location.latitude.toStringAsFixed(6);
              _lngController.text = location.longitude.toStringAsFixed(6);
            }
          });
          // Center map and show pin
          _mapController.move(location, 16.0);
        } else {
          setState(() {
            _errorMessage = 'Failed to get location details';
            _isGettingCurrentLocation = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to get current location';
          _isGettingCurrentLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get current location: $e';
        _isGettingCurrentLocation = false;
      });
    }
  }

  Future<void> _updateLocation() async {
    if (_selectedLocation == null) {
      setState(() {
        _errorMessage = 'Please select a location first';
      });
      return;
    }

    if (_locationNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a location name';
      });
      return;
    }

    try {
      setState(() {
        _isUpdating = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supplierLocationService.createOrUpdateSupplierLocation(
        supplierId: user.uid,
        supplierName: user.displayName ?? user.email ?? 'Unknown Supplier',
        locationName: _locationNameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _selectedLocation,
        address: _currentAddress,
      );

      // Reload the current location
      await _loadCurrentLocation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update location: $e';
      });
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _onMapTapped(LatLng point) {
    if (_locationInputMode != 'map') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switch to "Pin on Map" to select by tapping the map.')),
      );
      return;
    }
    setState(() {
      _selectedLocation = point;
    });
    _updateAddressFromLocation(point);
  }

  Future<void> _updateAddressFromLocation(LatLng location) async {
    try {
      final address = await _mapService.getAddressFromCoordinates(location);
      setState(() {
        _currentAddress = address;
      });
    } catch (e) {
      setState(() {
        _currentAddress = 'Address not available';
      });
    }
  }

  Future<void> _requestFarmLocation() async {
    LatLng? chosenLocation;
    String address = _currentAddress;
    if (_locationInputMode == 'map') {
      if (_selectedLocation == null) {
        setState(() {
          _errorMessage = 'Please tap on the map to choose a location';
        });
        return;
      }
      chosenLocation = _selectedLocation;
    } else {
      // Manual coordinates mode
      final latText = _latController.text.trim();
      final lngText = _lngController.text.trim();
      if (latText.isEmpty || lngText.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter both latitude and longitude';
        });
        return;
      }
      final double? lat = double.tryParse(latText);
      final double? lng = double.tryParse(lngText);
      if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
        setState(() {
          _errorMessage = 'Please enter valid coordinates';
        });
        return;
      }
      chosenLocation = LatLng(lat, lng);
      // Reverse geocode for display
      try {
        address = await _mapService.getAddressFromCoordinates(chosenLocation);
      } catch (_) {}
      setState(() {
        _selectedLocation = chosenLocation;
        _currentAddress = address;
      });
      // Center map to chosen point so a pin is visible
      _mapController.move(chosenLocation, 15.0);
    }

    // Show dialog to get farm details
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _FarmRequestDialog(),
    );

    if (result == null) return;

    try {
      setState(() {
        _isRequestingFarm = true;
        _errorMessage = null;
      });

      final requestId = await _farmLocationRequestService.submitFarmLocationRequest(
        farmName: result['farmName']!,
        farmDescription: result['farmDescription']!,
        location: chosenLocation!,
        address: address,
      );

      // Start countdown for this request
      _countdownService.startCountdownIfPending(requestId);
      
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
        if (chosenLocation != null) {
          _mapController.move(chosenLocation, 15.0);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit farm request: $e';
      });
    } finally {
      setState(() {
        _isRequestingFarm = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        title: Text(
          'Manage Location',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6CA04A),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : StreamBuilder<List<FarmLocationRequest>>(
                  stream: _farmLocationRequestService.streamCurrentUserRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _pendingRequests = snapshot.data!.where((req) => req.isPending).toList();
                    }
                    return _buildLocationManagement();
                  },
                ),
    );
  }

  Widget _buildLocationManagement() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            margin: EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLocation ?? LatLng(14.5995, 120.9842),
                  initialZoom: 13.0,
                  onTap: (tapPosition, point) {
                    _onMapTapped(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.veggieconnect.app',
                  ),
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          child: Icon(
                            Icons.location_pin,
                            color: Color(0xFF6CA04A),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Input mode toggle
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'map',
                        groupValue: _locationInputMode,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _locationInputMode = v;
                          });
                        },
                        title: Text('Pin on Map'),
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'manual',
                        groupValue: _locationInputMode,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _locationInputMode = v;
                          });
                        },
                        title: Text('Manual Coordinates'),
                        dense: true,
                      ),
                    ),
                  ],
                ),
                if (_locationInputMode == 'manual') ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF6CA04A)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF6CA04A)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 8),
                // Pending Requests Section
                if (_pendingRequests.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pending_actions, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Pending Farm Location Requests',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        ...(_pendingRequests.map((request) => Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.farmName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                request.farmDescription.isNotEmpty 
                                    ? request.farmDescription 
                                    : 'No description',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatCountdown(request),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: request.isAutoApprovalDue ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )).toList()),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                
                if (_currentAddress.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF6CA04A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Color(0xFF6CA04A).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Selected: $_currentAddress',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF222222),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                TextField(
                  controller: _locationNameController,
                  decoration: InputDecoration(
                    labelText: 'Location Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF6CA04A)),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF6CA04A)),
                    ),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 16),
                
                // Current Location Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGettingCurrentLocation ? null : _getCurrentDeviceLocation,
                    icon: _isGettingCurrentLocation
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.my_location),
                    label: Text('Use Current Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                
                // Update Location Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _updateLocation,
                    icon: _isUpdating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.save),
                    label: Text('Update Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6CA04A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                
                // Request Farm Location Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRequestingFarm ? null : _requestFarmLocation,
                    icon: _isRequestingFarm
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.agriculture),
                    label: Text('Request Farm Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20), // Extra padding at bottom
              ],
            ),
          ),
        ),
      ],
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