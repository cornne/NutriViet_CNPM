import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Crisp opaque duotone icon badge (squircle or orb) with zero gradient overdraw.
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
    final radius = isCircle ? size / 2 : size * 0.28;
    final tint = fillTint ?? color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Color.alphaBlend(tint.withValues(alpha: 0.11), Colors.white),
        border: Border.all(
          color: Color.alphaBlend(tint.withValues(alpha: 0.22), Colors.white),
          width: 1.05,
        ),
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

/// Lazily mounts each tab on first visit, preserves scroll position and state
/// across switches like [IndexedStack], and drives horizontal glide transitions
/// directly on the GPU compositor via [SlideTransition] with zero Dart rebuilds.
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
  late final CurvedAnimation _curved;
  late Animation<Offset> _slideAnimation;
  late final Set<int> _mountedTabs;

  static const Animation<Offset> _zeroOffset =
      AlwaysStoppedAnimation<Offset>(Offset.zero);

  @override
  void initState() {
    super.initState();
    _mountedTabs = {widget.index};
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1.0,
    );
    _curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slideAnimation = _zeroOffset;
  }

  @override
  void didUpdateWidget(covariant NutriVietTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mountedTabs.add(widget.index);
    if (widget.index != oldWidget.index) {
      final int dir = widget.index > oldWidget.index ? 1 : -1;
      _slideAnimation = Tween<Offset>(
        begin: Offset(0.032 * dir, 0.0),
        end: Offset.zero,
      ).animate(_curved);
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(widget.children.length, (i) {
        if (!_mountedTabs.contains(i)) {
          return SizedBox.shrink(key: ValueKey(i));
        }
        final isActive = i == widget.index;
        return Offstage(
          key: ValueKey(i),
          offstage: !isActive,
          child: TickerMode(
            enabled: isActive,
            child: SlideTransition(
              position: isActive ? _slideAnimation : _zeroOffset,
              child: RepaintBoundary(child: widget.children[i]),
            ),
          ),
        );
      }),
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
        if (t >= 0.999) return child!;
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

/// Interactive Frosted Glass CTA pill with tactile spring press feedback
/// ([NutriVietPressScale]), top specular catchlight, and shimmer loading state.
/// Engineered with zero live backdrop shader readbacks for locked 120 Hz UI.
class NutriVietGlassActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final bool isDanger;
  final double height;
  final double? width;
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
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;
    final Color fg = foregroundColor ??
        (isPrimary || isDanger ? Colors.white : NutriVietGlass.inkPrimary);
    final BorderRadius radius = BorderRadius.circular(height / 2);

    final Color fillColor;
    final Color borderColor;
    if (isDanger) {
      fillColor = const Color(0xFFDC2626);
      borderColor = const Color(0xFFB91C1C);
    } else if (isPrimary) {
      fillColor = const Color(0xFF14803C);
      borderColor = const Color(0xFF0F6B31);
    } else {
      fillColor = const Color(0xFFF2F6F3);
      borderColor = const Color(0xFFD2DED7);
    }

    final Widget inner = isLoading
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
          );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: NutriVietPressScale(
        pressedScale: 0.97,
        enableHaptic: !disabled,
        enabled: !disabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: disabled ? null : onPressed,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: disabled ? 0.65 : 1.0,
            child: Container(
              width: width,
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: radius,
                color: fillColor,
                border: Border.all(color: borderColor, width: 1.05),
              ),
              child: Center(child: inner),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight 120 Hz floating frosted glass AppBar with mathematically centered
/// title regardless of asymmetric leading/trailing actions and zero GPU shader
/// backdrop readbacks.
class NutriVietGlassAppBar extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget> actions;
  final double height;
  final double horizontalPadding;

  const NutriVietGlassAppBar({
    super.key,
    this.leading,
    this.title,
    this.actions = const [],
    this.height = 56,
    this.horizontalPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xF5FFFFFF),
              Color(0xEAF5FAF7),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFDCE7E0),
            width: 1.15,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: DefaultTextStyle.merge(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                    decoration: TextDecoration.none,
                  ),
                  child: title!,
                ),
              ),
            if (leading != null)
              Align(
                alignment: Alignment.centerLeft,
                child: leading!,
              ),
            if (actions.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Circular frosted utility icon button used inside [NutriVietGlassAppBar].
class NutriVietGlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;

  const NutriVietGlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconColor = const Color(0xFF1F2937),
  });

  @override
  Widget build(BuildContext context) {
    return NutriVietPressScale(
      pressedScale: 0.90,
      enableHaptic: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF1F5F3),
            border: Border.all(
              color: const Color(0xFFE2E9E4),
              width: 1.0,
            ),
          ),
          child: Center(
            child: PhosphorIcon(icon, color: iconColor, size: 19),
          ),
        ),
      ),
    );
  }
}

