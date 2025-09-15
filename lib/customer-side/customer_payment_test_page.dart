import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payment_completion_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/lottie_loading_widget.dart';
import '../services/auth_state_service.dart';

class PaymentTestPage extends StatefulWidget {
  const PaymentTestPage({super.key});

  @override
  State<PaymentTestPage> createState() => _PaymentTestPageState();
}

class _PaymentTestPageState extends State<PaymentTestPage> {
  String _orderId = '';
  String _status = '';
  bool _isLoading = false;
  final AuthStateService _authService = AuthStateService();

  AuthUser? get user => _authService.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Test'),
        backgroundColor: const Color(0xFF6CA04A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Order ID',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _orderId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testOrderCompletion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6CA04A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: GroceryLoadingWidget(
                        size: 24,
                        showText: false,
                      ),
                    )
                  : const Text('Test Automatic Order Completion'),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: GoogleFonts.quicksand(),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkOrderStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Check Order Status'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkTempOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Check Temp Order'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _clearCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Clear Cart'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _debugCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Debug Cart'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testPaymentMethodDisplay,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Payment Method Display'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testOrderCompletion() async {
    if (_orderId.isEmpty) {
      setState(() {
        _status = 'Please enter an order ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Testing automatic order completion...';
    });

    try {
      await PaymentCompletionService.completeOrder(_orderId);
      setState(() {
        _status = 'Automatic order completion test completed for: $_orderId\n\nThis simulates the automatic completion that happens after payment success.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkOrderStatus() async {
    if (_orderId.isEmpty) {
      setState(() {
        _status = 'Please enter an order ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Checking order status...';
    });

    try {
      final orderQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: _orderId)
          .get();

      if (orderQuery.docs.isNotEmpty) {
        final orderData = orderQuery.docs.first.data();
        setState(() {
          _status = 'Order found: ${orderData['status']} - ${orderData['paymentStatus']}';
        });
      } else {
        setState(() {
          _status = 'No orders found for order ID: $_orderId';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error checking order: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkTempOrder() async {
    if (_orderId.isEmpty) {
      setState(() {
        _status = 'Please enter an order ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Checking temp order...';
    });

    try {
      final tempOrderDoc = await FirebaseFirestore.instance
          .collection('temp_orders')
          .doc(_orderId)
          .get();

      if (tempOrderDoc.exists) {
        final tempOrderData = tempOrderDoc.data()!;
        setState(() {
          _status = 'Temp order found: ${tempOrderData['status']} - ${tempOrderData['amount']}';
        });
      } else {
        setState(() {
          _status = 'No temp order found for order ID: $_orderId';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error checking temp order: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCart() async {
    setState(() {
      _isLoading = true;
      _status = 'Clearing cart...';
    });

    try {
      if (user == null) {
        setState(() {
          _status = 'No user logged in';
        });
        return;
      }

      // Get all cart items for the user
      final cartQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .get();

      if (cartQuery.docs.isNotEmpty) {
        // Clear all cart items
        final cartBatch = FirebaseFirestore.instance.batch();
        
        for (final cartDoc in cartQuery.docs) {
          cartBatch.delete(cartDoc.reference);
        }
        
        await cartBatch.commit();
        setState(() {
          _status = 'Cart cleared successfully (${cartQuery.docs.length} items removed)';
        });
      } else {
        setState(() {
          _status = 'Cart is already empty';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error clearing cart: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _debugCart() async {
    setState(() {
      _isLoading = true;
      _status = 'Debugging cart...';
    });

    try {
      if (user == null) {
        setState(() {
          _status = 'No user logged in';
        });
        return;
      }

      // Get all cart items for the user
      final cartQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .get();

      String debugInfo = 'Cart Debug Info:\n';
      debugInfo += 'User ID: ${user!.uid}\n';
      debugInfo += 'Cart items count: ${cartQuery.docs.length}\n\n';
      
      for (final cartDoc in cartQuery.docs) {
        final cartData = cartDoc.data();
        debugInfo += 'Item ${cartDoc.id}:\n';
        debugInfo += '  Name: ${cartData['name']}\n';
        debugInfo += '  Quantity: ${cartData['quantity']}\n';
        debugInfo += '  Price: ${cartData['price']}\n';
        debugInfo += '  Product ID: ${cartData['productId']}\n\n';
      }

      setState(() {
        _status = debugInfo;
      });
    } catch (e) {
      setState(() {
        _status = 'Error debugging cart: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPaymentMethodDisplay() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing payment method display...';
    });

    try {
      String testResults = 'Payment Method Display Test:\n\n';
      
      final testMethods = ['gcash', 'grab_pay', 'paymaya', 'card', 'online_payment'];
      
      for (final method in testMethods) {
        final displayName = _getPaymentMethodDisplayName(method);
        testResults += '$method → $displayName\n';
      }
      
      setState(() {
        _status = testResults;
      });
    } catch (e) {
      setState(() {
        _status = 'Error testing payment method display: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getPaymentMethodDisplayName(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'gcash':
        return 'GCash';
      case 'grab_pay':
        return 'GrabPay';
      case 'paymaya':
        return 'PayMaya';
      case 'card':
        return 'Credit/Debit Card';
      case 'online_payment':
        return 'Online Payment';
      default:
        return 'Online Payment';
    }
  }
}
