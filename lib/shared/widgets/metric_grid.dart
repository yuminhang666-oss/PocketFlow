import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../app/theme/frosted_glass.dart';
import '../../core/domain/money.dart';
import 'amount_text.dart';
import 'entry_tile.dart';
import '../../core/domain/ledger_entry.dart';

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.values});
  final List<(String, Money?)> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (values.isEmpty) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      const gap = 8.0, horizontalPadding = 12.0;
      const preferredSize = 19.0, minimumSize = 16.0;
      final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
      final baseStyle = bodyStyle.copyWith(fontWeight: FontWeight.w600);

      double amountWidth(double size) {
        var widest = 0.0;
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
        );
        final style = baseStyle.copyWith(
          fontSize: size,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        for (final item in values) {
          painter.text = TextSpan(
            text: item.$2 == null
                ? tr(context, "待设置")
                : AmountText(item.$2!).displayText,
            style: style,
          );
          painter.layout();
          if (painter.width > widest) widest = painter.width;
        }
        painter.dispose();
        return widest;
      }

      // Keep a shared type size. Reflow before text becomes too small, and
      // retain system text scaling instead of shrinking the rendered widget.
      var columns = values.length < 3 ? values.length : 3;
      double available(int count) =>
          (box.maxWidth - gap * (count - 1)) / count -
          horizontalPadding * 2 -
          2; // Surface borders and fractional pixel rounding.
      final narrowest = amountWidth(minimumSize);
      while (columns > 1 && narrowest > available(columns)) {
        columns--;
      }
      var size = preferredSize;
      if (amountWidth(size) > available(columns)) {
        var low = minimumSize, high = preferredSize;
        for (var step = 0; step < 7; step++) {
          final middle = (low + high) / 2;
          if (amountWidth(middle) <= available(columns)) {
            low = middle;
          } else {
            high = middle;
          }
        }
        size = low;
      }
      final labelStyle = bodyStyle.copyWith(
        fontSize: 12,
        color: scheme.onSurfaceVariant,
      );
      var labelHeight = 0.0;
      final labelPainter = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      );
      for (final item in values) {
        labelPainter.text = TextSpan(text: item.$1, style: labelStyle);
        labelPainter.layout(
          maxWidth: available(columns).clamp(1, double.infinity),
        );
        if (labelPainter.height > labelHeight) {
          labelHeight = labelPainter.height;
        }
      }
      labelPainter.dispose();
      return Column(
        children: [
          for (var row = 0; row < values.length; row += columns) ...[
            if (row > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var column = 0;
                    column < columns && row + column < values.length;
                    column++
                  ) ...[
                    if (column > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final item = values[row + column];
                          return FrostedSurface(
                            radius: 18,
                            padding: const EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: labelHeight,
                                  ),
                                  child: Text(item.$1, style: labelStyle),
                                ),
                                const SizedBox(height: 6),
                                const Spacer(),
                                if (item.$2 == null)
                                  Text(
                                    tr(context, "待设置"),
                                    style: baseStyle.copyWith(fontSize: size),
                                  )
                                else
                                  AmountText(
                                    item.$2!,
                                    style: baseStyle.copyWith(
                                      fontSize: size,
                                      color:
                                          item.$1.toLowerCase().contains(
                                            tr(context, "净收支").toLowerCase(),
                                          )
                                          ? flowColor(
                                              context,
                                              item.$2!.fen < 0
                                                  ? EntryKind.expense
                                                  : EntryKind.income,
                                              amount: item.$2,
                                            )
                                          : item.$1.toLowerCase().contains(
                                              tr(context, "收入").toLowerCase(),
                                            )
                                          ? flowColor(
                                              context,
                                              EntryKind.income,
                                              amount: item.$2,
                                            )
                                          : item.$1.toLowerCase().contains(
                                              tr(context, "支出").toLowerCase(),
                                            )
                                          ? flowColor(
                                              context,
                                              EntryKind.expense,
                                              amount: item.$2,
                                            )
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
