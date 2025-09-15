import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieLoadingWidget extends StatelessWidget {
  final String? assetPath;
  final String? networkUrl;
  final double? width;
  final double? height;
  final bool repeat;
  final bool reverse;
  final double? speed;
  final Color? backgroundColor;
  final BoxFit fit;
  final Alignment alignment;
  final bool showText;

  const LottieLoadingWidget({
    super.key,
    this.assetPath,
    this.networkUrl,
    this.width,
    this.height,
    this.repeat = true,
    this.reverse = false,
    this.speed,
    this.backgroundColor,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    required this.showText,
  }) : assert(assetPath != null || networkUrl != null, 
              'Either assetPath or networkUrl must be provided');

  @override
  Widget build(BuildContext context) {
    Widget lottieWidget;

    if (assetPath != null) {
      lottieWidget = Lottie.asset(
        assetPath!,
        width: width,
        height: height,
        repeat: repeat,
        reverse: reverse,
        animate: true,
        fit: fit,
        alignment: alignment,
        frameRate: speed != null ? FrameRate(speed!) : null,
      );
    } else {
      lottieWidget = Lottie.network(
        networkUrl!,
        width: width,
        height: height,
        repeat: repeat,
        reverse: reverse,
        animate: true,
        fit: fit,
        alignment: alignment,
        frameRate: speed != null ? FrameRate(speed!) : null,
      );
    }

    if (backgroundColor != null) {
      return Container(
        color: backgroundColor,
        child: lottieWidget,
      );
    }

    return lottieWidget;
  }
}

// Predefined loading animations for common use cases
class VeggieConnectLoadingAnimations {
  // Your existing grocery shopping animation
  static const String groceryShopping = 'assets/lottie-loading-json/Grocery shopping bag pickup and delivery.json';
  
  // You can add more animations here as you get them
  // static const String loadingDots = 'assets/lottie-loading-json/loading-dots.json';
  // static const String loadingSpinner = 'assets/lottie-loading-json/loading-spinner.json';
}

// Convenience widgets for common loading scenarios
class GroceryLoadingWidget extends StatelessWidget {
  final double? size;
  final Color? backgroundColor;
  final bool showText;
  final String? loadingText;

  const GroceryLoadingWidget({
    super.key,
    this.size = 200,
    this.backgroundColor,
    this.showText = false,
    this.loadingText = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LottieLoadingWidget(
          assetPath: VeggieConnectLoadingAnimations.groceryShopping,
          width: size,
          height: size,
          backgroundColor: backgroundColor,
          showText: showText,
        ),
        if (showText) ...[
          const SizedBox(height: 16),
          Text(
            loadingText!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}

// Full screen loading overlay
class FullScreenLoadingOverlay extends StatelessWidget {
  final String? assetPath;
  final String? networkUrl;
  final String? loadingText;
  final Color? backgroundColor;
  final double? animationSize;

  const FullScreenLoadingOverlay({
    super.key,
    this.assetPath,
    this.networkUrl,
    this.loadingText,
    this.backgroundColor = Colors.white,
    this.animationSize = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LottieLoadingWidget(
              assetPath: assetPath,
              networkUrl: networkUrl,
              width: animationSize,
              height: animationSize,
              showText: false,
            ),
            if (loadingText != null) ...[
              const SizedBox(height: 24),
              Text(
                loadingText!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
