import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../widgets/nutriviet_ui.dart';

/// Shared Liquid Glass styles, optical presets, batches, and botanical
/// atmospheric backdrop for NutriViet at 120 Hz.
///
/// Built around `liquid_glass_easy`:
/// - Batched single-pass Impeller shader lenses ([NutriVietGlassScrollArea])
/// - True two-light rims (`specular` + `glow`) and soft dispersion on focal bars
/// - Contact shadows (`LiquidGlassShadow(insideGlass: false)`) that never clip
///   into the backdrop refraction
/// - Tactile soft-body deformation ([touchSubtle], [touchPronounced],
///   [touchHorizontalCapsule]) for glass buttons, pills, and floating chrome
class NutriVietGlass {
  NutriVietGlass._();

  static const Color brandGreen = Color(0xFF14803C);
  static const Color brandEmerald = Color(0xFF10B981);
  static const Color brandPurple = Color(0xFF4F37C8);
  static const Color riskRed = Color(0xFFDC2626);
  static const Color inkPrimary = Color(0xFF111827);
  static const Color inkSecondary = Color(0xFF4B5563);

  // ── Optical rim light presets ──────────────────────────────────────────────

  static const LiquidGlassLight _crispSpecular = LiquidGlassLight.specular(
    thickness: 2.6,
    sharpness: 0.62,
    angle: 40,
    spread: 0.92,
    intensity: 0.92,
  );

  static const LiquidGlassLight _cardGlow = LiquidGlassLight.glow(
    thickness: 9,
    angle: 135,
    spread: 0.55,
    intensity: 0.24,
    color: Color(0xFFECFDF5),
  );

  static const LiquidGlassLight _emeraldSpecular = LiquidGlassLight.specular(
    thickness: 3.0,
    sharpness: 0.65,
    angle: 38,
    spread: 0.95,
    intensity: 1.05,
    color: Color(0xFFD1FAE5),
  );

  static const LiquidGlassLight _emeraldGlow = LiquidGlassLight.glow(
    thickness: 10,
    angle: 130,
    spread: 0.6,
    intensity: 0.38,
    color: Color(0xFF34D399),
  );

  static const LiquidGlassLight _redSpecular = LiquidGlassLight.specular(
    thickness: 2.8,
    sharpness: 0.65,
    angle: 40,
    spread: 0.92,
    intensity: 1.0,
    color: Color(0xFFFEE2E2),
  );

  static const LiquidGlassLight _redGlow = LiquidGlassLight.glow(
    thickness: 10,
    angle: 130,
    spread: 0.55,
    intensity: 0.34,
    color: Color(0xFFF87171),
  );

  // ── Touch flex presets ─────────────────────────────────────────────────────

  /// Subtle soft-body flex for floating chrome, app bars, and wide pills.
  static const LiquidGlassTouch touchSubtle = LiquidGlassTouch.flexing(
    LiquidGlassFlex.subtle(),
  );

  /// Expressive soft-body flex for orbs, action buttons, and focal pills.
  static const LiquidGlassTouch touchPronounced = LiquidGlassTouch.flexing(
    LiquidGlassFlex.pronounced(),
  );

  /// Horizontal-locked capsule flex so wide bars swell smoothly without
  /// bulging awkwardly vertically under horizontal drags.
  static const LiquidGlassTouch touchHorizontalCapsule =
      LiquidGlassTouch.flexing(
    LiquidGlassFlex(
      stretch: 6,
      squeeze: 0.65,
      lean: 0.28,
      grip: 0.5,
      holdScale: 0.018,
      tapScale: 0.014,
      maxPull: 56,
      lockAxis: Axis.horizontal,
    ),
  );

  // ── Focal UI styles ────────────────────────────────────────────────────────

