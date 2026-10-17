import 'package:flutter/material.dart';

import '../../../../app/theme/pocketflow_theme.dart';
import '../../../../core/domain/budget_snapshot.dart';
import '../../../../core/domain/money.dart';
import '../../../../shared/widgets/amount_text.dart';
import 'budget_progress.dart';

class DailyAllowancePanel extends StatelessWidget {
  const DailyAllowancePanel({
    super.key,
    required this.snapshot,
    this.onSetBudget,
  });

  final BudgetSnapshot snapshot;
  final VoidCallback? onSetBudget;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final past = snapshot.period == MonthPeriod.past;
    final future = snapshot.period == MonthPeriod.future;
    final title = past
        ? (snapshot.isOverspent ? '本月已超支' : '本月结余')
        : future
        ? '计划日均'
        : '从今天起 · 每日可支配';
    final featured = past ? snapshot.remaining : snapshot.dailyAllowance;
    final mainAmount = past && featured != null && featured.fen < 0
        ? Money.fromFen(featured.fen.abs())
        : featured;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? PocketFlowTheme.heroDark
            : PocketFlowTheme.heroLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: PocketFlowTheme.onHero),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: text.bodyMedium?.copyWith(color: PocketFlowTheme.onHero),
            ),
            const SizedBox(height: 12),
            if (mainAmount == null)
              Text(
                '待设置预算',
                style: text.headlineSmall?.copyWith(
                  color: PocketFlowTheme.onHero,
                ),
              )
            else
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  AmountText(
                    mainAmount,
                    style: text.headlineLarge?.copyWith(
                      color: PocketFlowTheme.onHero,
                    ),
                  ),
                  if (!past)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('/ 天'),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              past
                  ? '历史月份 · 全月消费汇总'
                  : future
                  ? '按整月 ${snapshot.remainingDays} 天规划'
                  : '包含今天，距离月底还有 ${snapshot.remainingDays} 天',
            ),
            if (snapshot.budget == null) ...[
              const SizedBox(height: 12),
              const Text('设置生活费预算后，即可查看每日参考额度'),
              if (onSetBudget != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PocketFlowTheme.onHero,
                    foregroundColor: PocketFlowTheme.heroLight,
                  ),
                  onPressed: onSetBudget,
                  child: const Text('设置本月预算'),
                ),
              ],
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Color(0xFF4C6F60)),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 290 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final metrics = [
                  _Metric(label: '本月预算', amount: snapshot.budget),
                  _Metric(label: '本月已支出', amount: snapshot.spent),
                  _Metric(
                    label: snapshot.isOverspent ? '已超支' : '剩余预算',
                    amount: snapshot.isOverspent
                        ? Money.fromFen(snapshot.remaining!.fen.abs())
                        : snapshot.remaining,
                  ),
                ];
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final metric in metrics)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: metric,
                        ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final metric in metrics) Expanded(child: metric),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            BudgetProgress(snapshot: snapshot),
            if (snapshot.isOverspent) ...[
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: PocketFlowTheme.onHero,
                  ),
                  Text('本月已超支，仍可如实记录消费'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.amount});
  final String label;
  final Money? amount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 6),
      if (amount == null)
        const Text('待设置')
      else
        AmountText(
          amount!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: PocketFlowTheme.onHero,
            fontWeight: FontWeight.w600,
          ),
        ),
    ],
  );
}
