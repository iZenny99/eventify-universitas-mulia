import 'package:flutter/material.dart';

import 'theme_controller.dart';

class AppColorPalette {
  const AppColorPalette({
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
  });

  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  static const AppColorPalette light = AppColorPalette(
    primary: Color(0xFFEF4444),
    primaryDark: Color(0xFFF97316),
    accent: Color(0xFFF59E0B),
    background: Color(0xFFFFFBF5),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF6B7280),
    divider: Color(0xFFF3E8E0),
    success: Color(0xFF10B981),
    error: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF3B82F6),
  );

  static const AppColorPalette dark = AppColorPalette(
    primary: Color(0xFFFB7185),
    primaryDark: Color(0xFFF97316),
    accent: Color(0xFFF59E0B),
    background: Color(0xFF0B0B10),
    surface: Color(0xFF15151B),
    textPrimary: Color(0xFFF9FAFB),
    textSecondary: Color(0xFF9CA3AF),
    divider: Color(0xFF23232D),
    success: Color(0xFF34D399),
    error: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
  );
}

class AppColors {
  static AppColorPalette get _palette => ThemeController.instance.isDark
      ? AppColorPalette.dark
      : AppColorPalette.light;

  static Color get primary => _palette.primary;
  static Color get primaryDark => _palette.primaryDark;
  static Color get accent => _palette.accent;
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get divider => _palette.divider;
  static Color get success => _palette.success;
  static Color get error => _palette.error;
  static Color get warning => _palette.warning;
  static Color get info => _palette.info;

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
