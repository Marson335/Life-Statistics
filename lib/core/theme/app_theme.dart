import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Task type colors
  static const Color greenTask = Color(0xFF00C896);
  static const Color blueTask = Color(0xFF4D9FFF);
  static const Color redTask = Color(0xFFFF5252);
  static const Color yellowTask = Color(0xFFFFD740);

  // Background & Surfaces (Style 2: Iron & Steel)
  static const Color background = Color(0xFF0E0F12); // Cast-Iron Matte
  static const Color surface = Color(0xFF14161D); // Matte Heavy Steel
  static const Color surfaceVariant = Color(0xFF1C2029); // Brushed Plate

  // Accent (High-Voltage Neon Lime)
  static const Color accent = Color(0xFFD4FF00);
  static const Color accentLight = Color(0xFFE5FF4D);
  static const Color accentDark = Color(0xFFA6CC00);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9DA4B0);
  static const Color textDisabled = Color(0xFF505662);

  // Status
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);

  // Mindset tracker colors
  static const Color mindsetEnergy = Color(0xFF4D9FFF);
  static const Color mindsetFocus = Color(0xFFD4FF00);
  static const Color mindsetMotivation = Color(0xFF00C896);
  static const Color mindsetMood = Color(0xFFFFD740);

  // Border (Heavy Steel Frame)
  static const Color border = Color(0xFF282C38);
  static const Color borderLight = Color(0xFF1E222D);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: Colors.black, // High-contrast black on neon lime
        secondary: AppColors.blueTask,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Color(0xFF7E8594),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: IconThemeData(color: AppColors.accent),
        unselectedIconTheme: IconThemeData(color: Color(0xFF7E8594)),
        selectedLabelTextStyle: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFF7E8594), fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
      ),
      textTheme: GoogleFonts.chakraPetchTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        headlineLarge: GoogleFonts.chakraPetch(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
        headlineMedium: GoogleFonts.chakraPetch(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
        titleLarge: GoogleFonts.chakraPetch(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        titleMedium: GoogleFonts.chakraPetch(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        bodyLarge: GoogleFonts.chakraPetch(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.chakraPetch(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        labelMedium: GoogleFonts.chakraPetch(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Athletic monospaced/squared font helper
  static TextStyle athletic({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return GoogleFonts.chakraPetch(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.bold,
      letterSpacing: letterSpacing ?? 0.6,
    );
  }

  // Task type color helper
  static Color taskTypeColor(dynamic type) {
    switch (type.toString()) {
      case 'TaskType.green':
      case 'green':
        return AppColors.greenTask;
      case 'TaskType.blue':
      case 'blue':
        return AppColors.blueTask;
      case 'TaskType.red':
      case 'red':
        return AppColors.redTask;
      case 'TaskType.yellow':
      case 'yellow':
        return AppColors.yellowTask;
      case 'TaskType.finance':
      case 'finance':
        return AppColors.accent;
      default:
        return AppColors.blueTask;
    }
  }

  static IconData taskTypeIcon(dynamic type) {
    switch (type.toString()) {
      case 'TaskType.green':
      case 'green':
        return Icons.repeat_rounded;
      case 'TaskType.blue':
      case 'blue':
        return Icons.event_note_rounded;
      case 'TaskType.red':
      case 'red':
        return Icons.warning_amber_rounded;
      case 'TaskType.yellow':
      case 'yellow':
        return Icons.star_rounded;
      case 'TaskType.finance':
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }
}
