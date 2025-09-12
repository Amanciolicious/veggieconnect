import 'package:shared_preferences/shared_preferences.dart';

class PreboardingService {
  static const String _hasSeenPreboardingKey = 'has_seen_preboarding';

  /// Check if user has seen the pre-boarding screen
  static Future<bool> hasSeenPreboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenPreboardingKey) ?? false;
  }

  /// Mark that user has seen the pre-boarding screen
  static Future<void> markPreboardingAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenPreboardingKey, true);
  }

  /// Reset pre-boarding status (for testing or app reset)
  static Future<void> resetPreboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasSeenPreboardingKey);
  }

  /// Force show pre-boarding (for testing)
  static Future<void> forceShowPreboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenPreboardingKey, false);
  }
}