  /// Floating search / top chrome bar — crisp optical refraction + frosted blur
  /// tuned without chromatic 3-pass dispersion so 120 Hz transitions stay fast.
  static const LiquidGlassStyle floatingChrome = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 24),
    specular: _crispSpecular,
    glow: _cardGlow,
    refractionIndex: 1.08,
    refractionWidth: 16,
    magnification: 1.02,
    dispersion: 0.0,
    saturation: 1.08,
    blur: 1.6,
    color: Color(0xCEFFFFFF),
  );

  /// Style passed to [LiquidGlassAppBar] headers across sub-screens.
  static const LiquidGlassStyle appBar = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 26),
    specular: _crispSpecular,
    glow: _cardGlow,
    refractionIndex: 1.08,
    refractionWidth: 16,
    magnification: 1.02,
    dispersion: 0.0,
    saturation: 1.08,
    blur: 1.8,
    color: Color(0xD4FFFFFF),
  );

  /// Circular floating utility button orb (search, filter, language, back).
  static const LiquidGlassStyle circleOrb = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: 99),
    specular: _crispSpecular,
    glow: _cardGlow,
    refractionIndex: 1.13,
    refractionWidth: 16,
    magnification: 1.04,
    dispersion: 1.1,
    saturation: 1.12,
    blur: 2.0,
    color: Color(0xCCFFFFFF),
  );

  /// Emerald floating action orb (scanner FAB / docked scan action).
  static const LiquidGlassStyle emeraldActionOrb = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: 99),
    specular: _emeraldSpecular,
    glow: _emeraldGlow,
    refractionIndex: 1.14,
    refractionWidth: 18,
    magnification: 1.05,
    dispersion: 1.2,
    saturation: 1.18,
    blur: 2.5,
    color: Color(0xE614803C),
  );

  /// Smoked refractive glass used over dark camera preview controls.
  static const LiquidGlassStyle smokedCameraGlass = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 22),
    specular: LiquidGlassLight.specular(
      thickness: 3.0,
      sharpness: 0.65,
      angle: 38,
      spread: 0.94,
      intensity: 1.1,
      color: Color(0xFFE2E8F0),
    ),
    glow: LiquidGlassLight.glow(
      thickness: 10,
      angle: 132,
      spread: 0.55,
      intensity: 0.28,
      color: Color(0xFF34D399),
    ),
    refractionIndex: 1.12,
    refractionWidth: 20,
    magnification: 1.03,
    dispersion: 1.0,
    saturation: 1.10,
    blur: 7.5,
    color: Color(0x9A0F172A),
    shadow: LiquidGlassShadow(
      blur: 16,
      opacity: 0.28,
      offset: Offset(0, 6),
      inset: 2,
      insideGlass: false,
    ),
  );

  /// Style for [LiquidGlassBlender] clusters (scanner controls, category pills).
  static const LiquidGlassStyle blenderCluster = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: 99),
    specular: _crispSpecular,
    glow: _cardGlow,
    refractionIndex: 1.10,
    refractionWidth: 16,
    magnification: 1.03,
    dispersion: 0.9,
    saturation: 1.12,
    blur: 6,
    color: Color(0xC6FFFFFF),
  );

  /// Smoked [LiquidGlassBlender] cluster for the camera viewfinder controls.
  static const LiquidGlassStyle darkBlenderCluster = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: 99),
    specular: LiquidGlassLight.specular(
      thickness: 3.0,
      sharpness: 0.65,
      angle: 39,
      spread: 0.95,
      intensity: 1.05,
      color: Color(0xFFECFDF5),
    ),
    glow: LiquidGlassLight.glow(
      thickness: 10,
      angle: 132,
      spread: 0.55,
      intensity: 0.3,
      color: Color(0xFF34D399),
    ),
    refractionIndex: 1.14,
    refractionWidth: 18,
    magnification: 1.04,
    dispersion: 1.2,
    saturation: 1.14,
    blur: 7,
    color: Color(0x9E0B1324),
  );

  /// Floating bottom tab bar capsule (`LiquidGlassTabBar`).
  static const LiquidGlassStyle navBar = LiquidGlassStyle(
    specular: _crispSpecular,
    glow: _cardGlow,
    refractionIndex: 1.09,
    refractionWidth: 18,
    magnification: 1.02,
    dispersion: 0.0,
    saturation: 1.08,
    blur: 2.0,
    color: Color(0xCEFFFFFF),
  );

  /// Moving liquid selection pill inside `LiquidGlassTabBar` (full iOS 26
  /// lifting/morphing glass pill + magnifier under the finger on Impeller).
  static const LiquidGlassStyle _navMovingGlassPill = LiquidGlassStyle(
    specular: LiquidGlassLight.specular(
      thickness: 2.6,
      sharpness: 0.68,
      angle: 42,
      spread: 0.92,
      intensity: 1.0,
      color: Color(0xFFD1FAE5),
    ),
    glow: LiquidGlassLight.glow(
      thickness: 8,
      angle: 132,
      spread: 0.55,
      intensity: 0.35,
      color: Color(0xFF34D399),
    ),
    refractionIndex: 1.05,
    refractionWidth: 18,
    magnification: 1.06,
    dispersion: 1.32,
    saturation: 1.15,
    blur: 0,
    color: Color(0x2A14803C),
  );

  static const LiquidGlassStyle _navRestPill = LiquidGlassStyle(
    color: Color(0x2814803C),
  );

  static const LiquidGlassTabPillStyle navPill = LiquidGlassTabPillStyle(
    mode: LiquidGlassPillMode.impellerOnly,
    show: true,
    color: Color(0x2814803C),
    animated: true,
    growHeight: 10,
    growWidth: 14,
    confineToBar: false,
    refractionIndex: 1.05,
    refractionWidth: 18,
    magnification: 1.06,
    dispersion: 1.32,
    blur: 0,
    glassStyle: _navMovingGlassPill,
    rest: _navRestPill,
  );

  /// Bright frosted bottom sheet & dialog surface with high contrast for dark ink.
  static const LiquidGlassStyle lightSheet = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 28),
    specular: _crispSpecular,
    glow: _cardGlow,
    refractionIndex: 1.06,
    refractionWidth: 20,
    dispersion: 0.6,
    saturation: 1.06,
    blur: 14,
    color: Color(0xE8FFFFFF),
  );

  /// Emerald frosted CTA capsule for primary glass buttons.
  static const LiquidGlassStyle emeraldButton = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 24),
    specular: _emeraldSpecular,
    glow: _emeraldGlow,
    refractionIndex: 1.08,
    refractionWidth: 14,
    magnification: 1.02,
    saturation: 1.16,
    blur: 0.0,
    color: Color(0xDF14803C),
  );

  /// Deep crimson frosted CTA capsule for destructive/allergy actions.
  static const LiquidGlassStyle dangerButton = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 24),
    specular: _redSpecular,
    glow: _redGlow,
    refractionIndex: 1.08,
    refractionWidth: 14,
    magnification: 1.02,
    saturation: 1.14,
    blur: 0.0,
    color: Color(0xDEEF4444),
  );

  /// Neutral frosted capsule for secondary buttons.
  static const LiquidGlassStyle neutralButton = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 24),
    specular: _crispSpecular,
    glow: _cardGlow,
    refractionIndex: 1.06,
    refractionWidth: 12,
    saturation: 1.06,
    blur: 0.0,
    color: Color(0xBAFFFFFF),
  );

  /// Emerald hero liquid lens (used on the home hero banner).
  static const LiquidGlassStyle heroEmeraldCard = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 26),
    specular: _emeraldSpecular,
    glow: _emeraldGlow,
    refractionIndex: 1.065,
    refractionWidth: 22,
    magnification: 1.015,
    dispersion: 0.0,
    saturation: 1.18,
    blur: 0.0,
    color: Color(0xD8147D3B),
  );

  /// Translucent frosted card style backed by a real batched [LiquidGlassLens].
  static LiquidGlassStyle cardGlass({
    double cornerRadius = 22,
    Color? tint,
    LiquidGlassShadow? shadow,
    bool elevated = true,
  }) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: cornerRadius,
      ),
      specular: _crispSpecular,
      glow: _cardGlow,
      refractionIndex: 1.045,
      refractionWidth: 16,
      magnification: 1.012,
      saturation: 1.08,
      blur: 5.5,
      color: tint ?? const Color(0xCEFFFFFF),
      shadow: shadow,
    );
  }
}

