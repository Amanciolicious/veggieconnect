import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// A navigation compass widget that shows the direction of travel from current location to destination.
/// 
/// Features:
/// - Animated compass needle that points towards the destination
/// - Distance indicator showing remaining distance
/// - Tap gesture to show detailed navigation information
/// - Smooth rotation animations when direction changes
/// - Responsive to location updates
class NavigationCompass extends StatefulWidget {
  final latlong.LatLng? currentLocation;
  final latlong.LatLng? destination;
  final double size;
  final bool showDirection;

  const NavigationCompass({
    super.key,
    this.currentLocation,
    this.destination,
    this.size = 80.0,
    this.showDirection = true,
  });

  @override
  State<NavigationCompass> createState() => _NavigationCompassState();
}

class _NavigationCompassState extends State<NavigationCompass>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  double _currentBearing = 0.0;
  double _targetBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NavigationCompass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLocation != null && widget.destination != null) {
      // Only update if location or destination actually changed
      if (oldWidget.currentLocation != widget.currentLocation ||
          oldWidget.destination != widget.destination) {
        _updateBearing();
      }
    }
  }

  void _updateBearing() {
    if (widget.currentLocation == null || widget.destination == null) return;

    final bearing = _calculateBearing(
      widget.currentLocation!,
      widget.destination!,
    );

    if ((bearing - _currentBearing).abs() > 180) {
      // Handle crossing the 0/360 degree boundary
      if (bearing > _currentBearing) {
        _targetBearing = bearing - 360;
      } else {
        _targetBearing = bearing + 360;
      }
    } else {
      _targetBearing = bearing;
    }

    _rotationAnimation = Tween<double>(
      begin: _currentBearing,
      end: _targetBearing,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    _rotationController.reset();
    _rotationController.forward().then((_) {
      setState(() {
        _currentBearing = _targetBearing;
      });
    });
  }

  double _calculateBearing(latlong.LatLng from, latlong.LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final deltaLng = (to.longitude - from.longitude) * pi / 180;

    final y = sin(deltaLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLng);

    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null || widget.destination == null) {
      return _buildCompassPlaceholder();
    }

    final distance = _calculateDistance(widget.currentLocation!, widget.destination!);
    final distanceText = distance < 1000 
        ? '${distance.toStringAsFixed(0)}m'
        : '${(distance / 1000).toStringAsFixed(1)}km';

    return GestureDetector(
      onTap: () => _showCompassDetails(context),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Compass background
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFFF5F5F5),
                    Color(0xFFE0E0E0),
                  ],
                ),
              ),
            ),
            // Compass needle
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * pi / 180,
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: CompassNeedlePainter(),
                  ),
                );
              },
            ),
            // Center dot
            Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Distance indicator
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Text(
                distanceText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompassDetails(BuildContext context) {
    if (widget.currentLocation == null || widget.destination == null) return;

    final distance = _calculateDistance(widget.currentLocation!, widget.destination!);
    final bearing = _calculateBearing(widget.currentLocation!, widget.destination!);
    
    final directionText = _getDirectionText(bearing);
    final distanceText = distance < 1000 
        ? '${distance.toStringAsFixed(0)} meters'
        : '${(distance / 1000).toStringAsFixed(1)} kilometers';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.navigation, color: Colors.blue),
            SizedBox(width: 8),
            Text('Navigation Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Direction: $directionText'),
            const SizedBox(height: 8),
            Text('Distance: $distanceText'),
            const SizedBox(height: 8),
            Text('Bearing: ${bearing.toStringAsFixed(1)}°'),
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

  String _getDirectionText(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'North';
    if (bearing >= 22.5 && bearing < 67.5) return 'Northeast';
    if (bearing >= 67.5 && bearing < 112.5) return 'East';
    if (bearing >= 112.5 && bearing < 157.5) return 'Southeast';
    if (bearing >= 157.5 && bearing < 202.5) return 'South';
    if (bearing >= 202.5 && bearing < 247.5) return 'Southwest';
    if (bearing >= 247.5 && bearing < 292.5) return 'West';
    if (bearing >= 292.5 && bearing < 337.5) return 'Northwest';
    return 'Unknown';
  }

  Widget _buildCompassPlaceholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.withValues(alpha: 0.3),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
      ),
      child: const Center(
        child: Icon(
          Icons.navigation,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  double _calculateDistance(latlong.LatLng from, latlong.LatLng to) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final lat1Rad = from.latitude * pi / 180;
    final lat2Rad = to.latitude * pi / 180;
    final deltaLat = (to.latitude - from.latitude) * pi / 180;
    final deltaLng = (to.longitude - from.longitude) * pi / 180;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}

class CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Draw compass needle (pointing north)
    final needlePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final needlePath = Path();
    needlePath.moveTo(center.dx, center.dy - radius);
    needlePath.lineTo(center.dx - 4, center.dy);
    needlePath.lineTo(center.dx + 4, center.dy);
    needlePath.close();

    canvas.drawPath(needlePath, needlePaint);

    // Draw compass needle tail
    final tailPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final tailPath = Path();
    tailPath.moveTo(center.dx, center.dy + radius * 0.3);
    tailPath.lineTo(center.dx - 2, center.dy);
    tailPath.lineTo(center.dx + 2, center.dy);
    tailPath.close();

    canvas.drawPath(tailPath, tailPaint);

    // Draw direction indicators
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // North indicator
    textPainter.text = TextSpan(
      text: 'N',
      style: TextStyle(
        color: Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - radius - textPainter.height - 2,
      ),
    );

    // East indicator
    textPainter.text = TextSpan(
      text: 'E',
      style: TextStyle(
        color: Colors.black87,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx + radius - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // South indicator
    textPainter.text = TextSpan(
      text: 'S',
      style: TextStyle(
        color: Colors.black87,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + radius + 2,
      ),
    );

    // West indicator
    textPainter.text = TextSpan(
      text: 'W',
      style: TextStyle(
        color: Colors.black87,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - radius - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
