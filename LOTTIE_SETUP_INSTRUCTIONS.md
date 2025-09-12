# Lottie Loading Animation Setup Instructions

## Overview
Your VeggieConnect Flutter app now has a complete Lottie loading animation system integrated. This guide will help you understand how to use and customize the animations.

## What's Already Set Up

### ✅ Dependencies
- `lottie: ^3.1.2` is already added to your `pubspec.yaml`
- Assets are properly configured in `pubspec.yaml`

### ✅ Assets
- Your grocery shopping animation is located at: `assets/lottie-loading-json/Grocery shopping bag pickup and delivery.json`
- Assets are properly declared in `pubspec.yaml`

### ✅ Widgets Created
1. **LottieLoadingWidget** - Main reusable widget
2. **GroceryLoadingWidget** - Pre-configured for your grocery theme
3. **FullScreenLoadingOverlay** - Full screen loading with overlay
4. **VeggieConnectLoadingAnimations** - Constants for your animations

## How to Use

### 1. Basic Usage
```dart
import '../widgets/lottie_loading_widget.dart';

// Simple loading animation
LottieLoadingWidget(
  assetPath: VeggieConnectLoadingAnimations.groceryShopping,
  width: 200,
  height: 200,
)
```

### 2. With Custom Properties
```dart
LottieLoadingWidget(
  assetPath: VeggieConnectLoadingAnimations.groceryShopping,
  width: 150,
  height: 150,
  backgroundColor: Colors.green,
  speed: 1.5, // Animation speed multiplier
  repeat: true,
  reverse: false,
)
```

### 3. Grocery-Specific Widget
```dart
GroceryLoadingWidget(
  size: 200,
  showText: true,
  loadingText: 'Loading your groceries...',
)
```

### 4. Full Screen Loading
```dart
FullScreenLoadingOverlay(
  assetPath: VeggieConnectLoadingAnimations.groceryShopping,
  loadingText: 'Processing your order...',
  backgroundColor: Colors.white,
)
```

### 5. Loading Overlay (Modal)
```dart
// In your widget's build method
Stack(
  children: [
    // Your main content
    YourMainContent(),
    
    // Loading overlay
    if (isLoading)
      Container(
        color: Colors.black54,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LottieLoadingWidget(
                    assetPath: VeggieConnectLoadingAnimations.groceryShopping,
                    width: 120,
                    height: 120,
                  ),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              ),
            ),
          ),
        ),
      ),
  ],
)
```

## Demo Screen
A demo screen has been created at `/lottie-demo` route that shows all the different ways to use the Lottie animations. You can navigate to it to see examples in action.

## Adding New Animations

### 1. Add Animation Files
1. Download Lottie JSON files from [LottieFiles](https://lottiefiles.com/)
2. Place them in `assets/lottie-loading-json/` folder
3. Update `pubspec.yaml` if you add new subfolders

### 2. Update Constants
Add new animation paths to `VeggieConnectLoadingAnimations` class:

```dart
class VeggieConnectLoadingAnimations {
  static const String groceryShopping = 'assets/lottie-loading-json/Grocery shopping bag pickup and delivery.json';
  static const String loadingDots = 'assets/lottie-loading-json/loading-dots.json';
  static const String loadingSpinner = 'assets/lottie-loading-json/loading-spinner.json';
  // Add more as needed
}
```

### 3. Create Custom Widgets
For frequently used animations, create custom widgets:

```dart
class CustomLoadingWidget extends StatelessWidget {
  final double? size;
  final String? loadingText;

  const CustomLoadingWidget({
    super.key,
    this.size = 200,
    this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LottieLoadingWidget(
          assetPath: VeggieConnectLoadingAnimations.loadingDots,
          width: size,
          height: size,
        ),
        if (loadingText != null) ...[
          const SizedBox(height: 16),
          Text(loadingText!),
        ],
      ],
    );
  }
}
```

## Common Use Cases

### 1. App Initialization Loading
Your existing `AppLoader` is already using Lottie! It's perfect for app startup.

### 2. API Calls
```dart
Future<void> _loadData() async {
  setState(() => isLoading = true);
  
  try {
    final data = await apiService.fetchData();
    // Handle data
  } finally {
    setState(() => isLoading = false);
  }
}
```

### 3. Form Submission
```dart
Future<void> _submitForm() async {
  setState(() => isSubmitting = true);
  
  try {
    await formService.submit(formData);
    // Handle success
  } finally {
    setState(() => isSubmitting = false);
  }
}
```

### 4. Image/File Upload
```dart
Future<void> _uploadImage() async {
  setState(() => isUploading = true);
  
  try {
    await uploadService.uploadFile(file);
    // Handle success
  } finally {
    setState(() => isUploading = false);
  }
}
```

## Performance Tips

1. **Preload Animations**: For frequently used animations, consider preloading them
2. **Optimize File Size**: Use compressed Lottie files when possible
3. **Dispose Properly**: The Lottie widget handles disposal automatically
4. **Use Appropriate Sizes**: Don't use unnecessarily large animations for small loading indicators

## Troubleshooting

### Animation Not Showing
1. Check if the asset path is correct
2. Verify the file exists in the assets folder
3. Ensure `pubspec.yaml` includes the assets folder
4. Run `flutter clean` and `flutter pub get`

### Animation Too Large/Small
- Adjust `width` and `height` parameters
- Use `BoxFit.contain` for proper scaling

### Animation Not Looping
- Set `repeat: true` in the widget parameters

### Performance Issues
- Reduce animation complexity
- Use smaller file sizes
- Consider using `FrameRate` parameter to control playback speed

## Best Practices

1. **Consistent Sizing**: Use consistent sizes across your app
2. **Meaningful Animations**: Choose animations that match your app's context
3. **Loading States**: Always provide visual feedback for loading states
4. **Accessibility**: Consider users with motion sensitivity - provide options to reduce motion
5. **Brand Consistency**: Use animations that match your app's theme and branding

## Next Steps

1. **Test the Demo**: Navigate to `/lottie-demo` to see all animations in action
2. **Integrate**: Start using the widgets in your existing screens
3. **Customize**: Add more animations as needed for different use cases
4. **Optimize**: Monitor performance and optimize as needed

Your Lottie loading animation system is now ready to use! The existing `AppLoader` is already using your grocery shopping animation, and you have a complete set of reusable widgets for all your loading needs.