/// Luminous ambient backdrop behind Liquid Glass surfaces.
///
/// Layered emerald, sky-jade, and warm sunlit orbs painted into a cached
/// [RepaintBoundary] give surrounding glass lenses vibrant depth cues and
/// luminous edge refraction at zero ongoing GPU cost.
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
                          Color(0xFFEEF7F1),
                          Color(0xFFF4F8FB),
                          Color(0xFFEAF5EE),
                        ],
                ),
              ),
              child: CustomPaint(
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

    if (dark) {
      paintOrb(const Offset(0.18, 0.14), 0.72, const Color(0x5510B981));
      paintOrb(const Offset(0.86, 0.24), 0.62, const Color(0x454F37C8));
      paintOrb(const Offset(0.75, 0.80), 0.68, const Color(0x400EA5E9));
      paintOrb(const Offset(0.12, 0.85), 0.55, const Color(0x3014803C));
    } else {
      paintOrb(const Offset(0.14, 0.08), 0.75, const Color(0x4D22C55E));
      paintOrb(const Offset(0.88, 0.16), 0.62, const Color(0x3D10B981));
      paintOrb(const Offset(0.90, 0.52), 0.54, const Color(0x350EA5E9));
      paintOrb(const Offset(0.08, 0.58), 0.50, const Color(0x284F37C8));
      paintOrb(const Offset(0.78, 0.88), 0.70, const Color(0x4234D399));
      paintOrb(const Offset(0.18, 0.90), 0.52, const Color(0x2EF59E0B));
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientOrbsPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}

/// Wraps a scrollable page/list containing [LiquidGlassLens] items:
/// 1. Disables Android's stretch overscroll effect so scrollables never
///    isolate backdrop reads into a black stretch buffer.
/// 2. Batches all non-overlapping descendant lenses into a single-pass
///    Impeller backdrop copy for locked 120 Hz scrolling.
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
      behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      child: LiquidGlassBatch(
        enabled: enabled,
        mode: LiquidGlassBatchMode.singlePass,
        blurMethod: LiquidGlassBlurMethod.shader,
        child: child,
      ),
    );
  }
}

