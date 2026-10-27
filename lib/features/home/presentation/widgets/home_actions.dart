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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
  const HomeGoal({
    super.key,
    this.goal,
    this.goalCount = 1,
    this.onGoals,
    this.onIncrease,
  });
  final SavingsGoal? goal;
  final int goalCount;
  final VoidCallback? onGoals, onIncrease;
  @override
  Widget build(BuildContext context) {
    final g = goal;
    if (g == null) return const SizedBox.shrink();
    return Semantics(
      label: tr(context, '独立登记进度，不扣减生活费预算'),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onGoals,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            goalCount > 1
                                ? tr(context, '我的小目标（{0}）', [goalCount])
                                : tr(context, '我的小目标'),
                            style: const TextStyle(fontSize: 12, height: 1.1),
                          ),
                          Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: onIncrease,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr(context, '增加进度')),
                    ),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                children: [
                  Text(
                    '${g.saved.yuan} / ${g.target.yuan}',
                    style: const TextStyle(fontSize: 12, height: 1.2),
                  ),
                  Text(
                    g.saved.fen >= g.target.fen
                        ? tr(context, '已完成')
                        : '${(g.saved.fen / g.target.fen * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, height: 1.2),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (g.saved.fen / g.target.fen).clamp(0, 1),
                minHeight: 4,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
