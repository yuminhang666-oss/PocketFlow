import 'package:flutter/material.dart';
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
      final width = (box.maxWidth - (columns - 1) * 8) / columns;
      final scheme = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in values)
            Container(
              width: width,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (item.$2 == null)
                    const Text('待设置')
                  else
                    AmountText(
                      item.$2!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: item.$1.contains('收入')
                            ? scheme.primary
                            : scheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
