import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const bg          = Color(0xFFF0F8F8);
  static const panel       = Color(0xFFE4F1EF);
  static const panelDeep   = Color(0xFFD8ECE8);
  static const line        = Color(0xFFD3E6E2);

  static const ink         = Color(0xFF0B1210);
  static const inkSoft     = Color(0xFF4B5955);
  static const inkFaint    = Color(0xFF8A9A96);

  static const green       = Color(0xFF149954);
  static const greenDeep   = Color(0xFF0F7A43);
  static const greenSoft   = Color(0xFFDCF3E7);

  static const amber       = Color(0xFFB98900);
  static const danger      = Color(0xFFC1442E);

  static const white       = Color(0xFFFFFFFF);
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.green,
          onPrimary: AppColors.white,
          secondary: AppColors.ink,
          surface: AppColors.bg,
          onSurface: AppColors.ink,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: AppColors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: AppColors.line, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.panel,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.green, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
          hintStyle: const TextStyle(color: AppColors.inkFaint, fontSize: 14),
          labelStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
        cardTheme: CardThemeData(
          color: AppColors.panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.line),
          ),
        ),
      );
}
