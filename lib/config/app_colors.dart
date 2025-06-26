import 'package:flutter/material.dart';

/// Colores oficiales de la aplicación Tourify
class AppColors {
  // Colores principales de la marca
  static const Color primary = Color(0xFF0062FF); // Azul principal de Tourify
  static const Color primaryLight = Color(0xFF60A5FA); // Azul claro
  static const Color primaryDark = Color(0xFF0D47A1); // Azul oscuro

  // Colores de Civitatis (socio)
  static const Color civitatis = Color(0xFFFF0055); // Rosa/magenta de Civitatis

  // Colores de gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary],
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  // Colores semánticos
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Colores neutros
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // Colores premium
  static const Color premium = Color(0xFFFFD700); // Dorado
  static const Color premiumDark = Color(0xFFFFA000); // Dorado oscuro

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [premium, premiumDark],
  );
}
