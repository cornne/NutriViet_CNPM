import 'package:flutter/material.dart';

import '../theme/nutriviet_glass.dart';

/// Shared single-controller shimmer clock driving all descendant
/// [NutriVietShimmerBox] bones in lockstep so skeleton lists never allocate
/// dozens of separate tickers at 120 Hz.
class NutriVietShimmerGroup extends StatefulWidget {
  final Widget child;
  final Duration period;

  const NutriVietShimmerGroup({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1350),
  });

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_NutriVietShimmerScope>()
        ?.progress;
  }

  @override
  State<NutriVietShimmerGroup> createState() => _NutriVietShimmerGroupState();
}

class _NutriVietShimmerGroupState extends State<NutriVietShimmerGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.period,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _NutriVietShimmerScope(
      progress: _controller,
      child: widget.child,
    );
  }
}

class _NutriVietShimmerScope extends InheritedWidget {
  final Animation<double> progress;

  const _NutriVietShimmerScope({
    required this.progress,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _NutriVietShimmerScope oldWidget) {
    return progress != oldWidget.progress;
  }
}

/// GPU-cheap frosted glass shimmer bone with pearl highlight sweep.
///
/// Automatically attaches to an enclosing [NutriVietShimmerGroup] when
/// present, or lazily manages its own controller when rendered standalone.
class NutriVietShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final EdgeInsetsGeometry? margin;

