import 'package:flutter/foundation.dart';

class ContentFilterService {
  static final ContentFilterService _instance = ContentFilterService._internal();
  factory ContentFilterService() => _instance;
  ContentFilterService._internal();

  // List of offensive/inappropriate words (can be expanded)
  static const List<String> _offensiveWords = [
    'fuck', 'shit', 'bitch', 'ass', 'dick', 'pussy', 'cock', 'cunt',
    'damn', 'hell', 'bastard', 'whore', 'slut', 'faggot', 'nigger',
    'spic', 'chink', 'kike', 'wop', 'gook', 'dago', 'kraut', 'polack',
    'redneck', 'hillbilly', 'white trash', 'ghetto', 'hood rat',
    'crackhead', 'junkie', 'addict', 'alcoholic', 'drunk', 'stoner',
    'pothead', 'druggie', 'crack whore', 'meth head', 'heroin addict',
    'cocaine', 'heroin', 'meth', 'weed', 'marijuana', 'drugs',
    'illegal', 'contraband', 'stolen', 'fake', 'counterfeit',
    'scam', 'fraud', 'rip off', 'overpriced', 'garbage', 'trash',
    'junk', 'crap', 'bullshit', 'nonsense', 'stupid', 'idiot',
    'moron', 'retard', 'dumb', 'ignorant', 'racist', 'sexist',
    'homophobic', 'transphobic', 'bigot', 'nazi', 'fascist',
    'terrorist', 'extremist', 'radical', 'anarchist', 'communist',
    'socialist', 'liberal', 'conservative', 'republican', 'democrat',
    'political', 'propaganda', 'fake news', 'conspiracy', 'hoax',
    'scam', 'fraud', 'rip off', 'overpriced', 'garbage', 'trash',
  ];

  // List of suspicious patterns that might indicate inappropriate content
  static const List<String> _suspiciousPatterns = [
    'free money', 'make money fast', 'get rich quick', 'earn cash',
    'work from home', 'easy money', 'quick cash', 'instant money',
    'no experience needed', 'no skills required', 'anyone can do it',
    'guaranteed income', 'unlimited earnings', 'millionaire secrets',
    'crypto investment', 'bitcoin trading', 'forex trading', 'stock tips',
    'pyramid scheme', 'mlm', 'multi level marketing', 'network marketing',
    'direct sales', 'commission only', 'no salary', 'commission based',
    'adult content', 'adult entertainment', 'porn', 'pornography',
    'sex toys', 'adult toys', 'lingerie', 'adult clothing',
    'weapons', 'guns', 'ammo', 'ammunition', 'knives', 'swords',
    'explosives', 'bombs', 'fireworks', 'firearms', 'rifles',
    'pistols', 'revolvers', 'shotguns', 'automatic weapons',
    'drug paraphernalia', 'bongs', 'pipes', 'rolling papers',
    'scales', 'baggies', 'syringes', 'needles', 'pills',
    'prescription drugs', 'pharmaceuticals', 'medication',
    'controlled substances', 'illegal substances', 'recreational drugs',
  ];

  // List of trusted suppliers (can be expanded)
  static const List<String> _trustedSuppliers = [
    'organic_farm_verified',
    'fresh_veggies_certified',
    'local_farm_trusted',
    'green_garden_verified',
    'farm_fresh_certified',
  ];

  /// Check if content contains offensive or inappropriate words
  bool containsOffensiveContent(String text) {
    if (text.isEmpty) return false;
    
    final lowerText = text.toLowerCase();
    
    // Check for offensive words
    for (final word in _offensiveWords) {
      if (lowerText.contains(word.toLowerCase())) {
        debugPrint('Content filter: Found offensive word: $word');
        return true;
      }
    }
    
    // Check for suspicious patterns
    for (final pattern in _suspiciousPatterns) {
      if (lowerText.contains(pattern.toLowerCase())) {
        debugPrint('Content filter: Found suspicious pattern: $pattern');
        return true;
      }
    }
    
    return false;
  }

  /// Check if supplier is trusted
  bool isTrustedSupplier(String supplierId) {
    return _trustedSuppliers.contains(supplierId);
  }