/// Lightweight gradient top/bottom scroll fade edge with zero shader passes.
class NutriVietScrollFadeOverlay extends StatelessWidget {
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final double height;
  final Color color;

  const NutriVietScrollFadeOverlay.top({
    super.key,
    required this.height,
    this.color = const Color(0xE8EEF6F2),
  })  : begin = Alignment.topCenter,
        end = Alignment.bottomCenter;

  const NutriVietScrollFadeOverlay.bottom({
    super.key,
    required this.height,
    this.color = const Color(0xECEAF3EE),
  })  : begin = Alignment.bottomCenter,
        end = Alignment.topCenter;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [
              color,
              color.withValues(alpha: 0.72),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Crisp, zero-readback 120 Hz spring glass toggle switch replacing per-row
/// shader switches inside scrolling lists.
class NutriVietGlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color inactiveColor;

  const NutriVietGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = NutriVietGlass.brandGreen,
    this.inactiveColor = const Color(0xFFD1D5DB),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 31,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: value ? activeColor : inactiveColor,
            border: Border.all(
              color: value
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.65),
              width: 1.0,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 25,
              height: 25,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF3F6F4)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x260F172A),
                    blurRadius: 4,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab descriptor for [NutriVietFloatingBottomBar].
class NutriVietBottomTabItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NutriVietBottomTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Unified, pixel-aligned, zero-shader-readback floating bottom navigation dock
/// pairing the frosted 4-tab capsule and detached emerald scan orb on the exact
/// same horizontal row and single `SafeArea` baseline across every screen size.
class NutriVietFloatingBottomBar extends StatelessWidget {
  final List<NutriVietBottomTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onScanTap;
  final Color selectedColor;
  final Color unselectedColor;

  const NutriVietFloatingBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.onScanTap,
    this.selectedColor = NutriVietGlass.brandGreen,
    this.unselectedColor = const Color(0xFF1F2937),
  });

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    const double barHeight = 62.0;
    const double scanSize = 60.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: NutriVietScrollFadeOverlay.bottom(
                height: bottomInset + 96,
                color: const Color(0xECEAF3EE),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: RepaintBoundary(
                          child: Container(
                            height: barHeight,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(barHeight / 2),
                              color: const Color(0xFFFCFEFD),
                              border: Border.all(
                                color: const Color(0xFFD9E5DE),
                                width: 1.1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x100F172A),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // GPU-friendly isolated sliding pill (avoids LayoutBuilder + Stack relayout)
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: AnimatedAlign(
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutCubic,
                                      alignment: Alignment(
                                        items.length > 1
                                            ? -1.0 +
                                                2.0 *
                                                    selectedIndex /
                                                    (items.length - 1)
                                            : 0.0,
                                        0.0,
                                      ),
                                      child: FractionallySizedBox(
                                        widthFactor: items.isNotEmpty
                                            ? 1.0 / items.length
                                            : 1.0,
                                        heightFactor: 1.0,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              (barHeight - 8) / 2,
                                            ),
                                            color: Color.alphaBlend(
                                              selectedColor.withValues(alpha: 0.12),
                                              Colors.white,
                                            ),
                                            border: Border.all(
                                              color: selectedColor.withValues(
                                                alpha: 0.22,
                                              ),
                                              width: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: List<Widget>.generate(items.length, (i) {
                                    final item = items[i];
                                    final bool active = i == selectedIndex;
                                    final Color fg =
                                        active ? selectedColor : unselectedColor;
                                    return Expanded(
                                      child: Semantics(
                                        button: true,
                                        selected: active,
                                        label: item.label,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            if (selectedIndex != i) {
                                              HapticFeedback.selectionClick();
                                              onChanged(i);
                                            }
                                          },
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                PhosphorIcon(
                                                  active
                                                      ? item.selectedIcon
                                                      : item.icon,
                                                  color: fg,
                                                  size: 21,
                                                ),
                                                const SizedBox(height: 2),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                                  child: Text(
                                                    item.label,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: fg,
                                                      fontSize: 10.5,
                                                      fontWeight: active
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      letterSpacing: -0.1,
                                                      height: 1.15,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      RepaintBoundary(
                        child: Semantics(
                          button: true,
                          label: AppLocale.t('Quét nhãn', 'Scan label'),
                          child: NutriVietPressScale(
                            pressedScale: 0.91,
                            enableHaptic: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onScanTap,
                              child: Container(
                                width: scanSize,
                                height: scanSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF14803C),
                                  border: Border.all(
                                    color: const Color(0xFF0E642D),
                                    width: 1.15,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x2814803C),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: PhosphorIcon(
                                    PhosphorIconsBold.scan,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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


