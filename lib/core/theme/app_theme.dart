import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const amber50 = Color(0xFFFFF8E1);
  static const amber100 = Color(0xFFFFECB3);
  static const amber200 = Color(0xFFFFE082);
  static const amber400 = Color(0xFFFFCA28);
  static const amber600 = Color(0xFFFFB300);
  static const amber800 = Color(0xFFFF8F00);

  static const honey = Color(0xFFD4920B);
  static const honeyLight = Color(0xFFF5D78E);
  static const honeyDark = Color(0xFF8B5E0B);

  static const brown50 = Color(0xFFEFEBE9);
  static const brown100 = Color(0xFFD7CCC8);
  static const brown300 = Color(0xFFA1887F);
  static const brown600 = Color(0xFF6D4C41);
  static const brown800 = Color(0xFF4E342E);

  static const green50 = Color(0xFFE8F5E9);
  static const green100 = Color(0xFFC8E6C9);
  static const green400 = Color(0xFF66BB6A);
  static const green600 = Color(0xFF43A047);
  static const green800 = Color(0xFF2E7D32);

  static const surface = Color(0xFFFFFDF7);
  static const background = Color(0xFFFAF7F2);
  static const cardBg = Colors.white;
}

class AppTheme {
  static ThemeData get light {
    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.honey,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.brown800,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.brown800,
        selectedIconTheme: const IconThemeData(color: AppColors.amber400),
        unselectedIconTheme: IconThemeData(color: Colors.white.withAlpha(180)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.amber50,
        selectedColor: AppColors.amber200,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
