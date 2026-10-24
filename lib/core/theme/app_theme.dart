// lib/core/theme/app_theme.dart
//
// Tema único de la app -- Manrope para titulares (geométrica, con carácter,
// evita el aspecto "Flutter por defecto") + Inter para texto largo
// (máxima legibilidad en listas y formularios).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData buildAppTheme() {
  final headingFont = GoogleFonts.manropeTextTheme();
  final bodyFont = GoogleFonts.interTextTheme();

  final textTheme = bodyFont.copyWith(
    displaySmall: headingFont.displaySmall?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.3,
    ),
    headlineSmall: headingFont.headlineSmall?.copyWith(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.2,
    ),
    titleMedium: headingFont.titleMedium?.copyWith(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: bodyFont.bodyLarge?.copyWith(
      fontSize: 14.5,
      color: AppColors.ink,
      height: 1.4,
    ),
    bodyMedium: bodyFont.bodyMedium?.copyWith(
      fontSize: 13,
      color: AppColors.inkMuted,
      height: 1.4,
    ),
    bodySmall: bodyFont.bodySmall?.copyWith(
      fontSize: 11.5,
      color: AppColors.inkMuted,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: headingFont.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: AppColors.esOscuro ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: AppColors.esOscuro ? Brightness.dark : Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.displaySmall?.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      labelStyle: TextStyle(color: AppColors.inkMuted),
      hintStyle: TextStyle(color: AppColors.inkFaint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // En oscuro, `primary` está aclarado para leerse como texto/icono
        // sobre negro -- como fondo con texto blanco se usa `primaryStrong`
        // en su lugar (ver nota en AppColors/_Dark).
        backgroundColor: AppColors.esOscuro ? AppColors.primaryStrong : AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: textTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.esOscuro ? AppColors.primaryStrong : AppColors.primary,
      side: BorderSide(color: AppColors.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.inkFaint,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
  );
}
