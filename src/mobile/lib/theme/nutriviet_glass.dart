import 'package:flutter/material.dart';

import '../widgets/nutriviet_ui.dart';

/// Shared Frosted Glass palette, atmospheric backdrop, scroll wrapper, and
/// zero-shader-readback card surface engineered for locked 120 Hz performance
/// on high-resolution Android & iOS displays.
class NutriVietGlass {
  NutriVietGlass._();

  static const Color brandGreen = Color(0xFF14803C);
  static const Color brandEmerald = Color(0xFF10B981);
  static const Color brandPurple = Color(0xFF4F37C8);
  static const Color riskRed = Color(0xFFDC2626);
  static const Color inkPrimary = Color(0xFF111827);
  static const Color inkSecondary = Color(0xFF4B5563);
}

/// Luminous ambient botanical backdrop rendered in a single linear gradient
/// pass (zero radial CustomPaint overdraw) so high-DPI Android displays stay
/// well inside the 8.33 ms 120 Hz GPU raster budget during route transitions.
class NutriVietGlassBackdrop extends StatelessWidget {
  final Widget child;
  final bool dark;

  const NutriVietGlassBackdrop({
    super.key,
    required this.child,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xFF071A19),
                        Color(0xFF07131E),
                        Color(0xFF0A1424),
                      ]
                    : const [
                        Color(0xFFDBF1E4),
                        Color(0xFFF1F7F5),
                        Color(0xFFEFF5F9),
                        Color(0xFFDEF0E6),
                      ],
                stops: dark
                    ? const [0.0, 0.52, 1.0]
                    : const [0.0, 0.34, 0.68, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Global 120 Hz scroll behavior using crisp springy [BouncingScrollPhysics]
/// and disabling Android's stretch overscroll shader so every screen bounces
/// cleanly at scroll boundaries instead of clamping dead-flat.
class NutriVietScrollBehavior extends MaterialScrollBehavior {
  const NutriVietScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

/// Wraps a scrollable page/list with smooth springy bounce physics and zero
/// overscroll stretch shader passes for locked 120 Hz scrolling.
class NutriVietGlassScrollArea extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const NutriVietGlassScrollArea({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const NutriVietScrollBehavior(),
      child: child,
    );
  }
}

/// Ultra-light frosted glass card engineered for 120 Hz scrolling lists:
/// - Opaque surface (`#FAFDFB`) + crisp 1.05px hairline border (no per-card
///   Gaussian `BoxShadow` blur pass unless `elevated: true`).
/// - Lightweight `GestureDetector` + `NutriVietPressScale` instead of heavy
///   `Material` + `InkWell` ripple layers.
/// - No default per-card `RepaintBoundary` so GPU texture memory doesn't churn
///   as cards enter/exit the viewport.
class NutriVietGlassCard extends StatelessWidget {
  final Widget child;
  final double cornerRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;
  final bool elevated;
  final bool isolateRepaint;

  const NutriVietGlassCard({
    super.key,
    required this.child,
    this.cornerRadius = 22,
    this.padding,
    this.color,
    this.border,
    this.onTap,
    this.elevated = false,
    this.isolateRepaint = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cornerRadius);
    final Widget innerContent = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    final Widget decorated = DecoratedBox(
      decoration: BoxDecoration(
        // Crisp near-white opaque frosted surface lets Impeller/Skia skip alpha
        // blending behind cards while preserving the luminous botanical aesthetic.
        color: color ?? const Color(0xFFFAFDFB),
        borderRadius: radius,
        border: border ??
            const Border.fromBorderSide(
              BorderSide(color: Color(0xFFE0EAE4), width: 1.05),
            ),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x0B0F172A),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: innerContent,
            )
          : innerContent,
    );

    final Widget surface = isolateRepaint
        ? RepaintBoundary(child: decorated)
        : decorated;

    if (onTap == null) return surface;

    return NutriVietPressScale(
      pressedScale: 0.985,
      child: surface,
    );
  }
}
