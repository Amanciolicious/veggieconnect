import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Supported payment methods
  static const Map<String, String> _paymentMethods = {
    'cash_on_pickup': 'Cash on Pickup',
    'gcash': 'GCash',
    'paymaya': 'PayMaya',
  };

  Map<String, String> getPaymentMethods() => Map.from(_paymentMethods);

  bool requiresExternalBrowser(String method) => method == 'gcash' || method == 'paymaya';

  String getPaymentMethodDisplayName(String method) => _paymentMethods[method] ?? method;

  Future<bool> _openUrlExternally(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('Failed to open URL: $e');
      return false;
    }
  }

  // Sandbox checkout URLs (replace with real API checkout links later)
  static const String gcashSandboxUrl = 'https://sandbox.gcash.com/checkout/demo';
  static const String paymayaSandboxUrl = 'https://sandbox.paymaya.com/checkout/demo';

  Future<bool> launchGcashCheckout() => _openUrlExternally(gcashSandboxUrl);

  Future<bool> launchPayMayaCheckout() => _openUrlExternally(paymayaSandboxUrl);
}


