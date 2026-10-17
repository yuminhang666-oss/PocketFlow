import 'package:flutter/material.dart';

abstract final class PocketFlowTheme {
  static const primary = Color(0xFF2E6B58);
  static const heroLight = Color(0xFF153E35);
  static const heroDark = Color(0xFF1F493C);
  static const onHero = Color(0xFFF6FAF4);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFF9BCBB5) : primary,
          onPrimary: dark ? const Color(0xFF10291F) : Colors.white,
          surface: dark ? const Color(0xFF192620) : Colors.white,
          onSurface: dark ? const Color(0xFFEDF3EE) : const Color(0xFF202D27),
          onSurfaceVariant: dark
              ? const Color(0xFFA7B7AD)
              : const Color(0xFF64736B),
          primaryContainer: dark
              ? const Color(0xFF243C31)
              : const Color(0xFFE7EEE5),
          onPrimaryContainer: dark
              ? const Color(0xFFEDF3EE)
              : const Color(0xFF202D27),
          outlineVariant: dark
              ? const Color(0xFF3B5044)
              : const Color(0xFFDCE3DC),
          error: dark ? const Color(0xFFF4B3AA) : const Color(0xFF9B3F38),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: dark
          ? const Color(0xFF101A16)
          : const Color(0xFFF5F6F2),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xFF101A16)
            : const Color(0xFFF5F6F2),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontSize: 48,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.5,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
