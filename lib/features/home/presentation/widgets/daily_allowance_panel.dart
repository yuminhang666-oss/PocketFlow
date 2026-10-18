import 'package:flutter/material.dart';
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
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
                    ? '本月结余'
                    : future
                    ? '计划日均'
                    : '今起日均参考',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
              if (!past)
                Text(
                  future
                      ? '整月 ${snapshot.remainingDays} 天'
                      : '含今天 · 还剩 ${snapshot.remainingDays} 天',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (amount == null)
            Text('待设置预算', style: Theme.of(context).textTheme.headlineSmall)
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
                if (!past) Text('/ 天', style: TextStyle(color: scheme.primary)),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            past
                ? '历史月份 · 全月消费汇总'
                : future
                ? '仅用于预算规划'
                : '按剩余预算均分，每次记账后更新',
            style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                snapshot.isOverspent ? '本月已超支' : '预算余额',
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
          Text(
            snapshot.budget == null
                ? '设置预算后查看日均参考'
                : '预算 ${snapshot.budget!.yuan} · ${snapshot.budget!.fen == 0 ? '本月预算为零' : '已用 ${(used! * 100).toStringAsFixed(0)}%'}',
            style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
          ),
          if (snapshot.budget == null && onSetBudget != null) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: onSetBudget, child: const Text('设置本月预算')),
          ],
          if (snapshot.budget != null && onSetBudget != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSetBudget,
                child: const Text('调整预算'),
              ),
            ),
        ],
      ),
    );
  }
}
