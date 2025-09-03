// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/map_service.dart';

class LocationSelectionPage extends StatefulWidget {
  final Function(LatLng location, String address) onLocationSelected;
  
  const LocationSelectionPage({
    super.key,
    required this.onLocationSelected,
  });

  @override
  State<LocationSelectionPage> createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final MapService _mapService = MapService();
  
  bool _isLoading = false;
  bool _useCurrentLocation = false;
  bool _useManualCoordinates = false;
  LatLng? _currentLocation;
  String _currentAddress = '';
  LatLng? _manualLocation;
  String _manualAddress = '';

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _initializeLocations() {
    // Removed this function as it's not being used anywhere in the code
  }

  void _filterLocations(String query) {
    // Removed this function as it's not being used anywhere in the code
  }

  List<Map<String, dynamic>> _getAllLocations() {
    // Removed this function as it's not being used anywhere in the code
    return [];
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.whileInUse || 
        permission == LocationPermission.always) {
      setState(() {
        _useCurrentLocation = true;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        _showLocationServiceDialog();
        return;
      }

      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        _showPermissionPermanentlyDeniedDialog();
        return;
      }

      // Get current position with extended timeout and lower accuracy as fallback
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        );
      } catch (e) {
        // Fallback to lower accuracy if high accuracy fails
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        );
      }

      final location = LatLng(position.latitude, position.longitude);
      
      // Get address from coordinates with fallback
      String address;
      try {
        address = await _mapService.getAddressFromCoordinates(location);
        if (address.isEmpty) {
          address = 'Location found: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        }
      } catch (e) {
        address = 'Location found: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
      }

      setState(() {
        _currentLocation = location;
        _currentAddress = address;
        _useCurrentLocation = true;
        _useManualCoordinates = false;
        _isLoading = false;
      });

      _showSuccessSnackBar('Current location obtained successfully!');

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showLocationErrorDialog(e.toString());
    }
  }

  Future<void> _getManualLocation() async {
    if (_latitudeController.text.trim().isEmpty || _longitudeController.text.trim().isEmpty) {
      _showErrorDialog('Please enter both latitude and longitude');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final latitude = double.parse(_latitudeController.text.trim());
      final longitude = double.parse(_longitudeController.text.trim());
      
      // Validate coordinate ranges
      if (latitude < -90 || latitude > 90) {
        _showErrorDialog('Latitude must be between -90 and 90');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      if (longitude < -180 || longitude > 180) {
        _showErrorDialog('Longitude must be between -180 and 180');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final location = LatLng(latitude, longitude);
      
      // Get address from coordinates
      final address = await _mapService.getAddressFromCoordinates(location);
      
      setState(() {
        _manualLocation = location;
        _manualAddress = address.isNotEmpty ? address : 'Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
        _useManualCoordinates = true;
        _useCurrentLocation = false;
        _isLoading = false;
      });

      _showSuccessSnackBar('Location set successfully!');

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Invalid coordinates. Please enter valid numbers.');
    }
  }

  void _confirmLocation() {
    if (_useCurrentLocation && _currentLocation != null) {
      widget.onLocationSelected(_currentLocation!, _currentAddress);
      Navigator.of(context).pop();
    } else if (_useManualCoordinates && _manualLocation != null) {
      widget.onLocationSelected(_manualLocation!, _manualAddress);
      Navigator.of(context).pop();
    } else {
      _showErrorDialog('Please select a location first');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Location Services Disabled'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location services are currently disabled on your device.'),
            SizedBox(height: 12),
            Text(
              'To use your current location:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Go to your device Settings'),
            Text('2. Find Location or Privacy settings'),
            Text('3. Turn on Location Services'),
            Text('4. Return to this app and try again'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Alternative: You can enter coordinates manually below.',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _getCurrentLocation(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6CA04A),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_disabled, color: Colors.red),
            SizedBox(width: 8),
            Text('Location Permission Denied'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location permission is required to find your current location.'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'You can still enter coordinates manually below.',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _getCurrentLocation(); // Retry - will ask for permission again
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6CA04A),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.red),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location permissions are permanently denied.'),
            SizedBox(height: 12),
            Text(
              'To enable location access:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Go to your device Settings'),
            Text('2. Find Apps or Application Manager'),
            Text('3. Find VeggieConnect'),
            Text('4. Go to Permissions'),
            Text('5. Enable Location permission'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Alternative: You can enter coordinates manually below.',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Location Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Failed to get your current location.'),
            SizedBox(height: 8),
            Text(
              'Error details: $error',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Troubleshooting tips:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• Make sure you\'re not indoors'),
                  Text('• Check if location services are enabled'),
                  Text('• Try moving to an open area'),
                  Text('• Use manual coordinates as alternative'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _getCurrentLocation(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6CA04A),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Select Location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Choose your location to find nearby suppliers',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: screenWidth * 0.06),
            
            // Current Location Option
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _useCurrentLocation 
                      ? Color(0xFF6CA04A) 
                      : Color(0xFF8D9773).withOpacity(0.2),
                  width: _useCurrentLocation ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _getCurrentLocation,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF6CA04A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: Color(0xFF6CA04A),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Current Location',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (_currentAddress.isNotEmpty)
                            Text(
                              _currentAddress,
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Color(0xFF757575),
                                fontFamily: 'Poppins',
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
                        ),
                      )
                    else if (_useCurrentLocation)
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF6CA04A),
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: screenWidth * 0.04),
            
            // Manual Location Option
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _useManualCoordinates 
                      ? Color(0xFF6CA04A) 
                      : Color(0xFF8D9773).withOpacity(0.2),
                  width: _useManualCoordinates ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF6CA04A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit_location,
                          color: Color(0xFF6CA04A),
                          size: 24,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.04),
                      Text(
                        'Enter Coordinates Manually',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latitudeController,
                          decoration: InputDecoration(
                            hintText: 'Latitude',
                            hintStyle: TextStyle(
                              color: Color(0xFF757575),
                              fontFamily: 'Poppins',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF8D9773).withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF6CA04A), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: screenWidth * 0.04,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: TextField(
                          controller: _longitudeController,
                          decoration: InputDecoration(
                            hintText: 'Longitude',
                            hintStyle: TextStyle(
                              color: Color(0xFF757575),
                              fontFamily: 'Poppins',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF8D9773).withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF6CA04A), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: screenWidth * 0.04,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  ElevatedButton(
                    onPressed: _getManualLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6CA04A),
                      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Get Location',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_useCurrentLocation || _useManualCoordinates) 
                      ? Color(0xFF6CA04A) 
                      : Color(0xFF757575),
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (_useCurrentLocation || _useManualCoordinates) 
                    ? _confirmLocation 
                    : null,
                child: Text(
                  'Confirm Location',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}