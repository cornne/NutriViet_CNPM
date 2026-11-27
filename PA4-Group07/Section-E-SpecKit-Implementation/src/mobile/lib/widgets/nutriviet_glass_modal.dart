import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'nutriviet_ui.dart';

/// Anchor placement matching `LiquidGlassSheetAnchor` without heavy backdrop readbacks.
enum NutriVietGlassSheetAnchor {
  attached,
  floating,
}

/// Visual variant for lightweight Liquid Glass modal CTA buttons.
enum NutriVietGlassButtonVariant {
  primary,
  neutral,
  danger,
}

/// Presents a translucent Liquid Glass bottom sheet engineered for 120Hz Impeller
/// without multi-tap shader backdrop readbacks or heavyweight overlay meshes.
Future<T?> showNutriVietGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  NutriVietGlassSheetAnchor anchor = NutriVietGlassSheetAnchor.attached,
  bool grabber = true,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  EdgeInsets? margin,
  bool isScrollControlled = true,
  bool avoidKeyboard = true,
  Color barrierColor = const Color(0x520F172A),
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 220),
      reverseDuration: Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (ctx) {
      final Widget sheet = RepaintBoundary(
        child: _NutriVietGlassSheetSurface(
          anchor: anchor,
          grabber: grabber,
          padding: padding,
          margin: margin,
          child: builder(ctx),
        ),
      );
      if (!avoidKeyboard) return sheet;
      return _SheetKeyboardLift(child: sheet);
    },
  );
}

class _SheetKeyboardLift extends StatelessWidget {
  final Widget child;

  const _SheetKeyboardLift({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}

class _NutriVietGlassSheetSurface extends StatelessWidget {
  final NutriVietGlassSheetAnchor anchor;
  final bool grabber;
  final EdgeInsetsGeometry padding;
  final EdgeInsets? margin;
  final Widget child;

  const _NutriVietGlassSheetSurface({
    required this.anchor,
    required this.grabber,
    required this.padding,
    required this.margin,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFloating = anchor == NutriVietGlassSheetAnchor.floating;
    final BorderRadius radius = isFloating
        ? BorderRadius.circular(28)
        : const BorderRadius.vertical(top: Radius.circular(28));
    final EdgeInsets resolvedMargin = margin ??
        (isFloating
            ? EdgeInsets.fromLTRB(
                10,
                0,
                10,
                MediaQuery.paddingOf(context).bottom + 10,
              )
            : EdgeInsets.zero);

    return Padding(
      padding: resolvedMargin,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFAFCFB),
              Color(0xFFF3F8F5),
              Color(0xFFF8FBFA),
            ],
            stops: [0.0, 0.52, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFFFFFFFF),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160F172A),
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TopGlassCatchlight(horizontalMargin: 28),
              if (grabber)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 2),
                    child: Container(
                      width: 38,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0x381F2937),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),
              Flexible(
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Presents a centered Liquid Glass dialog using a snappy 200ms fade+scale
/// transition and isolated inner repaints so text entry stays locked at 120Hz.
Future<T?> showNutriVietGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x580F172A),
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  Duration transitionDuration = const Duration(milliseconds: 200),
}) {
  final CapturedThemes themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: useRootNavigator).context,
  );

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel:
        barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
    useRootNavigator: useRootNavigator,
    transitionDuration: transitionDuration,
    pageBuilder: (buildContext, animation, secondaryAnimation) {
      final Widget dialog = RepaintBoundary(
        child: themes.wrap(builder(buildContext)),
      );
      return _DialogKeyboardLift(
        useSafeArea: useSafeArea,
        child: dialog,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Centered Liquid Glass dialog card with crisp specular rim, dark ink
/// typography, and `RepaintBoundary` isolation around dynamic form fields.
class NutriVietGlassDialog extends StatelessWidget {
  final Widget? icon;
  final Widget? title;
  final TextStyle? titleTextStyle;
  final Widget? content;
  final TextStyle? contentTextStyle;
  final List<Widget>? actions;
  final double width;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const NutriVietGlassDialog({
    super.key,
    this.icon,
    this.title,
    this.titleTextStyle,
    this.content,
    this.contentTextStyle,
    this.actions,
    this.width = 340.0,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 18),
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(28);
    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(child: icon),
          ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DefaultTextStyle(
              style: titleTextStyle ??
                  const TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
              child: title!,
            ),
          ),
        if (content != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: RepaintBoundary(
              child: DefaultTextStyle(
                style: contentTextStyle ??
                    const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                      height: 1.4,
                    ),
                child: content!,
              ),
            ),
          ),
        if (actions != null && actions!.isNotEmpty)
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: 10,
            spacing: 10,
            children: actions!,
          ),
      ],
    );

    if (scrollable) {
      body = SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: body,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFCFEFD),
              Color(0xFFF3F8F5),
              Color(0xFFF8FBFA),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFFFFFFFF),
            width: 1.25,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1C0F172A),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TopGlassCatchlight(horizontalMargin: 24),
              Flexible(
                child: Padding(
                  padding: padding,
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogKeyboardLift extends StatelessWidget {
  final bool useSafeArea;
  final Widget child;

  const _DialogKeyboardLift({
    required this.useSafeArea,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = useSafeArea ? SafeArea(child: child) : child;
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: content,
      ),
    );
  }
}

class _TopGlassCatchlight extends StatelessWidget {
  final double horizontalMargin;

  const _TopGlassCatchlight({required this.horizontalMargin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      height: 1.5,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0xE6FFFFFF),
            Color(0x00FFFFFF),
          ],
        ),
      ),
    );
  }
}

