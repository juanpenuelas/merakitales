import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.destructive,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    TextStyle fr(TextStyle? s) =>
        GoogleFonts.fraunces(textStyle: s, color: AppColors.textPrimary, fontWeight: FontWeight.w600);
    final textTheme = inter.copyWith(
      displayLarge: fr(inter.displayLarge),
      displayMedium: fr(inter.displayMedium),
      displaySmall: fr(inter.displaySmall),
      headlineLarge: fr(inter.headlineLarge),
      headlineMedium: fr(inter.headlineMedium),
      headlineSmall: fr(inter.headlineSmall),
      titleLarge: fr(inter.titleLarge),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
