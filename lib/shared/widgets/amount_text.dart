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
      label:
          '${prefix.startsWith('−')
              ? '支出'
              : prefix.startsWith('+')
              ? '收入'
              : ''}${amount.decimal} 元',
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
