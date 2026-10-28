import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Native Flutter frosted surfaces. No third-party shaders or assets.
class FrostedAppearance extends ThemeExtension<FrostedAppearance> {
  const FrostedAppearance();
  static bool enabled(BuildContext context) =>
      Theme.of(context).extension<FrostedAppearance>() != null;
  @override
  FrostedAppearance copyWith() => this;
  @override
  FrostedAppearance lerp(covariant FrostedAppearance? other, double t) => this;
}

class FrostedBackdrop extends StatelessWidget {
  const FrostedBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF101B2B), Color(0xFF172C3C), Color(0xFF142239)]
              : const [Color(0xFFEDF5FC), Color(0xFFF3F6FA), Color(0xFFE4F0F3)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, -0.65),
            radius: 1.1,
            colors: [
              (dark ? const Color(0xFF368BA8) : const Color(0xFF91CAE4))
                  .withValues(alpha: dark ? .15 : .34),
              Colors.transparent,
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.color,
    this.accent = false,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final glass = FrostedAppearance.enabled(context);
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final fill = accent ? scheme.primaryContainer : scheme.surface;
    final content = Material(
      color: Colors.transparent,
      child: Padding(padding: padding, child: child),
    );
    if (!glass) {
      return Container(
        decoration: BoxDecoration(
          color: color ?? fill,
          borderRadius: BorderRadius.circular(radius),
          border: accent
              ? null
              : Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .5),
                  width: .6,
                ),
          boxShadow: accent
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: dark ? .04 : .06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          enabled: !highContrast,
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fill.withValues(
                    alpha: highContrast
                        ? 1
                        : dark
                        ? .88
                        : .82,
                  ),
                  fill.withValues(
                    alpha: highContrast
                        ? 1
                        : dark
                        ? .72
                        : .60,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: highContrast
                    ? scheme.outline
                    : Colors.white.withValues(alpha: dark ? .17 : .85),
                width: 1,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
