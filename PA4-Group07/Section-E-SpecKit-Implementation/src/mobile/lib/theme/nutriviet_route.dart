import 'package:flutter/material.dart';

/// Zero-`saveLayer` GPU-only page route engineered for locked 120 Hz Android/iOS
/// transitions.
///
/// Material 3's [ZoomPageTransitionsBuilder] and full-screen [FadeTransition]
/// routes allocate an offscreen RGBA render pass (`saveLayer`) across the
/// entire viewport on every animation frame, pushing raster times to 16–26ms
/// on high-DPI Android displays. A pure opaque [SlideTransition] composites
/// strictly via a 2D GPU translation transform with zero offscreen passes.
class NutriVietPageRoute<T> extends PageRouteBuilder<T> {
  NutriVietPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog = false,
    super.maintainState = true,
  }) : super(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 190),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildTransition,
        );

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final incomingCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final outgoingCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final Widget isolated = RepaintBoundary(child: child);
    final Widget incoming = SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(incomingCurve),
      child: isolated,
    );

    if (secondaryAnimation.status == AnimationStatus.dismissed) {
      return incoming;
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.18, 0.0),
      ).animate(outgoingCurve),
      child: incoming,
    );
  }
}

/// Global [PageTransitionsBuilder] matching [NutriVietPageRoute] so any
/// implicit Material route also avoids full-screen `saveLayer` passes.
class NutriVietPageTransitionsBuilder extends PageTransitionsBuilder {
  const NutriVietPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return NutriVietPageRoute._buildTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
