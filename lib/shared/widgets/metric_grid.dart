import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../app/theme/frosted_glass.dart';
import '../../core/domain/money.dart';
import 'amount_text.dart';

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.values});
  final List<(String, Money?)> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final long = values.any((v) => (v.$2?.decimal.length ?? 0) > 10);
      final columns = scale > 1.5
          ? 1
          : long || box.maxWidth < 290
          ? 2
          : 3;
      final scheme = Theme.of(context).colorScheme;
      return Column(
        children: [
          for (var row = 0; row < values.length; row += columns) ...[
            if (row > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 8),
                    Expanded(
                      child: row + column >= values.length
                          ? const SizedBox.shrink()
                          : Builder(
                              builder: (context) {
                                final item = values[row + column];
                                return FrostedSurface(
                                  radius: 18,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.$1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Spacer(),
                                      if (item.$2 == null)
                                        Text(tr(context, "待设置"))
                                      else
                                        AmountText(
                                          item.$2!,
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                item.$1.contains(
                                                  tr(context, "收入"),
                                                )
                                                ? scheme.primary
                                                : scheme.onSurface,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
