import 'package:flutter/material.dart';

abstract final class PocketFlowTheme {
  static const primary = Color(0xFF3E63DD);
  static const amber = Color(0xFFFFC53D);
  static const heroLight = Color(0xFFEDF2FE);
  static const heroDark = Color(0xFF1B2441);
  static const onHero = Color(0xFF1F2D5C);
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFADBFFF) : primary,
          onPrimary: dark ? const Color(0xFF14224B) : Colors.white,
          surface: dark ? const Color(0xFF1C202A) : Colors.white,
          onSurface: dark ? const Color(0xFFF0F2F8) : const Color(0xFF1C2024),
          onSurfaceVariant: dark
              ? const Color(0xFFB2B8C8)
              : const Color(0xFF60646C),
          primaryContainer: dark ? heroDark : heroLight,
          onPrimaryContainer: dark ? const Color(0xFFD6E1FF) : onHero,
          outlineVariant: dark
              ? const Color(0xFF3C4150)
              : const Color(0xFFE0E1E6),
          error: dark ? const Color(0xFFFFB4B0) : const Color(0xFFB42335),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final background = dark ? const Color(0xFF11131B) : const Color(0xFFF9F9FB);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.4,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
