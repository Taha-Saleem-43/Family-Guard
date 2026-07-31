import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Palette
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFFDBEAFE);

  // Status & Accents
  static const Color teal = Color(0xFF0D9488);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626); // SOS Red

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFEFF6FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  // Typography
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  // Member Pin Colors
  static const Color pinPurple = Color(0xFF7C3AED);
  static const Color pinBlue = Color(0xFF2563EB);
  static const Color pinAmber = Color(0xFFD97706);
  static const Color pinTeal = Color(0xFF0D9488);

  static const List<Color> pinColors = [
    pinPurple,
    pinBlue,
    pinAmber,
    pinTeal,
  ];
}