  /// Comprehensive content check for product listings
  ContentCheckResult checkProductContent({
    required String productName,
    required String description,
    required String supplierId,
    String? category,
    double? price,
  }) {
    final issues = <String>[];
    var severity = ContentSeverity.low;

    // Check product name
    if (containsOffensiveContent(productName)) {
      issues.add('Product name contains inappropriate content');
      severity = ContentSeverity.high;
    }

    // Check description
    if (containsOffensiveContent(description)) {
      issues.add('Product description contains inappropriate content');
      severity = ContentSeverity.high;
    }

    // Check for suspicious pricing
    if (price != null && (price <= 0 || price > 10000)) {
      issues.add('Suspicious pricing detected');
      severity = ContentSeverity.medium;
    }

    // Check for inappropriate categories
    if (category != null && containsOffensiveContent(category)) {
      issues.add('Product category contains inappropriate content');
      severity = ContentSeverity.high;
    }

    // Check if supplier is trusted
    final isTrusted = isTrustedSupplier(supplierId);

    return ContentCheckResult(
      isApproved: issues.isEmpty,
      issues: issues,
      severity: severity,
      isTrustedSupplier: isTrusted,
      requiresManualReview: issues.isNotEmpty || !isTrusted,
    );
  }

  /// Check content using external API (optional)
  Future<ContentCheckResult> checkContentWithAPI(String text) async {
    try {
      // This is a placeholder for external content filtering API
      // You can integrate with services like:
      // - Google Cloud Content Moderation
      // - Amazon Comprehend
      // - Microsoft Azure Content Moderator
      // - Perspective API
      
      // For now, we'll use our local filter
      final hasOffensiveContent = containsOffensiveContent(text);
      
      return ContentCheckResult(
        isApproved: !hasOffensiveContent,
        issues: hasOffensiveContent ? ['Content flagged by external API'] : [],
        severity: hasOffensiveContent ? ContentSeverity.high : ContentSeverity.low,
        isTrustedSupplier: false,
        requiresManualReview: hasOffensiveContent,
      );
    } catch (e) {
      debugPrint('Error checking content with API: $e');
      // Fallback to local check
      return ContentCheckResult(
        isApproved: !containsOffensiveContent(text),
        issues: containsOffensiveContent(text) ? ['Content flagged by local filter'] : [],
        severity: ContentSeverity.medium,
        isTrustedSupplier: false,
        requiresManualReview: containsOffensiveContent(text),
      );
    }
  }

  /// Get content filter statistics
  Map<String, dynamic> getFilterStats() {
    return {
      'offensiveWordsCount': _offensiveWords.length,
      'suspiciousPatternsCount': _suspiciousPatterns.length,
      'trustedSuppliersCount': _trustedSuppliers.length,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Add new offensive words to the filter
  void addOffensiveWord(String word) {
    if (!_offensiveWords.contains(word.toLowerCase())) {
      _offensiveWords.add(word.toLowerCase());
    }
  }

  /// Add new suspicious patterns to the filter
  void addSuspiciousPattern(String pattern) {
    if (!_suspiciousPatterns.contains(pattern.toLowerCase())) {
      _suspiciousPatterns.add(pattern.toLowerCase());
    }
  }

  /// Add trusted supplier
  void addTrustedSupplier(String supplierId) {
    if (!_trustedSuppliers.contains(supplierId)) {
      _trustedSuppliers.add(supplierId);
    }
  }
}

/// Result of content filtering check
class ContentCheckResult {
  final bool isApproved;
  final List<String> issues;
  final ContentSeverity severity;
  final bool isTrustedSupplier;
  final bool requiresManualReview;

  ContentCheckResult({
    required this.isApproved,
    required this.issues,
    required this.severity,
    required this.isTrustedSupplier,
    required this.requiresManualReview,
  });

  Map<String, dynamic> toJson() {
    return {
      'isApproved': isApproved,
      'issues': issues,
      'severity': severity.toString(),
      'isTrustedSupplier': isTrustedSupplier,
      'requiresManualReview': requiresManualReview,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  factory ContentCheckResult.fromJson(Map<String, dynamic> json) {
    return ContentCheckResult(
      isApproved: json['isApproved'] ?? false,
      issues: List<String>.from(json['issues'] ?? []),
      severity: ContentSeverity.values.firstWhere(
        (e) => e.toString() == json['severity'],
        orElse: () => ContentSeverity.low,
      ),
      isTrustedSupplier: json['isTrustedSupplier'] ?? false,
      requiresManualReview: json['requiresManualReview'] ?? false,
    );
  }
}

/// Severity levels for content issues
enum ContentSeverity {
  low,
  medium,
  high,
  critical,
} 