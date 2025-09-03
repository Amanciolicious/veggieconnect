import 'package:flutter/material.dart';

class ProductImageWidget extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ProductImageWidget({
    super.key,
    required this.imagePath,
    this.width = 120,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath.isEmpty) {
      return _buildPlaceholder();
    }

    // Since we now use Cloudinary URLs, all images should be network URLs
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    }

    // Default placeholder for invalid paths
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) {
      return SizedBox(
        width: width,
        height: height,
        child: placeholder!,
      );
    }
    
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(
        Icons.camera_alt,
        size: 40,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (errorWidget != null) {
      return SizedBox(
        width: width,
        height: height,
        child: errorWidget!,
      );
    }
    
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(
        Icons.broken_image,
        size: 40,
        color: Colors.grey,
      ),
    );
  }
}