  const NutriVietShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 10,
    this.baseColor,
    this.highlightColor,
    this.margin,
  });

  const NutriVietShimmerBox.circle({
    super.key,
    required double size,
    this.baseColor,
    this.highlightColor,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = 999;

  @override
  State<NutriVietShimmerBox> createState() => _NutriVietShimmerBoxState();
}

class _NutriVietShimmerBoxState extends State<NutriVietShimmerBox>
    with SingleTickerProviderStateMixin {
  AnimationController? _fallbackController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hasGroup = NutriVietShimmerGroup.maybeOf(context) != null;
    if (!hasGroup && _fallbackController == null) {
      _fallbackController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1350),
      )..repeat();
    } else if (hasGroup && _fallbackController != null) {
      _fallbackController!.dispose();
      _fallbackController = null;
    }
  }

  @override
  void dispose() {
    _fallbackController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> anim =
        NutriVietShimmerGroup.maybeOf(context) ?? _fallbackController!;
    final base = widget.baseColor ?? const Color(0x88DCE7E1);
    final mid = (widget.highlightColor ?? Colors.white).withValues(alpha: 0.92);
    final radius = BorderRadius.circular(widget.borderRadius);

    return RepaintBoundary(
      child: Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: anim,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(anim.value);
              final slide = -1.6 + t * 3.2;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment(slide - 0.85, -0.35),
                    end: Alignment(slide + 0.85, 0.35),
                    colors: [
                      base,
                      mid,
                      base,
                    ],
                    stops: const [0.12, 0.50, 0.88],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shimmer skeleton cards matching the Additives / Lookup concept card layout.
class NutriVietConceptListSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const NutriVietConceptListSkeleton({
    super.key,
    this.itemCount = 4,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return NutriVietShimmerGroup(
      child: Padding(
        padding: padding,
        child: Column(
          children: List.generate(itemCount, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
              child: const NutriVietGlassCard(
                cornerRadius: 22,
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            NutriVietShimmerBox(
                              width: 40,
                              height: 40,
                              borderRadius: 12,
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NutriVietShimmerBox(
                                  width: 132,
                                  height: 15,
                                  borderRadius: 8,
                                ),
                                SizedBox(height: 6),
                                NutriVietShimmerBox(
                                  width: 84,
                                  height: 11,
                                  borderRadius: 6,
                                ),
                              ],
                            ),
                          ],
                        ),
                        NutriVietShimmerBox(
                          width: 68,
                          height: 24,
                          borderRadius: 99,
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    NutriVietShimmerBox(
                      height: 12,
                      borderRadius: 6,
                    ),
                    SizedBox(height: 8),
                    NutriVietShimmerBox(
                      width: 210,
                      height: 12,
                      borderRadius: 6,
                    ),
                    SizedBox(height: 12),
                    NutriVietShimmerBox(
                      width: 92,
                      height: 24,
                      borderRadius: 99,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Shimmer skeleton cards matching the History & Recent Scan card layout.
class NutriVietHistoryListSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const NutriVietHistoryListSkeleton({
    super.key,
    this.itemCount = 3,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return NutriVietShimmerGroup(
      child: Padding(
        padding: padding,
        child: Column(
          children: List.generate(itemCount, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
              child: const NutriVietGlassCard(
                cornerRadius: 22,
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        NutriVietShimmerBox.circle(size: 42),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              NutriVietShimmerBox(
                                width: 156,
                                height: 15,
                                borderRadius: 8,
                              ),
                              SizedBox(height: 6),
                              NutriVietShimmerBox(
                                width: 96,
                                height: 11,
                                borderRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        NutriVietShimmerBox(
                          width: 64,
                          height: 26,
                          borderRadius: 99,
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    NutriVietShimmerBox(height: 12, borderRadius: 6),
                    SizedBox(height: 7),
                    NutriVietShimmerBox(
                      width: 220,
                      height: 12,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Shimmer skeleton shown below the Home summary while user profile/history
/// metrics are fetching on initial launch.
class NutriVietHomeStatsSkeleton extends StatelessWidget {
  const NutriVietHomeStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const NutriVietShimmerGroup(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                NutriVietShimmerBox(width: 44, height: 44, borderRadius: 14),
                SizedBox(height: 8),
                NutriVietShimmerBox(width: 48, height: 22, borderRadius: 8),
                SizedBox(height: 6),
                NutriVietShimmerBox(width: 66, height: 11, borderRadius: 6),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                NutriVietShimmerBox(width: 44, height: 44, borderRadius: 14),
                SizedBox(height: 8),
                NutriVietShimmerBox(width: 48, height: 22, borderRadius: 8),
                SizedBox(height: 6),
                NutriVietShimmerBox(width: 66, height: 11, borderRadius: 6),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                NutriVietShimmerBox(width: 44, height: 44, borderRadius: 14),
                SizedBox(height: 8),
                NutriVietShimmerBox(width: 48, height: 22, borderRadius: 8),
                SizedBox(height: 6),
                NutriVietShimmerBox(width: 66, height: 11, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact shimmer rows for live FoodOn ontology lookup inside
/// Allergy Profile.
class NutriVietFoodSearchSkeleton extends StatelessWidget {
  final int itemCount;

  const NutriVietFoodSearchSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return NutriVietShimmerGroup(
      child: Column(
        children: List.generate(itemCount, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
              child: const Row(
                children: [
                  NutriVietShimmerBox(
                    width: 28,
                    height: 28,
                    borderRadius: 9,
                    baseColor: Color(0x88FECACA),
                    highlightColor: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NutriVietShimmerBox(
                          width: 140,
                          height: 13,
                          borderRadius: 6,
                        ),
                        SizedBox(height: 5),
                        NutriVietShimmerBox(
                          width: 96,
                          height: 10,
                          borderRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  NutriVietShimmerBox(
                    width: 62,
                    height: 22,
                    borderRadius: 99,
                    baseColor: Color(0x88FDE68A),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Full-page frosted skeleton matching AllergyProfileScreen sections.
class NutriVietAllergyProfileSkeleton extends StatelessWidget {
  const NutriVietAllergyProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const NutriVietShimmerGroup(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NutriVietGlassCard(
              cornerRadius: 22,
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  NutriVietShimmerBox.circle(size: 46),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NutriVietShimmerBox(
                          width: 148,
                          height: 16,
                          borderRadius: 8,
                        ),
                        SizedBox(height: 8),
                        NutriVietShimmerBox(
                          width: 205,
                          height: 12,
                          borderRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18),
            NutriVietShimmerBox(width: 180, height: 16, borderRadius: 8),
            SizedBox(height: 10),
            NutriVietGlassCard(
              cornerRadius: 22,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NutriVietShimmerBox(height: 46, borderRadius: 14),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      NutriVietShimmerBox(
                          width: 72, height: 30, borderRadius: 99),
                      SizedBox(width: 8),
                      NutriVietShimmerBox(
                          width: 86, height: 30, borderRadius: 99),
                      SizedBox(width: 8),
                      NutriVietShimmerBox(
                          width: 68, height: 30, borderRadius: 99),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      NutriVietShimmerBox(
                          width: 92, height: 30, borderRadius: 99),
                      SizedBox(width: 8),
                      NutriVietShimmerBox(
                          width: 78, height: 30, borderRadius: 99),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 18),
            NutriVietShimmerBox(width: 160, height: 16, borderRadius: 8),
            SizedBox(height: 10),
            NutriVietGlassCard(
              cornerRadius: 22,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: NutriVietShimmerBox(
                          height: 62,
                          borderRadius: 14,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: NutriVietShimmerBox(
                          height: 62,
                          borderRadius: 14,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: NutriVietShimmerBox(
                          height: 62,
                          borderRadius: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  NutriVietShimmerBox(height: 54, borderRadius: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline shimmer pill for loading row summary values (e.g. Settings).
class NutriVietSettingsRowSkeleton extends StatelessWidget {
  final double width;

  const NutriVietSettingsRowSkeleton({super.key, this.width = 92});

  @override
  Widget build(BuildContext context) {
    return NutriVietShimmerBox(
      width: width,
      height: 14,
      borderRadius: 99,
    );
  }
}

