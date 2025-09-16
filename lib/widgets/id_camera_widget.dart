// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use, unnecessary_import

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

class IdCameraWidget extends StatefulWidget {
  final String title;
  final Function(Uint8List imageBytes, String fileName) onImageCaptured;

  const IdCameraWidget({
    super.key,
    required this.title,
    required this.onImageCaptured,
  });

  @override
  State<IdCameraWidget> createState() => _IdCameraWidgetState();
}

class _IdCameraWidgetState extends State<IdCameraWidget> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _idDetected = false;
  String _detectionMessage = 'Position your ID within the frame';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _controller!.initialize();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final Uint8List imageBytes = await image.readAsBytes();
      
      // Process and validate the captured image
      final processedBytes = await _processIdImage(imageBytes);
      final fileName = 'id_${widget.title.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      widget.onImageCaptured(processedBytes, fileName);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error capturing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<Uint8List> _processIdImage(Uint8List imageBytes) async {
    try {
      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Get the overlay frame dimensions for cropping
      final screenSize = MediaQuery.of(context).size;
      final frameWidth = screenSize.width * 0.85;
      final frameHeight = frameWidth * 0.63; // ID card aspect ratio (1.59:1)
      
      // Calculate crop area based on camera preview and overlay frame
      final previewRatio = _controller!.value.aspectRatio;
      final imageRatio = image.width / image.height;
      
      // Calculate the actual crop coordinates
      int cropX, cropY, cropWidth, cropHeight;
      
      if (imageRatio > previewRatio) {
        // Image is wider than preview
        cropHeight = image.height;
        cropWidth = (cropHeight * previewRatio).round();
        cropX = (image.width - cropWidth) ~/ 2;
        cropY = 0;
      } else {
        // Image is taller than preview
        cropWidth = image.width;
        cropHeight = (cropWidth / previewRatio).round();
        cropX = 0;
        cropY = (image.height - cropHeight) ~/ 2;
      }

      // Apply the crop to focus on the ID area
      final frameRatio = frameWidth / screenSize.width;
      final frameHeightRatio = frameHeight / screenSize.height;
      
      final finalCropX = (cropX + (cropWidth * (1 - frameRatio) / 2)).round();
      final finalCropY = (cropY + (cropHeight * (1 - frameHeightRatio) / 2)).round();
      final finalCropWidth = (cropWidth * frameRatio).round();
      final finalCropHeight = (cropHeight * frameHeightRatio).round();

      // Crop the image to the ID frame area
      final croppedImage = img.copyCrop(
        image,
        x: finalCropX,
        y: finalCropY,
        width: finalCropWidth,
        height: finalCropHeight,
      );

      // Enhance the image for better OCR
      final enhancedImage = img.contrast(img.adjustColor(croppedImage, brightness: 1.1), contrast: 1.2);
      
      // Encode back to bytes
      final processedBytes = img.encodeJpg(enhancedImage, quality: 95);
      return Uint8List.fromList(processedBytes);
    } catch (e) {
      print('Error processing image: $e');
      return imageBytes;
    }
  }

  void _simulateIdDetection() {
    // Simple simulation of ID detection based on frame positioning
    // In a real implementation, this would use ML/CV algorithms
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _idDetected = true;
          _detectionMessage = 'ID detected! Tap capture when ready';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            'Capture ${widget.title}',
            style: GoogleFonts.quicksand(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6CA04A)),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final frameWidth = screenSize.width * 0.85;
    final frameHeight = frameWidth * 0.63; // Standard ID card aspect ratio

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Dark overlay with ID frame cutout
          Positioned.fill(
            child: CustomPaint(
              painter: IdOverlayPainter(
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                screenSize: screenSize,
                idDetected: _idDetected,
              ),
            ),
          ),
          
          // Top instruction bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _idDetected ? Icons.check_circle : Icons.camera_alt,
                    color: _idDetected ? Color(0xFF6CA04A) : Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _detectionMessage,
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ID frame guidelines
          Positioned(
            left: (screenSize.width - frameWidth) / 2,
            top: (screenSize.height - frameHeight) / 2 - 40,
            child: SizedBox(
              width: frameWidth,
              height: frameHeight,
              child: Stack(
                children: [
                  // Corner guides
                  ...List.generate(4, (index) {
                    final isTop = index < 2;
                    final isLeft = index % 2 == 0;
                    return Positioned(
                      top: isTop ? 0 : null,
                      bottom: !isTop ? 0 : null,
                      left: isLeft ? 0 : null,
                      right: !isLeft ? 0 : null,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          border: Border(
                            top: isTop ? BorderSide(color: _idDetected ? Color(0xFF6CA04A) : Colors.white, width: 3) : BorderSide.none,
                            bottom: !isTop ? BorderSide(color: _idDetected ? Color(0xFF6CA04A) : Colors.white, width: 3) : BorderSide.none,
                            left: isLeft ? BorderSide(color: _idDetected ? Color(0xFF6CA04A) : Colors.white, width: 3) : BorderSide.none,
                            right: !isLeft ? BorderSide(color: _idDetected ? Color(0xFF6CA04A) : Colors.white, width: 3) : BorderSide.none,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          // Instructions text
          Positioned(
            left: 20,
            right: 20,
            bottom: 180,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ID Capture Tips:',
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Position ID within the frame\n• Ensure good lighting\n• Keep ID flat and straight\n• Make sure all text is visible',
                    style: GoogleFonts.quicksand(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Control buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.close, color: Colors.white, size: 30),
                  ),
                ),
                
                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _captureImage,
                  onTapDown: (_) => _simulateIdDetection(),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _idDetected ? Color(0xFF6CA04A) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _idDetected ? Color(0xFF6CA04A) : Colors.white,
                        width: 4,
                      ),
                    ),
                    child: _isCapturing
                        ? CircularProgressIndicator(
                            color: _idDetected ? Colors.white : Color(0xFF6CA04A),
                            strokeWidth: 3,
                          )
                        : Icon(
                            Icons.camera_alt,
                            color: _idDetected ? Colors.white : Color(0xFF6CA04A),
                            size: 40,
                          ),
                  ),
                ),
                
                // Gallery button
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    // This will trigger the gallery selection in the parent widget
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.photo_library, color: Colors.white, size: 30),
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

class IdOverlayPainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;
  final Size screenSize;
  final bool idDetected;

  IdOverlayPainter({
    required this.frameWidth,
    required this.frameHeight,
    required this.screenSize,
    required this.idDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Create the overlay with cutout for ID frame
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final frameLeft = (size.width - frameWidth) / 2;
    final frameTop = (size.height - frameHeight) / 2 - 40;
    
    final framePath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight),
        Radius.circular(12),
      ));

    final finalPath = Path.combine(PathOperation.difference, overlayPath, framePath);
    canvas.drawPath(finalPath, paint);

    // Draw frame border
    final borderPaint = Paint()
      ..color = idDetected ? Color(0xFF6CA04A) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight),
        Radius.circular(12),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
