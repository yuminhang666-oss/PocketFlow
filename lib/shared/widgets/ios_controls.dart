import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IosPressable extends StatefulWidget {
  const IosPressable({
    super.key,
    required this.child,
    this.onPressed,
    this.haptics = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool haptics;

  @override
  State<IosPressable> createState() => _IosPressableState();
}

class _IosPressableState extends State<IosPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.onPressed;
    final animation = !MediaQuery.disableAnimationsOf(context);
    return InkWell(
      onTap: action == null
          ? null
          : () {
              if (widget.haptics) HapticFeedback.selectionClick();
              action();
            },
      onHighlightChanged: action == null
          ? null
          : (pressed) => setState(() => _pressed = pressed),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: AnimatedScale(
        duration: animation ? const Duration(milliseconds: 100) : Duration.zero,
        scale: animation && _pressed ? .96 : 1,
        child: widget.child,
      ),
    );
  }
}

class IosSegmentedControl<T extends Object> extends StatelessWidget {
  const IosSegmentedControl({
    super.key,
    required this.labels,
    required this.value,
    this.onChanged,
  });

  final Map<T, String> labels;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final select = onChanged;
    return LayoutBuilder(
      builder: (context, size) {
        if (select == null ||
            size.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 18 ||
            MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.highContrastOf(context)) {
          return Wrap(
            spacing: 8,
            children: [
              for (final item in labels.entries)
                ChoiceChip(
                  label: Text(item.value),
                  selected: value == item.key,
                  onSelected: select == null ? null : (_) => select(item.key),
                ),
            ],
          );
        }
        return CupertinoSlidingSegmentedControl<T>(
          backgroundColor: scheme.surfaceContainerHighest,
          thumbColor: scheme.surface,
          groupValue: value,
          children: {
            for (final item in labels.entries)
              item.key: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  item.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurface),
                ),
              ),
          },
          onValueChanged: (value) {
            if (value != null) select(value);
          },
        );
      },
    );
  }
}
