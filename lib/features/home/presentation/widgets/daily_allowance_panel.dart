import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/frosted_glass.dart';
import '../../../../core/domain/budget_snapshot.dart';
import '../../../../core/domain/money.dart';
import '../../../../shared/widgets/amount_text.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final past = snapshot.period == MonthPeriod.past;
    final future = snapshot.period == MonthPeriod.future;
    final amount = past ? snapshot.remaining : snapshot.dailyAllowance;
    final used = snapshot.budget == null || snapshot.budget!.fen == 0
        ? null
        : snapshot.spent.fen / snapshot.budget!.fen;
    return FrostedSurface(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                past
                    ? tr(context, "本月结余")
                    : future
                    ? tr(context, "计划日均")
                    : tr(context, "今起日均参考"),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (amount == null)
            Text(
              tr(context, "待设置预算"),
              style: Theme.of(context).textTheme.headlineSmall,
            )
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                AmountText(
                  amount,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: scheme.primary,
                    fontSize: 42,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!past)
                  Text(
                    tr(context, "/ 天"),
                    style: TextStyle(color: scheme.primary),
                  ),
              ],
            ),
          const SizedBox(height: 2),
          if (!past)
            Text(
              future
                  ? tr(context, "整月 {0} 天", [snapshot.remainingDays])
                  : tr(context, "含今天 · 还剩 {0} 天", [snapshot.remainingDays]),
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: scheme.onPrimaryContainer,
              ),
            ),
          if (past || future)
            Text(past ? tr(context, "历史月份 · 全月消费汇总") : tr(context, "仅用于预算规划")),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(tr(context, snapshot.isOverspent ? "本月已超支" : "预算余额")),
                  if (snapshot.remaining != null)
                    AmountText(
                      Money.fromFen(snapshot.remaining!.fen.abs()),
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: snapshot.isOverspent
                            ? scheme.error
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
              TextButton(
                onPressed: onSetBudget,
                child: Text(
                  tr(context, snapshot.budget == null ? "设置本月预算" : "调整预算"),
                ),
              ),
            ],
          ),
          if (used != null) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: used.clamp(0.0, 1.0),
              minHeight: 4,
              borderRadius: BorderRadius.circular(8),
              color: snapshot.isOverspent ? scheme.error : scheme.primary,
              backgroundColor: scheme.outlineVariant,
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                snapshot.budget == null
                    ? tr(context, "设置预算后查看日均参考")
                    : tr(context, "已支出 {0} / 总预算 {1}", [
                        snapshot.spent.yuan,
                        snapshot.budget!.yuan,
                      ]),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              if (used != null)
                Text(
                  tr(context, "已使用 {0}%", [(used * 100).toStringAsFixed(1)]),
                  style: const TextStyle(fontSize: 12, height: 1.2),
                ),
            ],
          ),
          if (snapshot.budget?.fen == 0 && snapshot.spent.fen == 0)
            Text(tr(context, "本月预算为0"))
          else if (snapshot.remaining?.fen == 0)
            Text(tr(context, "预算已用完")),
        ],
      ),
    );
  }
}
