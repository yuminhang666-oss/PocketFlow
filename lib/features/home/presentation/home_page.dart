import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/metric_grid.dart';
import 'widgets/home_actions.dart';
import '../../../shared/widgets/presentation_errors.dart';
import '../../../shared/widgets/status_panel.dart';
import 'widgets/daily_allowance_panel.dart';
import '../../reports/domain/range_report_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.month,
    required this.state,
    this.report,
    this.todayKey,
    this.onAddExpense,
    this.onSetBudget,
    this.onOpenLedger,
    this.onEntryTap,
    this.onChooseMonth,
    this.onRefresh,
    this.onCalendar,
    this.onGoals,
    this.onTemplate,
    this.onOpenDate,
    this.onReports,
    this.onPlans,
    this.onCurrentMonth,
    this.onMore,
    this.onIncreaseGoal,
  });
  final CalendarMonth month;
  final AsyncValue<(LedgerMonthData, BudgetSnapshot)> state;
  final MonthlyReport? report;
  final String? todayKey;
  final VoidCallback? onAddExpense,
      onSetBudget,
      onOpenLedger,
      onChooseMonth,
      onCalendar,
      onGoals;
  final ValueChanged<LedgerEntry>? onEntryTap;
  final ValueChanged<EntryTemplate>? onTemplate;
  final ValueChanged<String>? onOpenDate;
  final VoidCallback? onReports, onPlans;
  final VoidCallback? onCurrentMonth, onMore;
  final ValueChanged<SavingsGoal>? onIncreaseGoal;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final content =
        state.asData?.value ?? (state.hasValue ? state.value : null);
    Widget body;
    if (content == null) {
      body = StatusPanel(
        title: state.hasError ? tr(context, "暂时无法读取账本") : tr(context, "正在读取账本"),
        message: state.hasError
            ? tr(context, presentationError(state.error!))
            : null,
        loading: !state.hasError,
        actionLabel: tr(context, "重试"),
        onAction: onRefresh == null
            ? null
            : () {
                onRefresh!();
              },
      );
    } else if (content.$1.month != month || content.$2.month != month) {
      body = StatusPanel(title: tr(context, "月份数据正在更新"), loading: true);
    } else {
      final data = content.$1, snapshot = content.$2;
      final todayExpense =
          report?.daily
              .where((d) => d.localDate == todayKey)
              .firstOrNull
              ?.amount ??
          const Money.fromFen(0);
      final complete =
          data.entries
              .where(
                (e) =>
                    todayKey == null || e.localDate.compareTo(todayKey!) <= 0,
              )
              .toList()
            ..sort((a, b) {
              final day = b.localDate.compareTo(a.localDate);
              if (day != 0) return day;
              final time = b.occurredAtUtcMs.compareTo(a.occurredAtUtcMs);
              return time == 0 ? a.id.compareTo(b.id) : time;
            });
      final totals = {
        for (final d in fullDailyTotals(complete)) d.localDate: d,
      };
      final entries = complete.take(5).toList();
      final goal =
          data.profile.goals
              .where((g) => g.saved.fen < g.target.fen)
              .firstOrNull ??
          data.profile.goals.firstOrNull;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (todayKey != null &&
              month != CalendarMonth.fromDate(parseCalendarDay(todayKey!)))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, "正在查看 {0}", [month.key])),
              trailing: TextButton(
                onPressed: onCurrentMonth,
                child: Text(tr(context, "回到本月")),
              ),
            ),
          if (state.hasError)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(tr(context, "更新失败，当前显示上次结果")),
            ),
          DailyAllowancePanel(snapshot: snapshot, onSetBudget: onSetBudget),
          const SizedBox(height: 8),
          if (snapshot.period != MonthPeriod.future)
            MetricGrid(
              compact: true,
              values: [
                (
                  tr(context, "本月收入"),
                  report?.totalIncome ?? const Money.fromFen(0),
                ),
                (tr(context, "今日支出"), todayExpense),
              ],
            ),
          const SizedBox(height: 8),
          if (goal != null) ...[
            HomeGoal(
              goal: goal,
              goalCount: data.profile.goals.length,
              onGoals: onGoals,
              onIncrease: onIncreaseGoal == null
                  ? null
                  : () => onIncreaseGoal!(goal),
            ),
            const SizedBox(height: 8),
          ],
          HomeActions(
            onCalendar: onCalendar,
            onPlans: onPlans,
            onReports: onReports,
            onMore: onMore,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, "最近账单"),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (onOpenLedger != null)
                TextButton(
                  onPressed: onOpenLedger,
                  child: Text(tr(context, "本月账单")),
                ),
            ],
          ),
          if (entries.isEmpty)
            StatusPanel(
              title: tr(context, "还没有消费记录"),
              message: tr(context, "从一笔支出或收入开始"),
              actionLabel: tr(context, "记第一笔"),
              onAction: onAddExpense,
            )
          else ...[
            for (var i = 0; i < entries.length; i++) ...[
              if (i == 0 || entries[i].localDate != entries[i - 1].localDate)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: InkWell(
                    onTap: onOpenDate == null
                        ? null
                        : () => onOpenDate!(entries[i].localDate),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].localDate == todayKey
                              ? tr(context, "今天")
                              : entries[i].localDate,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          tr(context, "支出 {0} · 收入 {1}", [
                            totals[entries[i].localDate]!.expense.yuan,
                            totals[entries[i].localDate]!.income.yuan,
                          ]),
                        ),
                        if (totals[entries[i].localDate]!.count >
                            entries
                                .where(
                                  (e) => e.localDate == entries[i].localDate,
                                )
                                .length)
                          Text(
                            tr(context, "当日共 {0} 笔，已展示 {1} 笔 · 查看当日账单", [
                              totals[entries[i].localDate]!.count,
                              entries
                                  .where(
                                    (e) => e.localDate == entries[i].localDate,
                                  )
                                  .length,
                            ]),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              EntryTile(
                entry: entries[i],
                categories: data.categories,
                onTap: onEntryTap == null
                    ? null
                    : () => onEntryTap!(entries[i]),
              ),
            ],
          ],
          const SizedBox(height: 14),
          if (report != null)
            Text(
              tr(context, "本月已记录 {0} 天 · {1} 笔", [
                report!.entries.map((e) => e.localDate).toSet().length,
                report!.entries.length,
              ]),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    }
    Widget scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: body,
        ),
      ),
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, child: scroll);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketFlow'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                tr(context, "{0}年{1}月", [month.year, month.month]),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(top: false, child: scroll),
    );
  }
}
