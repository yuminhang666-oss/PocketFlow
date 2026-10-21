import 'package:flutter/material.dart';

/// Keep Android's predictive back and its standard fallback. Glass routes share
/// one backdrop above the Navigator, so the fallback must not paint over it.
class PocketFlowPageTransitions extends PredictiveBackPageTransitionsBuilder {
  const PocketFlowPageTransitions({super.fallbackColor});

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return super.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
