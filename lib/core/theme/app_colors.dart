import 'package:flutter/material.dart';

class AppColors {
  // Brand colors
  static const Color primary = Color(0xFF3B82F6);      // Blue 500
  static const Color primaryDark = Color(0xFF2563EB);  // Blue 600
  static const Color primaryLight = Color(0xFFEFF6FF); // Blue 50

  static const Color teal = Color(0xFF0D9488);         // Teal 600
  static const Color tealLight = Color(0xFFF0FDF4);    // Teal 50

  static const Color sosRed = Color(0xFFEF4444);       // Red 500
  static const Color sosRedLight = Color(0xFFFEF2F2);  // Red 50

  // Neutral colors
  static const Color bg = Color(0xFFF8FAFC);           // Slate 50
  static const Color background = Color(0xFFF8FAFC);   // Alias for bg
  static const Color surface = Color(0xFFFFFFFF);      // White
  static const Color border = Color(0xFFE2E8F0);       // Slate 200
  static const Color borderDark = Color(0xFFCBD5E1);   // Slate 300
  static const Color danger = Color(0xFFEF4444);       // Alias for sosRed

  // Typography colors
  static const Color textPrimary = Color(0xFF0F172A);  // Slate 900
  static const Color textSecondary = Color(0xFF475569);// Slate 600
  static const Color textMuted = Color(0xFF94A3B8);    // Slate 400

  // Role pin colors
  static const Color pinParent = Color(0xFF3B82F6);    // Blue pin
  static const Color pinBlue = Color(0xFF3B82F6);      // Alias for pinParent
  static const Color pinChild = Color(0xFF10B981);     // Emerald pin
  static const Color pinWarning = Color(0xFFF59E0B);   // Amber pin
}
