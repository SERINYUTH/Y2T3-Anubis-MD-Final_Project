import 'package:flutter/material.dart';

// Every color and shared size used across the app lives here
class Shared {
  Shared._(); // prevent instantiation

  // Screen relative padding
  static const double horizontalPaddingPercent = 0.03;
  static const double verticalPaddingPercent = 0.02;

  // Fixed sizes
  static const double cardBorderRadius = 12.0;
  static const double iconSizeMedium = 24.0;
  static const double buttonHeight = 48.0;

  // Colors, dark gold theme
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color border = Color(0xFF2C2C2C);

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFF9C7A28);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9E9E9E);

  static const Color error = Color(0xFFE05252);
  static const Color success = Color(0xFF4CAF50);
}

extension ScreenPadding on BuildContext {
  double get hPad =>
      MediaQuery.sizeOf(this).width * Shared.horizontalPaddingPercent;
  double get vPad =>
      MediaQuery.sizeOf(this).height * Shared.verticalPaddingPercent;
}
