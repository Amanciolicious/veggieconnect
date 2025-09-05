
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Supported payment methods
  static const Map<String, String> _paymentMethods = {
    'cash_on_pickup': 'Cash on Pickup',
    'paypal_sandbox': 'PayPal Sandbox',
  };

  Map<String, String> getPaymentMethods() => Map.from(_paymentMethods);

  bool requiresExternalBrowser(String method) => method == 'paypal_sandbox';

  String getPaymentMethodDisplayName(String method) => _paymentMethods[method] ?? method;
}


