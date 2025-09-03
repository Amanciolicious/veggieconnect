// Paymongo API Configuration for Testing
// 
// SETUP INSTRUCTIONS:
// 1. Sign up at https://paymongo.com/
// 2. Go to Dashboard > API Keys
// 3. Copy your Test Secret Key
// 4. Replace the testSecretKey below with your actual test secret key
// 5. This configuration is for TESTING ONLY

class PaymongoConfig {
  // ===== TESTING KEYS (Replace with your actual test secret key) =====
  // Replace this with your actual Paymongo test secret key
  static const String testSecretKey = 'sk_test_SKv7mHXQhMZzUVXAyqmFZuKC';
  
  // ===== API CONFIGURATION =====
  static const String baseUrl = 'https://api.paymongo.com/v1';
  
  // ===== PAYMENT METHODS =====
  static const Map<String, String> supportedPaymentMethods = {
    'gcash': 'gcash',
    'paymaya': 'paymaya',
  };
  
  // ===== CURRENCY SETTINGS =====
  static const String defaultCurrency = 'PHP';
  
  // ===== WEBHOOK SETTINGS =====
  static const String webhookUrl = 'https://amancioliciaus.com/webhook/paymongo';
  
  // ===== HELPER METHODS =====
  static String get secretKey => testSecretKey;
  static String get publicKey => 'pk_test_placeholder'; // Not used for server-side operations
  
  static bool get isConfigured {
    // Check if the test secret key is properly set (not the placeholder)
    return secretKey.isNotEmpty && 
           secretKey != 'sk_test_SKv7mHXQhMZzUVXAyqmFZuKC' &&
           secretKey.startsWith('sk_test_');
  }
  
  static String get environment => 'test';
  
  // ===== VALIDATION METHODS =====
  static bool isValidSecretKey(String key) {
    return key.startsWith('sk_test_') && key.length > 20;
  }
  
  static bool isValidPublicKey(String key) {
    return key.startsWith('pk_test_') && key.length > 20;
  }
  
  // ===== ERROR MESSAGES =====
  static String get configurationError => 
    'Paymongo test secret key not configured. Please update the testSecretKey in paymongo_config.dart with your actual test secret key from Paymongo dashboard.';
  
  static String get testModeMessage => 
    'Running in TEST mode. Use test cards for payment testing.';
}

// ===== PAYMONGO SETUP GUIDE =====
/*
STEP 1: SIGN UP FOR PAYMONGO
- Go to https://paymongo.com/
- Click "Get Started" or "Sign Up"
- Complete the registration process
- Verify your email address

STEP 2: GET YOUR TEST API KEY
- Log in to your Paymongo Dashboard
- Go to "API Keys" in the sidebar
- Copy your Test Secret Key (starts with sk_test_)
- Keep your Secret Key secure and never share it

STEP 3: CONFIGURE THE APP
- Open vegieconnect/lib/services/paymongo_config.dart
- Replace 'sk_test_YOUR_TEST_SECRET_KEY_HERE' with your actual test secret key
- The key should start with 'sk_test_'

STEP 4: TEST THE INTEGRATION
- Use test cards for testing (see Paymongo documentation)
- Test with small amounts first
- Verify webhook endpoints if using webhooks

TEST CARDS FOR GCASH/PAYMaya:
- GCash: Use any valid Philippine mobile number
- PayMaya: Use any valid Philippine mobile number
- For testing, use test mode with small amounts

IMPORTANT SECURITY NOTES:
- Never commit API keys to version control
- Use environment variables in production
- Keep your secret key secure
- Monitor your Paymongo dashboard regularly
*/ 