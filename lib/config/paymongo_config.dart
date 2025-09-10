class PaymongoConfig {
  // Vercel API endpoint for PayMongo checkout
  static const String checkoutFunctionUrl = 'https://paymongo-api-fawn.vercel.app/api/createCheckoutSession';

  // GitHub Pages redirect URLs for PayMongo Checkout success/cancel
  static const String successUrl = 'https://amanciolicious.github.io/veggieconnect.github.io/order-success.html';
  static const String cancelUrl = 'https://amanciolicious.github.io/veggieconnect.github.io/payment-cancel.html';
}


