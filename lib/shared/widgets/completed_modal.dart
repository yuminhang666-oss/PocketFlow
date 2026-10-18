import 'package:flutter/material.dart';

/// Keep form controllers alive until the route's exit transition has removed
/// its widgets. Navigator.pop returns its result before that transition ends.
Future<T?> showCompletedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  ModalRoute<T>? route;
  final result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialog) {
      route = ModalRoute.of<T>(dialog);
      return builder(dialog);
    },
  );
  await route?.completed;
  return result;
}

Future<T?> showCompletedBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) async {
  ModalRoute<T>? route;
  final result = await showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (sheet) {
      route = ModalRoute.of<T>(sheet);
      return builder(sheet);
    },
  );
  await route?.completed;
  return result;
}
