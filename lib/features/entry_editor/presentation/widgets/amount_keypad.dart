import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.onKey, this.enabled = true});
  final ValueChanged<String> onKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['.', '0', 'backspace'],
      ])
        Row(
          children: [
            for (final key in row)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Semantics(
                    label: key == 'backspace'
                        ? tr(context, "删除一位")
                        : key == '.'
                        ? tr(context, "小数点")
                        : key,
                    button: true,
                    enabled: enabled,
                    onTap: enabled ? () => onKey(key) : null,
                    excludeSemantics: true,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: enabled ? () => onKey(key) : null,
                      child: key == 'backspace'
                          ? const Icon(Icons.backspace_outlined)
                          : Text(key),
                    ),
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}
