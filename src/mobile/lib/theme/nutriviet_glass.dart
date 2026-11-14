import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../widgets/nutriviet_ui.dart';

/// Shared NutriViet Liquid Glass tokens, styles, and lightweight card surfaces.
///
/// Follows Impeller performance guidelines from `liquid_glass_easy`:
/// - Reserve shader-backed [LiquidGlassLens] / [LiquidGlassTabBar] /
///   [LiquidGlassTabBarAction] strictly for floating chrome (<= 3 per screen).
/// - Use zero-backdrop [LiquidGlassLite] (`blur: 0`) inside scrollable lists
///   so frame times stay under 8.33 ms at 120 Hz on Impeller Vulkan.
class NutriVietGlass {
  NutriVietGlass._();

  static const Color bgMist = Color(0xFFF3F6F3);
  static const Color brandGreen = Color(0xFF14803C);
  static const Color brandEmeraldDeep = Color(0xFF0E6830);
  static const Color brandPurple = Color(0xFF4F37C8);
  static const Color inkPrimary = Color(0xFF111827);
  static const Color inkSecondary = Color(0xFF6B7280);

  /// Luminous light glass style for floating bars and search capsules.
  /// Tuned for 120 Hz Impeller frame budgets (zero blur/dispersion multi-reads,
  /// cheap circular capsule SDF, no runtime ring-shadow pass).
  static const LiquidGlassStyle floatingChrome = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: 25),
    specular: LiquidGlassLight.specular(
      thickness: 3.2,
      sharpness: 0.68,
      angle: 39,
      spread: 0.9,
      intensity: 1.0,
      color: Color(0xE6FFFFFF),
    ),
    glow: LiquidGlassLight.glow(
      thickness: 7,
      angle: 115,
      spread: 0.5,
      intensity: 0.35,
      color: Color(0x4AD1FAE5),
    ),
    refractionIndex: 1.028,
    refractionWidth: 14,
    dispersion: 0,
    blur: 0,
    color: Color(0xE8FFFFFF),
  );

  /// Floating circular utility lens (feedback orb, scanner close button).
  static const LiquidGlassStyle circleOrb = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 99),
    specular: LiquidGlassLight.specular(
      thickness: 3.2,
      sharpness: 0.65,
      angle: 39,
      spread: 0.95,
      intensity: 1.1,
      color: Color(0xEEFFFFFF),
    ),
    glow: LiquidGlassLight.glow(
      thickness: 7,
      angle: 120,
      spread: 0.5,
      intensity: 0.4,
      color: Color(0x55BAE6CE),
    ),
    refractionIndex: 1.045,
    refractionWidth: 14,
    blur: 2.0,
    color: Color(0xBCFFFFFF),
    shadow: LiquidGlassShadow(
      blur: 10,
      opacity: 0.12,
      offset: Offset(0, 4),
      insideGlass: false,
    ),
  );

  /// Botanical emerald liquid glass orb for the primary Scan CTA.
  static const LiquidGlassStyle emeraldActionOrb = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 99),
    specular: LiquidGlassLight.specular(
      thickness: 3.6,
      sharpness: 0.6,
      angle: 39,
      spread: 0.95,
      intensity: 1.25,
      color: Color(0xD9FFFFFF),
    ),
    glow: LiquidGlassLight.glow(
      thickness: 9,
      angle: 125,
      spread: 0.55,
      intensity: 0.65,
      color: Color(0x8834D399),
    ),
    refractionIndex: 1.042,
    refractionWidth: 15,
    blur: 0,
    color: Color(0xDC14803C),
    shadow: LiquidGlassShadow(
      blur: 12,
      opacity: 0.22,
      color: Color(0xFF0E4D24),
      offset: Offset(0, 5),
      insideGlass: false,
    ),
  );

  /// Smoked dark glass style for high-contrast floating camera prompts.
  static const LiquidGlassStyle smokedCameraGlass = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 20),
    specular: LiquidGlassLight.specular(
      thickness: 2.8,
      sharpness: 0.6,
      angle: 39,
      spread: 0.9,
      intensity: 0.9,
      color: Color(0xAAFFFFFF),
    ),
    refractionIndex: 1.025,
    refractionWidth: 14,
    blur: 3.0,
    color: Color(0x8427272A),
  );

  /// Navigation bar capsule shell style.
  static const LiquidGlassStyle navBar = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 31),
    specular: LiquidGlassLight.specular(
      thickness: 3.2,
      sharpness: 0.65,
      angle: 39,
      spread: 0.92,
      intensity: 1.1,
      color: Color(0xEAFFFFFF),
    ),
    glow: LiquidGlassLight.glow(
      thickness: 8,
      angle: 118,
      spread: 0.55,
      intensity: 0.42,
      color: Color(0x55CBEAD5),
    ),
    refractionIndex: 1.028,
    refractionWidth: 16,
    blur: 1.8,
    color: Color(0xBEFFFFFF),
    shadow: LiquidGlassShadow(
      blur: 14,
      opacity: 0.14,
      offset: Offset(0, 6),
      insideGlass: false,
    ),
  );

  /// Nav pill style: morphing refraction during tab drags/taps, clear
  /// emerald-tinted glass cushion at rest without washing out `#14803C` ink.
  static const LiquidGlassTabPillStyle navPill = LiquidGlassTabPillStyle(
    mode: LiquidGlassPillMode.impellerOnly,
    color: Color(0x2414803C),
    blur: 0,
    refractionIndex: 1.022,
    refractionWidth: 18,
    dispersion: 0,
    growHeight: 6,
    growWidth: 10,
    rest: LiquidGlassStyle(
      color: Color(0x2214803C),
      specular: LiquidGlassLight.specular(
        thickness: 2.0,
        sharpness: 0.65,
        angle: 40,
        spread: 0.9,
        intensity: 0.9,
        color: Color(0xD9FFFFFF),
      ),
    ),
    glassStyle: LiquidGlassStyle(
      specular: LiquidGlassLight.specular(
        thickness: 2.6,
        sharpness: 0.65,
        angle: 39,
        spread: 0.95,
        intensity: 1.15,
        color: Color(0xE6FFFFFF),
      ),
      color: Color(0x2814803C),
      refractionIndex: 1.028,
      refractionWidth: 18,
      dispersion: 0,
    ),
  );

  /// Sheet backdrop glass tuned for crisp dark typography (`#111827`).
  static const LiquidGlassStyle lightSheet = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 28),
    specular: LiquidGlassLight.specular(
      thickness: 3.2,
      sharpness: 0.65,
      angle: 42,
      spread: 0.9,
      intensity: 1.0,
      color: Color(0xECFFFFFF),
    ),
    refractionIndex: 1.022,
    refractionWidth: 16,
    blur: 10,
    color: Color(0xE6F7FAF7),
    shadow: LiquidGlassShadow(
      blur: 18,
      opacity: 0.16,
      offset: Offset(0, 6),
      insideGlass: false,
    ),
  );

  /// Primary emerald button inside sheets & dialogs.
  static const LiquidGlassStyle emeraldButton = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 24),
    specular: LiquidGlassLight.specular(
      thickness: 2.8,
      sharpness: 0.65,
      angle: 39,
      spread: 0.9,
      intensity: 1.1,
      color: Color(0xCCFFFFFF),
    ),
    refractionIndex: 1.025,
    refractionWidth: 12,
    blur: 0,
    color: Color(0xEA14803C),
  );

  /// Secondary neutral glass button inside sheets & dialogs.
  static const LiquidGlassStyle neutralButton = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 24),
    specular: LiquidGlassLight.specular(
      thickness: 2.4,
      sharpness: 0.6,
      angle: 39,
      spread: 0.9,
      intensity: 0.95,
      color: Color(0xE6FFFFFF),
    ),
    refractionIndex: 1.015,
    refractionWidth: 10,
    blur: 0,
    color: Color(0xD8E5EBE6),
  );
}

