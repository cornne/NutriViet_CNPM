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

/// Luminous ambient botanical backdrop cached in a single static
/// [RepaintBoundary] with minimal radial overdraw so scrolling never re-paints
/// the background layer.
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
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [
                          Color(0xFF06101B),
                          Color(0xFF091B18),
                          Color(0xFF071321),
                        ]
                      : const [
                          Color(0xFFEAF6EF),
                          Color(0xFFF4F8FB),
                          Color(0xFFE9F4EE),
                        ],
                ),
              ),
              child: CustomPaint(
                isComplex: true,
                willChange: false,
                painter: _AmbientOrbsPainter(dark: dark),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientOrbsPainter extends CustomPainter {
  final bool dark;

  const _AmbientOrbsPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    void paintOrb(Offset centerFraction, double radiusFactor, Color color) {
      final center = Offset(
        size.width * centerFraction.dx,
        size.height * centerFraction.dy,
      );
      final radius = size.shortestSide * radiusFactor;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // Two clean ambient light sources instead of 6 overlapping full-screen
    // radials cuts pixel overdraw 3x while preserving soft botanical depth.
    if (dark) {
      paintOrb(const Offset(0.18, 0.14), 0.70, const Color(0x4D10B981));
      paintOrb(const Offset(0.84, 0.78), 0.66, const Color(0x3D4F37C8));
    } else {
      paintOrb(const Offset(0.16, 0.10), 0.72, const Color(0x4222C55E));
      paintOrb(const Offset(0.84, 0.84), 0.68, const Color(0x3634D399));
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientOrbsPainter oldDelegate) {
    return oldDelegate.dark != dark;
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

/// Ultra-light frosted glass card isolated in a [RepaintBoundary] so scrolling
/// lists reuse cached GPU card textures without re-rasterizing text/shadows.
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
    this.elevated = true,
    this.isolateRepaint = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cornerRadius);
    final Widget innerContent = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    final Widget decorated = DecoratedBox(
      decoration: BoxDecoration(
        // Crisp near-white opaque frosted surface lets Impeller skip alpha
        // blending behind cards while preserving the luminous botanical aesthetic.
        color: color ?? const Color(0xFFFAFDFB),
        borderRadius: radius,
        border: border ??
            const Border.fromBorderSide(
              BorderSide(color: Color(0xFFE6EFEA), width: 1.05),
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
          ? Material(
              type: MaterialType.transparency,
              clipBehavior: Clip.none,
              child: InkWell(
                borderRadius: radius,
                splashColor: const Color(0x1410B981),
                highlightColor: const Color(0x28FFFFFF),
                onTap: onTap,
                child: innerContent,
              ),
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
