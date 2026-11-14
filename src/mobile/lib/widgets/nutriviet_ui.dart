import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../theme/nutriviet_glass.dart';
import 'nutriviet_shimmer.dart';

/// Tactile 120 Hz spring press feedback wrapper that preserves vertical ListView
/// drags by releasing its pressed scale immediately if the pointer moves > 12px.
class NutriVietPressScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final bool enableHaptic;
  final bool enabled;

  const NutriVietPressScale({
    super.key,
    required this.child,
    this.pressedScale = 0.968,
    this.enableHaptic = false,
    this.enabled = true,
  });

  @override
  State<NutriVietPressScale> createState() => _NutriVietPressScaleState();
}

class _NutriVietPressScaleState extends State<NutriVietPressScale> {
  bool _pressed = false;
  Offset? _downPosition;
  Timer? _pressDelay;

  void _release() {
    _pressDelay?.cancel();
    _pressDelay = null;
    _downPosition = null;
    if (_pressed && mounted) {
      setState(() => _pressed = false);
    }
  }

  @override
  void dispose() {
    _pressDelay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _downPosition = e.position;
        _pressDelay?.cancel();
        // Wait past initial scroll-slop (~45ms) so vertical ListView flings
        // never scale cards down mid-scroll.
        _pressDelay = Timer(const Duration(milliseconds: 45), () {
          if (mounted && _downPosition != null && !_pressed) {
            setState(() => _pressed = true);
          }
        });
      },
      onPointerMove: (e) {
        if (_downPosition != null &&
            (e.position - _downPosition!).distance > 10.0) {
          _release();
        }
      },
      onPointerUp: (_) {
        if (_downPosition != null && widget.enableHaptic) {
          HapticFeedback.selectionClick();
        }
        _release();
      },
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 95)
            : const Duration(milliseconds: 240),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Layered Liquid-Glass duotone icon badge (iOS 26 / modern squircle or orb tile).
class NutriVietGlassIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool isCircle;
  final double? iconSize;
  final double secondaryOpacity;
  final Color? fillTint;

  const NutriVietGlassIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.isCircle = false,
    this.iconSize,
    this.secondaryOpacity = 0.26,
    this.fillTint,
  });

  @override
  Widget build(BuildContext context) {
    final radius = isCircle ? size / 2 : size * 0.30;
    final tint = fillTint ?? color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.72),
            tint.withValues(alpha: 0.19),
            tint.withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.36, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: PhosphorIcon(
          icon,
          color: color,
          size: iconSize ?? size * 0.54,
          duotoneSecondaryOpacity: secondaryOpacity,
          duotoneSecondaryColor: color,
        ),
      ),
    );
  }
}

/// Subtle breathing glow ring used behind unlocked medals & active hero badges.
class NutriVietPulseHalo extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double size;
  final bool active;

  const NutriVietPulseHalo({
    super.key,
    required this.child,
    required this.glowColor,
    required this.size,
    this.active = true,
  });

  @override
  State<NutriVietPulseHalo> createState() => _NutriVietPulseHaloState();
}

