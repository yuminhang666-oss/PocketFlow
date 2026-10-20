import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../core/domain/money.dart';

/// Full precision remains visible at large text scales; never ellipsize money.
class AmountText extends StatelessWidget {
  const AmountText(this.amount, {super.key, this.style, this.prefix = '¥'});

  final Money amount;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final parts = amount.decimal.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return Semantics(
      label: tr(context, "{0}{1} 元", [
        prefix.startsWith('−')
            ? tr(context, "支出")
            : prefix.startsWith('+')
            ? tr(context, "收入")
            : '',
        amount.decimal,
      ]),
      excludeSemantics: true,
      child: Text(
        '$prefix$whole.${parts[1]}',
        softWrap: true,
        style: (style ?? Theme.of(context).textTheme.titleLarge)?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
