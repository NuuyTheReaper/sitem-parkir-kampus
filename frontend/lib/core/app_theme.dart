import 'package:flutter/material.dart';

class AppTheme {
  // === Color Palette — Modern Dark Maroon ===
  static const Color maroon = Color(0xFF8B1A1A);
  static const Color maroonDark = Color(0xFF5C1010);
  static const Color maroonLight = Color(0xFFAE3030);
  static const Color maroonSurface = Color(0xFFFFF5F5);

  // Accent & Semantic Colors
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFF5C842);
  static const Color teal = Color(0xFF0EA5E9);
  static const Color tealLight = Color(0xFFE0F2FE);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: maroon,
      brightness: Brightness.light,
      primary: maroon,
      secondary: teal,
      surface: Colors.white,
      error: const Color(0xFFDC2626),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter',

      // Scaffold — Subtle warm neutral
      scaffoldBackgroundColor: const Color(0xFFF6F3F0),

      // AppBar — Premium gradient feel
      appBarTheme: AppBarTheme(
        backgroundColor: maroonDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.9)),
      ),

      // Cards — Glassmorphism-lite with subtle border
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.withOpacity(0.08)),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.2),
        ),
      ),

      // Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),

      // Input fields — Softer, rounded
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: maroon, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFFAF8F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: TextStyle(color: slate500, fontFamily: 'Inter'),
        hintStyle: TextStyle(color: slate500.withOpacity(0.5), fontFamily: 'Inter', fontSize: 14),
        prefixIconColor: slate500,
      ),

      // Bottom Nav — Clean modern
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: maroon,
        unselectedItemColor: slate500,
        selectedLabelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 11),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: StadiumBorder(),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: maroonSurface,
        labelStyle: const TextStyle(fontFamily: 'Inter', color: maroon, fontWeight: FontWeight.w600, fontSize: 12),
        side: BorderSide(color: maroon.withOpacity(0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),

      // Divider
      dividerTheme: DividerThemeData(color: slate200, thickness: 1),

      // Dialog — Rounded modern
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        surfaceTintColor: Colors.transparent,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // Helper: gradient decoration for headers
  static BoxDecoration get headerGradient => const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF3D0C0C), Color(0xFF8B1A1A), Color(0xFFAE3030)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  // Modern card decoration with soft shadow
  static BoxDecoration get modernCard => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.grey.withOpacity(0.06)),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4)),
      BoxShadow(color: maroon.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
    ],
  );

  // Glass card decoration
  static BoxDecoration get glassCard => BoxDecoration(
    color: Colors.white.withOpacity(0.85),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.3)),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
    ],
  );

  // Status colors
  static Color statusColor(String status) {
    switch (status) {
      case 'disetujui': return emerald;
      case 'ditolak': return const Color(0xFFDC2626);
      case 'pending': return amber;
      default: return slate500;
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'disetujui': return Icons.check_circle;
      case 'ditolak': return Icons.cancel;
      case 'pending': return Icons.hourglass_top;
      default: return Icons.circle;
    }
  }
}
