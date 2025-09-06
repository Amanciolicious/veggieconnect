import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  // Headers and Titles
  static TextStyle get headerLarge => GoogleFonts.quicksand(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  static TextStyle get headerMedium => GoogleFonts.quicksand(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static TextStyle get headerSmall => GoogleFonts.quicksand(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  // Body Text
  static TextStyle get bodyLarge => GoogleFonts.quicksand(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  static TextStyle get bodyMedium => GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
  );

  static TextStyle get bodySmall => GoogleFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
  );

  // Labels and Captions
  static TextStyle get labelLarge => GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static TextStyle get labelMedium => GoogleFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  static TextStyle get labelSmall => GoogleFonts.quicksand(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.black54,
  );

  // Specialized Styles
  static TextStyle get buttonText => GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle get buttonTextSecondary => GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.green,
  );

  static TextStyle get hintText => GoogleFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.grey,
  );

  static TextStyle get errorText => GoogleFonts.quicksand(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.red,
  );

  static TextStyle get successText => GoogleFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.green,
  );

  // Price and Money
  static TextStyle get price => GoogleFonts.quicksand(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.green,
  );

  static TextStyle get priceSmall => GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.green,
  );

  // App Bar
  static TextStyle get appBarTitle => GoogleFonts.quicksand(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  // Card Titles
  static TextStyle get cardTitle => GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  // Form Labels
  static TextStyle get formLabel => GoogleFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF757575),
  );

  // Input Fields
  static TextStyle get inputText => GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
  );

  // Responsive text styles
  static TextStyle responsiveHeader(double screenWidth) => GoogleFonts.quicksand(
    fontSize: screenWidth * 0.045,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  static TextStyle responsiveBody(double screenWidth) => GoogleFonts.quicksand(
    fontSize: screenWidth * 0.04,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
  );

  static TextStyle responsiveLabel(double screenWidth) => GoogleFonts.quicksand(
    fontSize: screenWidth * 0.04,
    fontWeight: FontWeight.w600,
    color: Color(0xFF757575),
  );
}
