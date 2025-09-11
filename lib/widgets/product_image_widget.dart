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
      return Container(
        width: width,
        height: height,
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: height,
          minWidth: width,
          minHeight: height,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imagePath,
            width: width,
            height: height,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildPlaceholder();
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget();
            },
          ),
        ),
      );
    }

    // Default placeholder for invalid paths
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) {
      return Container(
        width: width,
        height: height,
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: height,
          minWidth: width,
          minHeight: height,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: placeholder!,
        ),
      );
    }
    
    return Container(
      width: width,
      height: height,
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: height,
        minWidth: width,
        minHeight: height,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.camera_alt,
        size: 40,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (errorWidget != null) {
      return Container(
        width: width,
        height: height,
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: height,
          minWidth: width,
          minHeight: height,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: errorWidget!,
        ),
      );
    }
    
    return Container(
      width: width,
      height: height,
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: height,
        minWidth: width,
        minHeight: height,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.broken_image,
        size: 40,
        color: Colors.grey,
      ),
    );
  }
}