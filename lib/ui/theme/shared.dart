import 'package:flutter/material.dart';

class Shared {
  Shared._(); // prevent instantiation

  // Screen-relative padding
  static const double horizontalPaddingPercent = 0.03;
  static const double verticalPaddingPercent = 0.02;

  // Fixed sizes
  static const double cardBorderRadius = 12.0;
  static const double iconSizeMedium = 24.0;
  static const double buttonHeight = 48.0;

  // Colors (dark gold Egyptian theme)
  static const Color background = Color(0xFF0D0D0D);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFF9C7A28);
}

extension ScreenPadding on BuildContext {
  double get hPad =>
      MediaQuery.sizeOf(this).width * Shared.horizontalPaddingPercent;
  double get vPad =>
      MediaQuery.sizeOf(this).height * Shared.verticalPaddingPercent;
}
