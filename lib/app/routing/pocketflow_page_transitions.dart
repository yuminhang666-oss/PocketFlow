import 'package:flutter/cupertino.dart';

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
