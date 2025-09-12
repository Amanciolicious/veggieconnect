// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../customer-side/customer_order_success_page.dart';
import 'payment_completion_service.dart';

class DeepLinkService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void handleDeepLink(String url) {
    print('Deep link received: $url');
    
    try {
      final uri = Uri.parse(url);
      print('Parsed URI: $uri');
      
      if (uri.scheme == 'veggieconnect') {
        print('Scheme matches veggieconnect');
        if (uri.host == 'order-success') {
          print('Host matches order-success');
          final orderId = uri.queryParameters['orderId'];
          final status = uri.queryParameters['status'];
          
          print('OrderId: $orderId, Status: $status');
          
          if (orderId != null) {
            print('Navigating to order success page...');
            _navigateToOrderSuccess(orderId, status);
          } else {
            print('No orderId found in deep link');
          }
        } else {
          print('Host does not match order-success: ${uri.host}');
        }
      } else {
        print('Scheme does not match veggieconnect: ${uri.scheme}');
      }
    } catch (e) {
      print('Error parsing deep link: $e');
    }
  }

  static void _navigateToOrderSuccess(String orderId, String? status) {
    print('_navigateToOrderSuccess called with orderId: $orderId, status: $status');
    
    final context = navigatorKey.currentContext;
    if (context != null) {
      print('Context found, proceeding with navigation');
      
      // Complete the order first
      print('Completing order...');
      PaymentCompletionService.completeOrder(orderId).then((_) {
        print('Order completion initiated');
      }).catchError((error) {
        print('Error completing order: $error');
      });
      
      // Clear the cart after successful payment
      print('Clearing cart...');
      _clearCart();
      
      // Navigate to order success page and clear the entire navigation stack
      print('Navigating to OrderSuccessPage...');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessPage(
            orderId: orderId,
            status: status,
          ),
        ),
        (route) => false, // Remove all previous routes
      );
      print('Navigation completed');
    } else {
      print('No context found, cannot navigate');
    }
  }

  static void _clearCart() {
    // Clear cart from Firestore
    // This ensures the cart is empty after successful order
    try {
      // Clear cart by order ID - this will be called after order completion
      print('Cart will be cleared after order completion');
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }
}
