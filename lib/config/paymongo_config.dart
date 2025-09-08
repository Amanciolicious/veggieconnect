class PaymongoConfig {
  // Vercel API endpoint for PayMongo checkout
  static const String checkoutFunctionUrl = 'https://paymongo-api-fawn.vercel.app/api/createCheckoutSession';

  // Redirect URLs for PayMongo Checkout success/cancel
  // For testing, any reachable URL is fine. Replace with your deep links or pages.
  static const String successUrl = 'https://example.com/pay-success';
  static const String cancelUrl = 'https://example.com/pay-cancel';
}


