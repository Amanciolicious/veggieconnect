import 'package:flutter/material.dart';
import '../widgets/lottie_loading_widget.dart';

class LottieDemoScreen extends StatefulWidget {
  const LottieDemoScreen({super.key});

  @override
  State<LottieDemoScreen> createState() => _LottieDemoScreenState();
}

class _LottieDemoScreenState extends State<LottieDemoScreen> {
  bool _showFullScreenLoading = false;
  bool _showLoadingOverlay = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lottie Loading Animations Demo'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _showFullScreenLoading
          ? const FullScreenLoadingOverlay(
              assetPath: VeggieConnectLoadingAnimations.groceryShopping,
              loadingText: 'Loading your groceries...',
              backgroundColor: Colors.white,
            )
          : _showLoadingOverlay
              ? Stack(
                  children: [
                    _buildMainContent(),
                    // Loading overlay
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
                                  showText: true,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Basic Lottie Animation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Basic Lottie Animation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const LottieLoadingWidget(
                    assetPath: VeggieConnectLoadingAnimations.groceryShopping,
                    width: 200,
                    height: 200,
                    showText: true,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your grocery shopping animation',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Grocery Loading Widget
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Grocery Loading Widget',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const GroceryLoadingWidget(
                    size: 150,
                    showText: true,
                    loadingText: 'Loading your groceries...',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Different Sizes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Different Sizes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const LottieLoadingWidget(
                            assetPath: VeggieConnectLoadingAnimations.groceryShopping,
                            width: 80,
                            height: 80,
                            showText: true,
                          ),
                          const Text('Small'),
                        ],
                      ),
                      Column(
                        children: [
                          const LottieLoadingWidget(
                            assetPath: VeggieConnectLoadingAnimations.groceryShopping,
                            width: 120,
                            height: 120,
                            showText: true,
                          ),
                          const Text('Medium'),
                        ],
                      ),
                      Column(
                        children: [
                          const LottieLoadingWidget(
                            assetPath: VeggieConnectLoadingAnimations.groceryShopping,
                            width: 160,
                            height: 160,
                            showText: true,
                          ),
                          const Text('Large'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Custom Background
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'With Background Color',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const LottieLoadingWidget(
                    assetPath: VeggieConnectLoadingAnimations.groceryShopping,
                    width: 200,
                    height: 200,
                    backgroundColor: Colors.green,
                    showText: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Demo Buttons
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Full Screen Loading Demo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showFullScreenLoading = true;
                      });
                      // Simulate loading for 3 seconds
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted) {
                          setState(() {
                            _showFullScreenLoading = false;
                          });
                        }
                      });
                    },
                    child: const Text('Show Full Screen Loading'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showLoadingOverlay = true;
                      });
                      // Simulate loading for 2 seconds
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() {
                            _showLoadingOverlay = false;
                          });
                        }
                      });
                    },
                    child: const Text('Show Loading Overlay'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Usage Instructions
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Usage Instructions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Basic usage: LottieLoadingWidget(assetPath: "path/to/animation.json")\n'
                    '2. With size: LottieLoadingWidget(width: 200, height: 200)\n'
                    '3. With background: LottieLoadingWidget(backgroundColor: Colors.green)\n'
                    '4. Grocery specific: GroceryLoadingWidget(showText: true)\n'
                    '5. Full screen: FullScreenLoadingOverlay(loadingText: "Loading...")',
                    style: TextStyle(color: Colors.blue[800]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
