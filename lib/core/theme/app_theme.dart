import 'package:flutter/material.dart';

class AppTheme {
  static final InputDecorationTheme darkInputDecoration = InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF163452),
    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF00875A)),
    ),
  );
}
