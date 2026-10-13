import 'package:flutter/material.dart';

class AppColors {
  // Task type colors
  static const Color greenTask = Color(0xFF00C896);
  static const Color blueTask = Color(0xFF4D9FFF);
  static const Color redTask = Color(0xFFFF5252);
  static const Color yellowTask = Color(0xFFFFD740);

  // Background
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceVariant = Color(0xFF21262D);

  // Accent
  static const Color accent = Color(0xFF7C4DFF);
  static const Color accentLight = Color(0xFF9C6FFF);

  // Text
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textDisabled = Color(0xFF484F58);

  // Status
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);

  // Mindset tracker colors
  static const Color mindsetEnergy = Color(0xFF4D9FFF);
  static const Color mindsetFocus = Color(0xFF7C4DFF);
  static const Color mindsetMotivation = Color(0xFF00C896);
  static const Color mindsetMood = Color(0xFFFFD740);

  // Border
  static const Color border = Color(0xFF30363D);
  static const Color borderLight = Color(0xFF21262D);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: AppColors.blueTask,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
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
            return AppColors.greenTask;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: IconThemeData(color: AppColors.accent),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle: TextStyle(color: AppColors.accent, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        labelMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
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