/// Tactile frosted Liquid Glass pill button for popup and dialog actions.
class NutriVietGlassPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final NutriVietGlassButtonVariant variant;
  final double height;
  final double? width;
  final bool isLoading;
  final EdgeInsetsGeometry padding;

  const NutriVietGlassPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NutriVietGlassButtonVariant.primary,
    this.height = 46,
    this.width,
    this.isLoading = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;
    final BorderRadius radius = BorderRadius.circular(height / 2);

    final List<Color> gradientColors;
    final Color borderColor;
    final Color textColor;
    final Color shadowColor;

    switch (variant) {
      case NutriVietGlassButtonVariant.primary:
        gradientColors = const [
          Color(0xFF31A05B),
          Color(0xFF1A8D45),
          Color(0xFF147E3C),
          Color(0xFF106B31),
        ];
        borderColor = const Color(0x70FFFFFF);
        textColor = Colors.white;
        shadowColor = const Color(0x3614803C);
      case NutriVietGlassButtonVariant.danger:
        gradientColors = const [
          Color(0xFFF66969),
          Color(0xFFEF4444),
          Color(0xFFDC2626),
          Color(0xFFC41E1E),
        ];
        borderColor = const Color(0x70FFFFFF);
        textColor = Colors.white;
        shadowColor = const Color(0x36DC2626);
      case NutriVietGlassButtonVariant.neutral:
        gradientColors = const [
          Color(0xFFFAFDFB),
          Color(0xFFF3F7F4),
          Color(0xFFEAF1ED),
          Color(0xFFE2EBE6),
        ];
        borderColor = const Color(0xFFD5E0DA);
        textColor = const Color(0xFF1F2937);
        shadowColor = const Color(0x140F172A);
    }

    Widget button = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: disabled ? 0.62 : 1.0,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
            stops: const [0.0, 0.28, 0.68, 1.0],
          ),
          border: Border.all(color: borderColor, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: padding,
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: textColor,
                    ),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
          ),
        ),
      ),
    );

    if (width == null) {
      button = IntrinsicWidth(child: button);
    }

    return NutriVietPressScale(
      pressedScale: 0.965,
      enableHaptic: !disabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : onPressed,
        child: button,
      ),
    );
  }
}

Color _selectedRowFillColor(Color activeColor) => Color.alphaBlend(
      activeColor.withValues(alpha: 0.085),
      const Color(0xFFF6FAF7),
    );

Color _selectedRowBorderColor(Color activeColor) => Color.alphaBlend(
      activeColor.withValues(alpha: 0.36),
      const Color(0xFFF6FAF7),
    );

/// Isolated 120Hz toggle row with springy custom emerald checkbox and no
/// full-row Material ink flood, avoiding sheet-wide repaints on tick.
class NutriVietGlassCheckRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool checked;
  final VoidCallback onTap;
  final Color activeColor;

  const NutriVietGlassCheckRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onTap,
    this.activeColor = const Color(0xFF14803C),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: checked
                  ? _selectedRowFillColor(activeColor)
                  : const Color(0xFFF6F9F7),
              border: Border.all(
                color: checked
                    ? _selectedRowBorderColor(activeColor)
                    : const Color(0xFFE3EAE5),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOutCubic,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: checked ? activeColor : Colors.white,
                    border: Border.all(
                      color: checked ? activeColor : const Color(0xFF9CA3AF),
                      width: 1.6,
                    ),
                  ),
                  child: checked
                      ? const Center(
                          child: PhosphorIcon(
                            PhosphorIconsBold.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Isolated 120Hz single-choice selection row for modal sheets (e.g. language).
class NutriVietGlassOptionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  const NutriVietGlassOptionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.activeColor = const Color(0xFF14803C),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? _selectedRowFillColor(activeColor)
                  : const Color(0xFFF6F9F7),
              border: Border.all(
                color: selected
                    ? _selectedRowBorderColor(activeColor)
                    : const Color(0xFFE3EAE5),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color:
                              selected ? activeColor : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 12),
                  PhosphorIcon(
                    PhosphorIconsFill.checkCircle,
                    color: activeColor,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

