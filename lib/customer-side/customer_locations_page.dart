// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import '../widgets/role_page_header.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/supplier_location.dart';
import '../services/supplier_location_service.dart';
import '../services/map_service.dart';
import '../widgets/lottie_loading_widget.dart';

class FarmLocationsPage extends StatefulWidget {
  const FarmLocationsPage({super.key});

  @override
  State<FarmLocationsPage> createState() => _FarmLocationsPageState();
}

class _FarmLocationsPageState extends State<FarmLocationsPage> {
  final MapController _mapController = MapController();
  final SupplierLocationService _supplierLocationService = SupplierLocationService();
  final MapService _mapService = MapService();
  
  List<SupplierLocation> _allSupplierLocations = [];
  LatLng? _userLocation;
  bool _isLoading = true;
  final double _searchRadius = 10.0; // Default 10km radius
  final double _vicinityRadius = 1.0; // 1km radius for automatic guides
  bool _hasShownVicinityGuide = false; // Track if guide has been shown
  
  List<LatLng>? _routeLine; // Store the current route line
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    // Automatically try to get current location on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _useCurrentLocation();
    });
  }

  void _initializeLocation() async {
    // Use a default location (Bogo City center) for demo purposes
    const LatLng defaultLocation = LatLng(11.0474, 124.0051);
    
    setState(() {
      _userLocation = defaultLocation;
    });
    
    await _loadSupplierLocations();
  }

  Future<void> _loadSupplierLocations() async {
    if (_userLocation == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final locations = await _supplierLocationService.getAllSupplierLocations();
      
      // Filter locations based on distance
      final nearbyLocations = locations.where((location) {
        final distance = _mapService.calculateDistance(
          _userLocation!,
          LatLng(location.latitude, location.longitude),
        );
        return distance <= _searchRadius;
      }).toList();

      // Sort by distance
      nearbyLocations.sort((a, b) {
        final distanceA = _mapService.calculateDistance(
          _userLocation!,
          LatLng(a.latitude, a.longitude),
        );
        final distanceB = _mapService.calculateDistance(
          _userLocation!,
          LatLng(b.latitude, b.longitude),
        );
        return distanceA.compareTo(distanceB);
      });

      setState(() {
        _allSupplierLocations = nearbyLocations;
        _isLoading = false;
      });

      // Show guide for very nearby suppliers if not shown before
      if (nearbyLocations.isNotEmpty && !_hasShownVicinityGuide) {
        _showVicinityGuide(nearbyLocations.first);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading supplier locations: $e')),
        );
      }
    }
  }

  void _showVicinityGuide(SupplierLocation nearestSupplier) {
    _hasShownVicinityGuide = true;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.celebration, color: Colors.orange),
              SizedBox(width: 8),
              Text('Great News!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'There\'s a supplier very close to you!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('${nearestSupplier.locationName} is just ${_mapService.calculateDistance(_userLocation!, LatLng(nearestSupplier.latitude, nearestSupplier.longitude)).toStringAsFixed(1)} km away.'),
              SizedBox(height: 16),
              Text('Would you like to get directions?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Maybe Later'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showRouteDirectionsSupplier(nearestSupplier, 'foot-walking');
              },
              icon: Icon(Icons.directions_walk),
              label: Text('Walking Directions', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showRouteDirectionsSupplier(nearestSupplier, 'driving-car');
              },
              icon: Icon(Icons.directions_car),
              label: Text('Driving Directions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSupplierDetails(SupplierLocation supplier) {
    final double distance = _userLocation != null 
        ? _mapService.calculateDistance(_userLocation!, LatLng(supplier.latitude, supplier.longitude))
        : 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.store, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text(supplier.locationName)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supplier Info Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supplier: ${supplier.supplierName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      // Rating stars and count
                      if (supplier.rating != null && supplier.rating! > 0) ...[
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < supplier.rating!.round() ? Icons.star : Icons.star_border,
                                  color: index < supplier.rating!.round() ? Colors.amber : Colors.grey,
                                  size: 20,
                                );
                              }),
                            ),
                            SizedBox(width: 8),
                            Text(
                              supplier.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              ' (${supplier.ratingCount ?? 0} reviews)',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(Icons.star_border, color: Colors.grey, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'No ratings yet',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 8),
                      
                      // Description
                      Text(
                        'Description: ${supplier.description}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      
                      // Address
                      Text(
                        'Address: ${supplier.address}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      
                      // Coordinates
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Latitude: ${supplier.latitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Longitude: ${supplier.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // Distance if user location available
                      if (_userLocation != null) ...[
                        SizedBox(height: 4),
                        Text(
                          'Distance: ${distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Navigation Options Section
                if (_userLocation != null) ...[
                  SizedBox(height: 16),
                  Text(
                    'Navigation Options:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Walking Directions Button
                  _buildNavigationOption(
                    icon: Icons.directions_walk,
                    title: 'Get Walking Directions',
                    subtitle: 'Best for short distances',
                    color: Colors.green,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showRouteDirectionsSupplier(supplier, 'foot-walking');
                    },
                  ),
                  SizedBox(height: 8),
                  
                  // Driving Directions Button
                  _buildNavigationOption(
                    icon: Icons.directions_car,
                    title: 'Get Driving Directions',
                    subtitle: 'Best for longer distances',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showRouteDirectionsSupplier(supplier, 'driving-car');
                    },
                  ),
                  SizedBox(height: 8),
                  
                  // Generate Route with Lines Button
                  _buildNavigationOption(
                    icon: Icons.route,
                    title: 'Show Route on Map',
                    subtitle: 'Display route line on map',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.of(context).pop();
                      _generateRouteWithLines(supplier);
                    },
                  ),
                  SizedBox(height: 8),
                  
                  // Time Estimates Button
                  _buildNavigationOption(
                    icon: Icons.schedule,
                    title: 'View Time Estimates',
                    subtitle: 'Walking & driving time estimates',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showTimeEstimates(supplier);
                    },
                  ),
                  SizedBox(height: 8),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Text('Close'),
            ),
          ],
          actionsPadding: EdgeInsets.all(16),
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  void _showRouteDirectionsSupplier(SupplierLocation supplier, String profile) {
    // Keep the current modal/dialog open; do not pop here to avoid
    // revealing the underlying browse page unintentionally.
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                profile == 'foot-walking' ? Icons.directions_walk : Icons.directions_car,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text('${profile == 'foot-walking' ? 'Walking' : 'Driving'} Directions'),
            ],
          ),
          content: FutureBuilder(
            future: _mapService.getRoute(
              _userLocation!,
              LatLng(supplier.latitude, supplier.longitude),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: GroceryLoadingWidget(
                    size: 100,
                    showText: true,
                    loadingText: 'Fetching route...'
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text('Error getting directions: ${snapshot.error}');
              }
              final route = snapshot.data;
              if (route == null) {
                return const Text('No route found');
              }
              final Map<String, dynamic> routeData = route;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Route Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Distance: ${routeData['distanceText']}'),
                        Text('Mode: ${profile == 'foot-walking' ? 'Walking' : 'Driving'}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Step-by-step Directions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                      child: _buildRouteInstructions(route),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('Show Route on Map'),
                    onPressed: () {
                      setState(() {
                        _routeLine = [];
                      });
                      Navigator.of(context).pop();
                      // Fit map to route
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _fitMapToRoute();
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openInMapsSupplier(supplier);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open in Maps'),
            ),
          ],
          actionsPadding: EdgeInsets.all(16),
        );
      },
    );
  }

  Widget _buildRouteInstructions(Map<String, dynamic> route) {
    try {
      final Map<String, dynamic> routeData = route;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Route Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Distance: ${routeData['distanceText']}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Step-by-step Directions:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._buildRouteInstructionsSteps(routeData),
        ],
      );
    } catch (e) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Instructions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Follow the route line on the map. For detailed turn-by-turn directions, '
            'use the "Open in Maps" button to open your preferred navigation app.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }
  }

  List<Widget> _buildRouteInstructionsSteps(Map<String, dynamic> routeData) {
    try {
      final distance = (routeData['distance'] as num) / 1000; // km
      
      // Generate realistic step-by-step instructions based on distance
      List<Widget> instructions = [];
      
      if (distance < 0.5) {
        instructions.addAll([
          _buildInstructionStep(1, 'Start from your current location', Icons.my_location),
          _buildInstructionStep(2, 'Walk ${(distance * 1000).round()} meters to the destination', Icons.directions_walk),
          _buildInstructionStep(3, 'You have arrived at your destination', Icons.location_on),
        ]);
      } else if (distance < 1.0) {
        instructions.addAll([
          _buildInstructionStep(1, 'Start from your current location', Icons.my_location),
          _buildInstructionStep(2, 'Walk ${(distance * 1000).round()} meters', Icons.directions_walk),
          _buildInstructionStep(3, 'Continue straight ahead', Icons.trending_up),
          _buildInstructionStep(4, 'You have arrived at your destination', Icons.location_on),
        ]);
      } else if (distance < 2.0) {
        instructions.addAll([
          _buildInstructionStep(1, 'Start from your current location', Icons.my_location),
          _buildInstructionStep(2, 'Walk ${(distance * 1000).round()} meters', Icons.directions_walk),
          _buildInstructionStep(3, 'Follow the main path/road', Icons.trending_up),
          _buildInstructionStep(4, 'Look for landmarks along the way', Icons.landscape),
          _buildInstructionStep(5, 'You have arrived at your destination', Icons.location_on),
        ]);
      } else {
        instructions.addAll([
          _buildInstructionStep(1, 'Start from your current location', Icons.my_location),
          _buildInstructionStep(2, 'Walk ${(distance * 1000).round()} meters', Icons.directions_walk),
          _buildInstructionStep(3, 'Follow the main road/path', Icons.trending_up),
          _buildInstructionStep(4, 'Stay on the designated route', Icons.route),
          _buildInstructionStep(5, 'Watch for traffic and pedestrians', Icons.traffic),
          _buildInstructionStep(6, 'You have arrived at your destination', Icons.location_on),
        ]);
      }
      
      return instructions;
    } catch (e) {
      return [];
    }
  }

  Widget _buildInstructionStep(int stepNumber, String instruction, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    instruction,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openInMapsSupplier(SupplierLocation supplier) {
    // Open supplier location in OpenStreetMap
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${supplier.locationName} in OpenStreetMap...'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              // Note: In a real app, you would use url_launcher package to open the URL
              // await launchUrl(Uri.parse(url));
            },
          ),
        ),
      );
    }
  }

  void _fitMapToRoute() {
    if (_routeLine == null || _routeLine!.isEmpty) return;
    // LatLngBounds requires two points to initialize
    final points = _routeLine!;
    LatLngBounds bounds = LatLngBounds(points.first, points.first);
    for (final point in points) {
      bounds.extend(point);
    }
  }

  void _generateRouteWithLines(SupplierLocation supplier) async {
    if (_userLocation == null) return;
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                height: 40,
                width: 40,
                child: GroceryLoadingWidget(
                  size: 40,
                  showText: false,
                ),
              ),
              SizedBox(width: 16),
              Text('Generating route...'),
            ],
          ),
        ),
      );

      // Get route data
      final route = await _mapService.getRoute(
        _userLocation!,
        LatLng(supplier.latitude, supplier.longitude),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (route != null) {
        setState(() {
          _routeLine = [];
        });

        // Fit map to show the route
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapToRoute();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Route displayed on map'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not generate route'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTimeEstimates(SupplierLocation supplier) {
    if (_userLocation == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange),
              SizedBox(width: 8),
              Text('Time Estimates'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination: ${supplier.supplierName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Distance: ${_mapService.calculateDistance(_userLocation!, LatLng(supplier.latitude, supplier.longitude)).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              
              // Enhanced Time Estimates with Single Route Call
              FutureBuilder(
                future: _mapService.getRoute(_userLocation!, LatLng(supplier.latitude, supplier.longitude)),
                builder: (context, routeSnapshot) {
                  if (routeSnapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_empty, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('Calculating route...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  
                  if (routeSnapshot.hasData && routeSnapshot.data != null) {
                    final route = routeSnapshot.data as Map<String, dynamic>;
                    final walkingTime = route['walkingTime'] as int? ?? 0;
                    final drivingTime = route['drivingTime'] as int? ?? 0;
                    
                    return Column(
                      children: [
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
                              Icon(Icons.directions_walk, color: Colors.green),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Walking Time',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '$walkingTime minutes',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        
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
                              Icon(Icons.directions_car, color: Colors.blue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Driving Time',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '$drivingTime minutes',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Unable to calculate route', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showRouteDirectionsSupplier(supplier, 'foot-walking');
              },
              icon: const Icon(Icons.directions_walk),
              label: const Text('Get Walking Directions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          actionsPadding: EdgeInsets.all(16),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: RolePageHeader(title: 'Supplier Locations'),
      body: Column(
        children: [
          // Header Section - Remove the search field
          Container(
            margin: EdgeInsets.all(screenWidth * 0.04),
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.06),
              child: Column(
                children: [
                  Icon(
                    Icons.location_on,
                    size: screenWidth * 0.12,
                    color: Colors.green,
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  Text(
                    'Discover Local Suppliers',
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  Text(
                    'Find fresh produce from suppliers near you',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Map Section
          Expanded(
            flex: 3,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(screenWidth * 0.05),
                child: _buildMapSection(screenWidth),
              ),
            ),
          ),
          // Farm List Section
          Expanded(
            flex: 2,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nearby Suppliers',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      if (_userLocation != null)
                        IconButton(
                          onPressed: _refreshGPSLocation,
                          icon: Icon(Icons.refresh, color: Colors.green),
                          tooltip: 'Refresh GPS Location',
                        ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  Expanded(
                    child: _buildFarmList(screenWidth),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(double screenWidth) {
    if (_userLocation == null) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: screenWidth * 0.15, color: Colors.grey),
              SizedBox(height: screenWidth * 0.03),
              Text(
                'Location not set',
                style: TextStyle(fontSize: screenWidth * 0.05, color: Colors.grey),
              ),
              SizedBox(height: screenWidth * 0.02),
              Text(
                'Set your location to see nearby suppliers',
                style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation!,
        initialZoom: 13.0,
        maxZoom: 18.0,
        minZoom: 10.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.veggieconnect.app',
        ),
        // User location marker
        MarkerLayer(
          markers: [
            Marker(
              point: _userLocation!,
              width: screenWidth * 0.08,
              height: screenWidth * 0.08,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.person, color: Colors.white, size: screenWidth * 0.05),
              ),
            ),
          ],
        ),
        // Supplier location markers
        MarkerLayer(
          markers: _allSupplierLocations.map((supplier) {
            final distance = _mapService.calculateDistance(
              _userLocation!,
              LatLng(supplier.latitude, supplier.longitude),
            );
            
            return Marker(
              point: LatLng(supplier.latitude, supplier.longitude),
              width: screenWidth * 0.08,
              height: screenWidth * 0.08,
              child: GestureDetector(
                onTap: () => _showSupplierDetails(supplier),
                child: Container(
                  decoration: BoxDecoration(
                    color: distance <= _vicinityRadius ? Colors.orange : Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.store,
                    color: Colors.white,
                    size: screenWidth * 0.05,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Route polyline layer
        if (_routeLine != null && _routeLine!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routeLine!,
                color: Colors.blue,
                strokeWidth: 5.0,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFarmList(double screenWidth) {
    if (_isLoading) {
      return Center(
        child: const GroceryLoadingWidget(
          size: 100,
          showText: true,
          loadingText: 'Loading suppliers...'
        ),
      );
    }

    if (_allSupplierLocations.isEmpty) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.08),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.agriculture,
                size: screenWidth * 0.15,
                color: Colors.green,
              ),
              SizedBox(height: screenWidth * 0.04),
              Text(
                'No Suppliers Found',
                style: TextStyle(
                  fontSize: screenWidth * 0.06,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: screenWidth * 0.02),
              Text(
                'No suppliers are currently registered in your area',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      itemCount: _allSupplierLocations.length,
      itemBuilder: (context, index) {
        final farm = _allSupplierLocations[index];
        return _buildFarmCard(screenWidth, farm);
      },
    );
  }

  Widget _buildFarmCard(double screenWidth, SupplierLocation farm) {
    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      child: InkWell(
        onTap: () => _showSupplierDetails(farm),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Row(
            children: [
              // Farm Icon
              Container(
                width: screenWidth * 0.15,
                height: screenWidth * 0.15,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(screenWidth * 0.075),
                ),
                child: Icon(
                  Icons.agriculture,
                  color: Colors.green,
                  size: screenWidth * 0.08,
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              // Farm Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farm.locationName,
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      farm.address,
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: screenWidth * 0.04,
                          color: Colors.orange,
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Text(
                          farm.rating.toString(),
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.03),
                        Icon(
                          Icons.location_on,
                          size: screenWidth * 0.04,
                          color: Colors.green,
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Text(
                          _userLocation != null 
                            ? '${_mapService.calculateDistance(_userLocation!, LatLng(farm.latitude, farm.longitude)).toStringAsFixed(1)} km'
                            : 'Distance unavailable',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // View Button
              ElevatedButton(
                onPressed: () => _showSupplierDetails(farm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenWidth * 0.02),
                  child: Text(
                    'View',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshGPSLocation() async {
    await _useCurrentLocation();
  }

  Future<void> _useCurrentLocation() async {
    if (_isGettingLocation) return;
    setState(() { _isGettingLocation = true; });
    
    try {
      // Check location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showPermissionPermanentlyDeniedDialog();
        return;
      }
      
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        return;
      }
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }
      
      final data = await _mapService.getCurrentLocationWithAddress();
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to get current location'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final LatLng? loc = data['location'] as LatLng?;
      
      if (loc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid location data'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      // Check if location is within reasonable distance from Bogo City
      const LatLng bogoCityCenter = LatLng(11.0474, 124.0051);
      double distance = _mapService.calculateDistance(bogoCityCenter, loc);
      
      if (distance > 50.0) { // 50km radius - more lenient for customers
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your location seems far from Bogo City. Suppliers may be limited.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
      
      setState(() {
        _userLocation = loc;
      });
      
      // Move map to user location after the widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(loc, 15.0);
        }
      });
      
      await _loadSupplierLocations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _isGettingLocation = false; });
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text(
    'Location Services Disabled',
    style: TextStyle(fontSize: 15),
  ),
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
              style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
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
                'Alternative: You can use the default location for now.',
                style: GoogleFonts.quicksand(
                  color: Colors.blue[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeLocation(); // Use default location
            },
            child: const Text('Use Default Location'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _useCurrentLocation(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4CAF50),
            ),
            child: Text('Try Again', style: GoogleFonts.quicksand(color: Colors.white)),
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
                'You can still use the default location for now.',
                style: GoogleFonts.quicksand(
                  color: Colors.blue[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeLocation(); // Use default location
            },
            child: const Text('Use Default Location'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _useCurrentLocation(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4CAF50),
            ),
            child: Text('Try Again', style: GoogleFonts.quicksand(color: Colors.white)),
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
              style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
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
                'Alternative: You can use the default location for now.',
                style: GoogleFonts.quicksand(
                  color: Colors.blue[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeLocation(); // Use default location
            },
            child: const Text('Use Default Location'),
          ),
        ],
      ),
    );
  }
}
