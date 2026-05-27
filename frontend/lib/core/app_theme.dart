import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // === Minimalist Color Palette ===
  static const Color primary = Color(0xFF800000); // Maroon - Primary color
  static const Color maroon = primary; // Backward compatibility
  static const Color maroonDark = Color(0xFF5C0000);
  static const Color maroonLight = Color(0xFFA63333);
  static const Color maroonSurface = Color(0xFFFFF5F5); // Very subtle maroon tint
  static const Color background = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceAccent = Color(0xFFFAFAFA); // Minimal gray
  static const Color bodyText = Color(0xFF1F2937); // Softer black

  // Accent & Semantic Colors - Softer palette
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFF5C842);
  static const Color teal = Color(0xFF0EA5E9);
  static const Color tealLight = Color(0xFFE0F2FE);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color slate50 = Color(0xFFFAFAFA);
  static const Color slate100 = Color(0xFFF5F5F5);
  static const Color slate200 = Color(0xFFE5E5E5);
  static const Color slate300 = Color(0xFFD4D4D4);
  static const Color slate400 = Color(0xFFA3A3A3);
  static const Color slate500 = Color(0xFF737373);
  static const Color slate600 = Color(0xFF525252);
  static const Color slate700 = Color(0xFF404040);
  static const Color slate800 = Color(0xFF262626);
  static const Color slate900 = Color(0xFF171717);

  static ThemeData get theme {
    // Minimalist typography with Inter font
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w700, letterSpacing: -1.5, color: bodyText),
      displayMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w700, letterSpacing: -1.0, color: bodyText),
      displaySmall: GoogleFonts.inter(
          fontWeight: FontWeight.w600, letterSpacing: -0.5, color: bodyText),
      headlineLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w700, letterSpacing: -1.0, color: bodyText),
      headlineMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w600, letterSpacing: -0.5, color: bodyText),
      headlineSmall: GoogleFonts.inter(
          fontWeight: FontWeight.w600, letterSpacing: -0.3, color: bodyText),
      titleLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w600, letterSpacing: -0.3, color: bodyText),
      titleMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w600, letterSpacing: -0.2, color: bodyText),
      titleSmall: GoogleFonts.inter(
          fontWeight: FontWeight.w500, letterSpacing: 0, color: bodyText),
      bodyLarge: GoogleFonts.inter(color: bodyText, letterSpacing: 0),
      bodyMedium: GoogleFonts.inter(color: bodyText, letterSpacing: 0),
      bodySmall: GoogleFonts.inter(color: slate600, letterSpacing: 0),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: background,
        surfaceContainerHighest: surfaceAccent,
        onSurface: bodyText,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: background,

      // AppBar - Minimalist
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: bodyText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: bodyText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: slate700),
      ),

      // Cards - Clean and minimal
      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: slate200, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button - Softer, more minimal
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),

      // Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: slate300, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),

      // Input fields - Cleaner look
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: slate50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: slate600, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: slate400, fontSize: 14),
      ),

      // Bottom Nav - Minimal
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: slate500,
        selectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: slate100,
        labelStyle: GoogleFonts.inter(
            color: slate700, fontWeight: FontWeight.w500, fontSize: 13),
        side: BorderSide(color: slate200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Divider
      dividerTheme: DividerThemeData(
          color: slate200, thickness: 1, space: 1),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: bodyText,
          fontSize: 20,
        ),
        contentTextStyle: GoogleFonts.inter(color: bodyText, fontSize: 15),
      ),
    );
  }

  // Minimalist card styles
  static BoxDecoration get modernCard => BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: slate200, width: 1.0),
      );

  static BoxDecoration get headerGradient => const BoxDecoration(
        color: primary,
      );

  static BoxDecoration get glassCard => BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: slate200, width: 1.0),
      );

  // Subtle shadow for elevated elements
  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: slate900.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // Minimal card with shadow
  static BoxDecoration get elevatedCard => BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: subtleShadow,
      );

  // Status colors
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
        return const Color(0xFF10B981); // emerald
      case 'ditolak':
        return const Color(0xFFDC2626); // red
      case 'pending':
        return const Color(0xFFF59E0B); // amber
      default:
        return Colors.black54;
    }
  }

  static IconData statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
        return Icons.check_circle_outline;
      case 'ditolak':
        return Icons.highlight_off;
      case 'pending':
        return Icons.hourglass_empty;
      default:
        return Icons.info_outline;
    }
  }
}
