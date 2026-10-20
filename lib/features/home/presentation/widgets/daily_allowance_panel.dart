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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
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
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
              if (!past)
                Text(
                  future
                      ? tr(context, "整月 {0} 天", [snapshot.remainingDays])
                      : tr(context, "含今天 · 还剩 {0} 天", [snapshot.remainingDays]),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(color: scheme.primary),
                ),
                if (!past)
                  Text(
                    tr(context, "/ 天"),
                    style: TextStyle(color: scheme.primary),
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            past
                ? tr(context, "历史月份 · 全月消费汇总")
                : future
                ? tr(context, "仅用于预算规划")
                : tr(context, "按剩余预算均分，每次记账后更新"),
            style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                snapshot.isOverspent
                    ? tr(context, "本月已超支")
                    : tr(context, "预算余额"),
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
              if (snapshot.remaining != null)
                AmountText(
                  snapshot.isOverspent
                      ? Money.fromFen(snapshot.remaining!.fen.abs())
                      : snapshot.remaining!,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: snapshot.isOverspent
                        ? scheme.error
                        : scheme.onPrimaryContainer,
                  ),
                ),
            ],
          ),
          if (used != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: used.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              color: snapshot.isOverspent ? scheme.error : scheme.primary,
              backgroundColor: scheme.outlineVariant,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                snapshot.budget == null
                    ? tr(context, "设置预算后查看日均参考")
                    : tr(context, "预算 {0} · {1}", [
                        snapshot.budget!.yuan,
                        snapshot.budget!.fen == 0
                            ? tr(context, "本月预算为零")
                            : tr(context, "已用 {0}%", [
                                (used! * 100).toStringAsFixed(0),
                              ]),
                      ]),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              if (snapshot.budget != null && onSetBudget != null)
                TextButton(
                  onPressed: onSetBudget,
                  child: Text(tr(context, "调整预算")),
                ),
            ],
          ),
          if (snapshot.budget == null && onSetBudget != null) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onSetBudget,
              child: Text(tr(context, "设置本月预算")),
            ),
          ],
        ],
      ),
    );
  }
}
