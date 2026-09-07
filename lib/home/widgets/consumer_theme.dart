import 'package:flutter/material.dart';

class ConsumerTheme {
  // Brand Identity Colors
  static const Color primary = Color(0xFF131722);       // Dark slate background (new aesthetic)
  static const Color actionBlue = Color(0xFF20A376);     // Emerald Green (Buttons, CTA)
  static const Color verifyGreen = Color(0xFF20A376);    // Emerald Green (Success badges)

  // Surfaces
  static const Color backgroundDark = Color(0xFF0F2B46); // Navy blue (matches home screen)
  static const Color surface = Color(0xFF16325B);         // Slightly lighter navy for cards
  static const Color white = Colors.white;
  static const Color border = Color(0xFF2E3B52);          // Subtle slate border

  // Text (on dark Navy background)
  static const Color textDark = Color(0xFFE8EDF3);        // Light text on Navy
  static const Color textGrey = Color(0xFF94A3B8);        // Muted text on Navy

  // Text (on white card surfaces)
  static const Color textOnCard = Color(0xFF0F2B46);      // Trust Navy on white
  static const Color textOnCardSub = Color(0xFF64748B);   // Slate 500 on white
  static const Color red = Colors.red;

  // Gradients or other styles can go here
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(16.0));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(24.0));
}
