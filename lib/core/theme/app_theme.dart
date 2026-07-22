import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

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
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: BeeTokens.honig,
        brightness: Brightness.light,
        surface: BeeTokens.karte,
      ),
      scaffoldBackgroundColor: BeeTokens.oberflaeche,
      appBarTheme: AppBarTheme(
        backgroundColor: BeeTokens.karte,
        foregroundColor: BeeTokens.textPrimaer,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: BeeTokens.honig, width: 2)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: BeeTokens.textPrimaer,
        ),
      ),
      cardTheme: CardThemeData(
        color: BeeTokens.karte,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeeTokens.rKarte),
          side: const BorderSide(color: BeeTokens.rand, width: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, BeeTokens.tapMin),
          backgroundColor: BeeTokens.honig,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeeTokens.rControl)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, BeeTokens.tapMin),
          foregroundColor: BeeTokens.textPrimaer,
          side: const BorderSide(color: BeeTokens.randStark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeeTokens.rControl)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, BeeTokens.tapMin),
          foregroundColor: BeeTokens.honig,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BeeTokens.karte,
        selectedColor: BeeTokens.honigTint,
        side: const BorderSide(color: BeeTokens.rand, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeeTokens.rControl)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BeeTokens.karte,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(BeeTokens.rKarte)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BeeTokens.karte,
        indicatorColor: BeeTokens.honigTint,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? BeeTokens.honig : BeeTokens.textGedaempft,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BeeTokens.karte,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeeTokens.rControl),
          borderSide: const BorderSide(color: BeeTokens.rand),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeeTokens.rControl),
          borderSide: const BorderSide(color: BeeTokens.rand),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.brown800,
        selectedIconTheme: IconThemeData(color: AppColors.amber400),
        unselectedIconTheme: IconThemeData(color: Colors.white70),
      ),
    );
  }
}
