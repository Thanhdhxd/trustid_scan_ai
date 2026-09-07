import 'package:flutter/material.dart';

class TrustIDColors {
  // --- PRIMARY BRAND COLORS (theo Brand Guideline) ---
  static const Color primary = Color(0xFF0F2B46);    // Trust Navy - 60% (Logo, Header, CTA chủ đạo)
  static const Color secondary = Color(0xFF00875A);   // Verify Green - 30% (Nút, link, icon tương tác, active)
  static const Color success = Color(0xFF00875A);     // Verify Green - 10% (Badge, xác thực, EUDR)
  static const Color accent = Color(0xFF00C853);      // Vivid Green (Dark mode success variant)

  // --- APP THEME (Trust Navy background) ---
  static const Color background = Color(0xFF0F2B46);    // Trust Navy background
  static const Color surface = Color(0xFF16325B);       // Card BG (Deep Navy)
  static const Color cardWhite = Colors.white;           // White cards for content
  static const Color border = Color(0xFF1E3A5F);         // Subtle glow border
  static const Color textPrimary = Color(0xFFE8EDF3);    // Light text on dark
  static const Color textSecondary = Color(0xFF94A3B8);  // Muted text on dark
  static const Color textMuted = Color(0xFF64748B);      // Very muted

  // --- DARK THEME (Auth/Dark Mode) ---
  static const Color backgroundDark = Color(0xFF0A1628);  // Void Black
  static const Color surfaceDark = Color(0xFF16325B);      // Deep Navy
  static const Color borderDark = Color(0xFF1E3A5F);       // Subtle glow
  static const Color textOnDark = Color(0xFFE8EDF3);       // Light text on dark
  static const Color textOnDarkSecondary = Colors.white70;
  static const Color textOnDarkMuted = Colors.white38;
}

// --- GLOBAL CONSTANTS ---
const Color kPrimaryColor = TrustIDColors.primary;       // Trust Navy
const Color kSecondaryColor = TrustIDColors.secondary;    // Verify Green (buttons, active)
const Color kSuccessColor = TrustIDColors.success;        // Verify Green

// Text colors for dark Navy background
const Color kHeaderColor = TrustIDColors.textPrimary;
const Color kTextDark = TrustIDColors.textPrimary;
const Color kTextLight = Color(0xFFE8EDF3);   // Light text for Navy background
const Color kTextLight70 = Color(0xB3E8EDF3);
const Color kTextLight38 = Color(0x61E8EDF3);

// Auth screens (dark background)
const Color kAuthLabelColor = Colors.white70;
const Color kAuthTextColor = Colors.white;

const Color kSurfaceDark = TrustIDColors.surfaceDark;
const Color kBackgroundDark = TrustIDColors.background;
const Color kTextGray = TrustIDColors.textSecondary;