/// Static botanical-mist ambient gradient background placed behind glass surfaces
/// so refracting edges and specular rims visibly catch soft emerald/sky tones.
class NutriVietGlassBackdrop extends StatelessWidget {
  final Widget child;

  const NutriVietGlassBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEEF5F0),
                    Color(0xFFF6F8F5),
                    Color(0xFFEAF1EE),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -70,
                    left: -50,
                    child: _AmbientOrb(
                      size: 270,
                      color: Color(0x66B7E4C7),
                    ),
                  ),
                  Positioned(
                    top: 230,
                    right: -85,
                    child: _AmbientOrb(
                      size: 260,
                      color: Color(0x52D8E6F7),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: -70,
                    child: _AmbientOrb(
                      size: 250,
                      color: Color(0x4DC7E9D4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zero-backdrop frosted card surface for scrollable list content.
///
/// Uses [LiquidGlassLite] with `blur: 0` (avoiding backdrop snapshot copies per
/// list tile) while keeping authentic specular rim light & glass depth.
class NutriVietGlassCard extends StatelessWidget {
  final Widget child;
  final double cornerRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;

  const NutriVietGlassCard({
    super.key,
    required this.child,
    this.cornerRadius = 22,
    this.padding,
    this.color,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cornerRadius);
    final Widget surface = Container(
      decoration: BoxDecoration(
        color: color ?? const Color(0xE8FFFFFF),
        borderRadius: radius,
        border: border ??
            Border.all(
              color: const Color(0xFAFFFFFF),
              width: 1.2,
            ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F2418),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return surface;
    return NutriVietPressScale(
      pressedScale: 0.976,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: surface,
        ),
      ),
    );
  }
}