class _NutriVietPulseHaloState extends State<NutriVietPulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: widget.active ? 1.0 : 0.0,
    );
    if (widget.active) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant NutriVietPulseHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _ctrl.forward(from: 0.0);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final pulse = math.sin(_ctrl.value * math.pi);
          final alpha = 0.16 + 0.14 * pulse;
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: alpha),
                  blurRadius: 12 + 5 * pulse,
                  spreadRadius: 1.5 + 1.5 * pulse,
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Preserves scroll position and state across tabs like [IndexedStack] while
/// delivering smooth directional fade + horizontal glide transitions at 120 Hz.
class NutriVietTabView extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const NutriVietTabView({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<NutriVietTabView> createState() => _NutriVietTabViewState();
}

class _NutriVietTabViewState extends State<NutriVietTabView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant NutriVietTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(widget.children.length, (i) {
        final isActive = i == widget.index;
        return Offstage(
          key: ValueKey(i),
          offstage: !isActive,
          child: TickerMode(
            enabled: isActive,
            child: AnimatedBuilder(
              animation: _ctrl,
              child: RepaintBoundary(child: widget.children[i]),
              builder: (context, repaintedChild) {
                if (!isActive || _ctrl.isCompleted) return repaintedChild!;
                final t = Curves.easeOutCubic.transform(_ctrl.value);
                final dx = (1.0 - t) * 14.0 * _direction;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: repaintedChild,
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

/// Diagonal specular light sweep rendered quietly inside the Hero glass card.
class NutriVietHeroSheen extends StatefulWidget {
  const NutriVietHeroSheen({super.key});

  @override
  State<NutriVietHeroSheen> createState() => _NutriVietHeroSheenState();
}

class _NutriVietHeroSheenState extends State<NutriVietHeroSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final raw = _ctrl.value;
                final sweep = Curves.easeInOutSine.transform(raw);
                final alignmentX = -1.7 + sweep * 3.4;
                final alpha = raw > 0.0 && raw < 1.0
                    ? math.sin(raw * math.pi) * 0.16
                    : 0.0;
                if (alpha <= 0.001) return const SizedBox.shrink();
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(alignmentX - 0.55, -1.0),
                      end: Alignment(alignmentX + 0.55, 1.0),
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: alpha),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One-shot GPU-friendly entrance motion for non-huge lists & empty states.
class NutriVietEntranceMotion extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final double offsetY;

  const NutriVietEntranceMotion({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offsetY = 14,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = 260 + delayMs.clamp(0, 240);
    final delayFrac = delayMs == 0 ? 0.0 : (delayMs / totalMs).clamp(0.0, 0.55);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayFrac, 1.0, curve: Curves.easeOutCubic),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - t) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Shared modern duotone/filled semantic risk badge across Home, Additives & History.
class NutriVietRiskPill extends StatelessWidget {
  final String riskLevel;
  final String? customLabel;

  const NutriVietRiskPill({
    super.key,
    required this.riskLevel,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final level = riskLevel.toLowerCase();
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;

    if (level == 'high' || level == 'red') {
      bg = const Color(0xFFDC2626);
      fg = Colors.white;
      icon = PhosphorIconsFill.warningOctagon;
      label = customLabel ?? AppLocale.t('Nguy cơ cao', 'High risk');
    } else if (level == 'safe' || level == 'green') {
      bg = const Color(0xFF14803C);
      fg = Colors.white;
      icon = PhosphorIconsFill.shieldCheck;
      label = customLabel ?? AppLocale.t('An toàn', 'Safe');
    } else {
      bg = const Color(0xFFF5C518);
      fg = const Color(0xFF1F2937);
      icon = PhosphorIconsFill.warning;
      label = customLabel ?? AppLocale.t('Nguy cơ thấp', 'Low risk');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated corner viewfinder & emerald laser beam sweeping at 120 Hz over
/// the active ingredient card in [_PackagingScannerScreen].
class NutriVietScannerReticle extends StatefulWidget {
  final bool isScanning;

  const NutriVietScannerReticle({super.key, required this.isScanning});

  @override
  State<NutriVietScannerReticle> createState() =>
      _NutriVietScannerReticleState();
}

class _NutriVietScannerReticleState extends State<NutriVietScannerReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant NutriVietScannerReticle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      _ctrl.duration = Duration(
        milliseconds: widget.isScanning ? 950 : 2200,
      );
      if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = Curves.easeInOutSine.transform(_ctrl.value);
            final breatheScale =
                widget.isScanning ? 1.0 : (0.992 + 0.016 * math.sin(t * math.pi));
            return Transform.scale(
              scale: breatheScale,
              child: CustomPaint(
                painter: _ScannerReticlePainter(
                  progress: t,
                  isScanning: widget.isScanning,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScannerReticlePainter extends CustomPainter {
  final double progress;
  final bool isScanning;

  const _ScannerReticlePainter({
    required this.progress,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 24.0;
    const cornerRadius = 18.0;
    final strokePaint = Paint()
      ..color = isScanning
          ? const Color(0xFF34D399)
          : Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      // Top-left
      ..moveTo(0, cornerLen)
      ..lineTo(0, cornerRadius)
      ..quadraticBezierTo(0, 0, cornerRadius, 0)
      ..lineTo(cornerLen, 0)
      // Top-right
      ..moveTo(w - cornerLen, 0)
      ..lineTo(w - cornerRadius, 0)
      ..quadraticBezierTo(w, 0, w, cornerRadius)
      ..lineTo(w, cornerLen)
      // Bottom-right
      ..moveTo(w, h - cornerLen)
      ..lineTo(w, h - cornerRadius)
      ..quadraticBezierTo(w, h, w - cornerRadius, h)
      ..lineTo(w - cornerLen, h)
      // Bottom-left
      ..moveTo(cornerLen, h)
      ..lineTo(cornerRadius, h)
      ..quadraticBezierTo(0, h, 0, h - cornerRadius)
      ..lineTo(0, h - cornerLen);

    canvas.drawPath(path, strokePaint);

    // Sweeping emerald laser line
    final beamY = 14.0 + (h - 28.0) * progress;
    final beamRect = Rect.fromLTWH(10, beamY - 12, w - 20, 24);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF34D399).withValues(alpha: 0.0),
          const Color(0xFF34D399).withValues(alpha: isScanning ? 0.50 : 0.28),
          const Color(0xFF34D399).withValues(alpha: 0.0),
        ],
      ).createShader(beamRect);
    canvas.drawRect(beamRect, glowPaint);

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF34D399).withValues(alpha: 0.0),
          const Color(0xFF6EE7B7),
          const Color(0xFF34D399).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(12, beamY - 1, w - 24, 2))
      ..strokeWidth = isScanning ? 2.4 : 1.6;
    canvas.drawLine(
      Offset(12, beamY),
      Offset(w - 12, beamY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerReticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isScanning != isScanning;
}

/// Interactive Liquid Glass CTA pill built over [LiquidGlassButton] with
/// soft-body finger flex ([LiquidGlassTouch.flexing]) and a frosted pearl
/// shimmer sweep during async operations instead of a bare spinner.
class NutriVietGlassActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final bool isDanger;
  final double height;
  final double? width;
  final LiquidGlassStyle? style;
  final Color? foregroundColor;

  const NutriVietGlassActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.isDanger = false,
    this.height = 50,
    this.width,
    this.style,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ??
        (isDanger
            ? NutriVietGlass.dangerButton
            : (isPrimary
                ? NutriVietGlass.emeraldButton
                : NutriVietGlass.neutralButton));
    final fg = foregroundColor ??
        (isPrimary || isDanger ? Colors.white : NutriVietGlass.inkPrimary);

    return LiquidGlassButton(
      width: width,
      height: height,
      style: effectiveStyle,
      touch: NutriVietGlass.touchHorizontalCapsule,
      foregroundColor: fg,
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                NutriVietShimmerBox.circle(
                  size: 16,
                  baseColor: fg.withValues(alpha: 0.28),
                  highlightColor: Colors.white,
                ),
                const SizedBox(width: 10),
                NutriVietShimmerBox(
                  width: 88,
                  height: 12,
                  borderRadius: 6,
                  baseColor: fg.withValues(alpha: 0.30),
                  highlightColor: Colors.white,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  PhosphorIcon(icon!, size: 19, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Morphing Liquid Glass surface powered by [LiquidGlassMorph] — smoothly
/// stretches and reforms its glass capsule whenever its keyed child state flips
/// (e.g. collapsed summary ↔ expanded detail card).
class NutriVietGlassMorphCard extends StatelessWidget {
  final Widget child;
  final LiquidGlassMorphMotion motion;
  final LiquidGlassStyle? style;
  final Alignment alignment;
  final double smoothness;
  final double? width;
  final LiquidGlassTouch? touch;

  const NutriVietGlassMorphCard({
    super.key,
    required this.child,
    this.motion = LiquidGlassMorphMotion.calm,
    this.style,
    this.alignment = Alignment.topCenter,
    this.smoothness = 26,
    this.width,
    this.touch,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassMorph(
      width: width,
      alignment: alignment,
      motion: motion,
      smoothness: smoothness,
      touch: touch,
      style: style ?? NutriVietGlass.cardGlass(cornerRadius: 22),
      child: child,
    );
  }
}

/// Horizontal [SingleChildScrollView] that smoothly fades overflowing left/right
/// edges into transparency instead of hard-clipping items at viewport bounds.
class NutriVietHorizontalFadeScroll extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double fadeExtent;
  final ScrollPhysics physics;

  const NutriVietHorizontalFadeScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.fadeExtent = 46.0,
    this.physics = const BouncingScrollPhysics(),
  });

  @override
  State<NutriVietHorizontalFadeScroll> createState() =>
      _NutriVietHorizontalFadeScrollState();
}

class _NutriVietHorizontalFadeScrollState
    extends State<NutriVietHorizontalFadeScroll> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<(double, double)> _edgeFade =
      ValueNotifier<(double, double)>((0.0, 0.0));
  bool _syncQueued = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncFromController);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant NutriVietHorizontalFadeScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncQueued) return;
    _syncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      _syncFromController();
    });
  }

  void _syncFromController() {
    if (!mounted || !_scrollController.hasClients) return;
    final ScrollPosition pos = _scrollController.position;
    if (!pos.hasContentDimensions) return;
    final double max = pos.maxScrollExtent;
    if (max <= 0.5) {
      _edgeFade.value = (0.0, 0.0);
      return;
    }
    final double left = (pos.pixels / 18.0).clamp(0.0, 1.0);
    final double right = ((max - pos.pixels) / 18.0).clamp(0.0, 1.0);
    _edgeFade.value = (left, right);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncFromController);
    _scrollController.dispose();
    _edgeFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget scrollView = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleSync();
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: widget.physics,
        padding: widget.padding,
        child: widget.child,
      ),
    );

    return RepaintBoundary(
      child: ValueListenableBuilder<(double, double)>(
        valueListenable: _edgeFade,
        child: scrollView,
        builder: (context, edges, child) {
          final double left = edges.$1;
          final double right = edges.$2;
          if (left <= 0.001 && right <= 0.001) {
            return child!;
          }
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              final double w = bounds.width <= 0 ? 1.0 : bounds.width;
              final double f = (widget.fadeExtent / w).clamp(0.04, 0.28);
              final List<Color> colors = <Color>[];
              final List<double> stops = <double>[];

              if (left > 0.001) {
                colors.addAll([
                  Color.fromRGBO(255, 255, 255, 1.0 - left),
                  Color.fromRGBO(255, 255, 255, 1.0 - left * 0.52),
                  Colors.white,
                ]);
                stops.addAll([0.0, f * 0.45, f]);
              } else {
                colors.add(Colors.white);
                stops.add(0.0);
              }

              if (right > 0.001) {
                colors.addAll([
                  Colors.white,
                  Color.fromRGBO(255, 255, 255, 1.0 - right * 0.52),
                  Color.fromRGBO(255, 255, 255, 1.0 - right),
                ]);
                stops.addAll([1.0 - f, 1.0 - f * 0.45, 1.0]);
              } else {
                colors.add(Colors.white);
                stops.add(1.0);
              }

              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors,
                stops: stops,
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}


