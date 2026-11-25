import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, PredictiveBackPageTransitionsBuilder;

/// Use the framework's interactive horizontal transition for app pages.
class PocketFlowPageTransitions extends CupertinoPageTransitionsBuilder {
  const PocketFlowPageTransitions();

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

/// Keep the shared glass backdrop steady during the predictive-back route.
class GlassPageTransitions extends PredictiveBackPageTransitionsBuilder {
  const GlassPageTransitions() : super(fallbackColor: Colors.transparent);

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
