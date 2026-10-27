import 'package:flutter/material.dart';
import 'package:pocketflow/l10n/app_strings.dart';
import '../../../../contracts/contracts.dart';

class HomeActions extends StatelessWidget {
  const HomeActions({
    super.key,
    this.onCalendar,
    this.onPlans,
    this.onReports,
    this.onMore,
  });
  final VoidCallback? onCalendar, onPlans, onReports, onMore;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(String label, IconData icon, VoidCallback? action) => Expanded(
      child: InkWell(
        onTap: action,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(tr(context, label))),
            ],
          ),
        ),
      ),
    );
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                item('记账日历', Icons.calendar_month_outlined, onCalendar),
                const VerticalDivider(width: 1),
                item('周期计划', Icons.event_repeat_outlined, onPlans),
              ],
            ),
          ),
          const Divider(height: 1),
          IntrinsicHeight(
            child: Row(
              children: [
                item('周报月报', Icons.summarize_outlined, onReports),
                const VerticalDivider(width: 1),
                item('更多', Icons.grid_view_outlined, onMore),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeGoal extends StatelessWidget {
  const HomeGoal({super.key, this.goal, this.onGoals, this.onIncrease});
  final SavingsGoal? goal;
  final VoidCallback? onGoals, onIncrease;
  @override
  Widget build(BuildContext context) {
    final g = goal, scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: onGoals,
                  child: Text(tr(context, '我的小目标')),
                ),
                if (g != null)
                  FilledButton.tonal(
                    onPressed: onIncrease,
                    child: Text(tr(context, '增加进度')),
                  ),
              ],
            ),
            if (g == null) ...[
              Text(tr(context, '还没有目标，可以从一个小计划开始。')),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onGoals,
                  icon: const Icon(Icons.add),
                  label: Text(tr(context, '新建目标')),
                ),
              ),
            ] else ...[
              Text(g.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (g.saved.fen / g.target.fen).clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('${g.saved.yuan} / ${g.target.yuan}'),
                  Text(
                    g.saved.fen >= g.target.fen
                        ? tr(context, '已完成')
                        : '${(g.saved.fen / g.target.fen * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
              Text(
                tr(context, '独立登记进度，不扣减生活费预算'),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