/// Frosted Liquid Glass container powered by a real batched [LiquidGlassLens].
///
/// Gives content cards squircle geometry, true specular/glow highlights,
/// subtle optical refraction, contact shadow, and optional tactile press flex
/// at 120 Hz.
class NutriVietGlassCard extends StatelessWidget {
  final Widget child;
  final double cornerRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;
  final LiquidGlassTouch? touch;
  final bool elevated;
  final bool useShaderGlass;

  const NutriVietGlassCard({
    super.key,
    required this.child,
    this.cornerRadius = 22,
    this.padding,
    this.color,
    this.border,
    this.onTap,
    this.touch,
    this.elevated = true,
    this.useShaderGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cornerRadius);
    final innerContent = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    final borderedContent = border != null
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: border,
            ),
            child: innerContent,
          )
        : innerContent;

    final interactiveContent = onTap != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              splashColor: NutriVietGlass.brandEmerald.withValues(alpha: 0.08),
              highlightColor: Colors.white.withValues(alpha: 0.25),
              onTap: onTap,
              child: borderedContent,
            ),
          )
        : borderedContent;

    final Widget surface = useShaderGlass
        ? LiquidGlassLens(
            touch: touch,
            style: NutriVietGlass.cardGlass(
              cornerRadius: cornerRadius,
              tint: color ?? const Color(0xCCFFFFFF),
              elevated: elevated,
            ),
            child: interactiveContent,
          )
        : Container(
            decoration: BoxDecoration(
              color: color ?? const Color(0xDEFFFFFF),
              borderRadius: radius,
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.1,
                  ),
              boxShadow: elevated
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: interactiveContent,
            ),
          );

    if (onTap == null) return surface;

    return NutriVietPressScale(
      pressedScale: 0.982,
      child: surface,
    );
  }
}
