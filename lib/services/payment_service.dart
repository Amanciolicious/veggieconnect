
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Supported payment methods
  static const Map<String, String> _paymentMethods = {
    'cash_on_pickup': 'Cash on Pickup',
    'gcash': 'GCash',
    'grab_pay': 'GrabPay',
    'paymaya': 'Maya',
    'card': 'Credit/Debit Card',
  };

  Map<String, String> getPaymentMethods() => Map.from(_paymentMethods);

  bool requiresExternalBrowser(String method) =>
      method == 'gcash' || method == 'grab_pay' || method == 'paymaya' || method == 'card';

  String getPaymentMethodDisplayName(String method) => _paymentMethods[method] ?? method;
}
