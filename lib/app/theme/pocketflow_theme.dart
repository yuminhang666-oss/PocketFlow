import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routing/pocketflow_page_transitions.dart';
import 'frosted_glass.dart';

abstract final class PocketFlowTheme {
  static const primary = Color(0xFF3E63DD);
  static const amber = Color(0xFFFFC53D);
  static const heroLight = Color(0xFFEDF2FE);
  static const heroDark = Color(0xFF1B2441);
  static const onHero = Color(0xFF1F2D5C);
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData glass(Brightness brightness) {
    final base = _build(brightness);
    final dark = brightness == Brightness.dark;
    final scheme = base.colorScheme.copyWith(
      primary: dark ? const Color(0xFF94C5FF) : const Color(0xFF0063D7),
      surface: dark ? const Color(0xFF1D3045) : const Color(0xFFF8FCFF),
      primaryContainer: dark
          ? const Color(0xFF243D59)
          : const Color(0xFFE6F2FF),
      onPrimaryContainer: dark
          ? const Color(0xFFE0EDFC)
          : const Color(0xFF20364D),
      onSurface: dark ? const Color(0xFFF1F6FC) : const Color(0xFF172B40),
      onSurfaceVariant: dark
          ? const Color(0xFFB7C9DB)
          : const Color(0xFF4F6478),
    );
    return base.copyWith(
      extensions: const [FrostedAppearance()],
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          ...base.pageTransitionsTheme.builders,
          TargetPlatform.android: const PocketFlowPageTransitions(
            fallbackColor: Colors.transparent,
          ),
        },
      ),
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface.withValues(alpha: .88),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: scheme.surface,
      ),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFADBFFF) : primary,
          onPrimary: dark ? const Color(0xFF14224B) : Colors.white,
          surface: dark ? const Color(0xFF1C1F28) : Colors.white,
          onSurface: dark ? const Color(0xFFF0F2F8) : const Color(0xFF1C2024),
          onSurfaceVariant: dark
              ? const Color(0xFFB2B8C8)
              : const Color(0xFF60646C),
          primaryContainer: dark ? heroDark : heroLight,
          onPrimaryContainer: dark ? const Color(0xFFD6E1FF) : onHero,
          outlineVariant: dark
              ? const Color(0xFF353A48)
              : const Color(0xFFE3E7EF),
          error: dark ? const Color(0xFFFFB4B0) : const Color(0xFFB42335),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final background = dark ? const Color(0xFF101218) : const Color(0xFFF3F5F9);
    return base.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          ...base.pageTransitionsTheme.builders,
          TargetPlatform.android: const PocketFlowPageTransitions(),
        },
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: base.textTheme.titleLarge?.fontFamily,
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        systemOverlayStyle:
            (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: background,
                  systemNavigationBarIconBrightness: dark
                      ? Brightness.light
                      : Brightness.dark,
                ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
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
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: scheme.primary,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
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
