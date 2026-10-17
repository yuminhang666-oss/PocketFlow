import 'package:flutter/material.dart';

import '../../../../core/domain/budget_snapshot.dart';
import '../../../../app/theme/pocketflow_theme.dart';

class BudgetProgress extends StatelessWidget {
  const BudgetProgress({super.key, required this.snapshot});
  final BudgetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final budget = snapshot.budget;
    if (budget == null) return const SizedBox.shrink();
    if (budget.fen == 0) {
      return const Text('本月预算为零',
          style: TextStyle(color: PocketFlowTheme.onHero));
    }
    // A display ratio only; financial values come directly from the snapshot.
    final ratio = snapshot.spent.fen / budget.fen;
    final percent = (ratio * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '预算已用百分之$percent',
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            minHeight: 5,
            borderRadius: BorderRadius.circular(4),
            color: const Color(0xFFD6E4A7),
            backgroundColor: const Color(0xFF4C6F60),
          ),
        ),
        const SizedBox(height: 8),
        Text('预算已用 $percent%',
            style: const TextStyle(color: PocketFlowTheme.onHero)),
      ],
    );
  }
}
