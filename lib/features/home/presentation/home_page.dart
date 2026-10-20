import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/metric_grid.dart';
import '../../../shared/widgets/amount_text.dart';
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
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content =
        state.asData?.value ?? (state.hasValue ? state.value : null);
    Widget body;
    if (content == null) {
      body = StatusPanel(
        title: state.hasError ? '暂时无法读取账本' : '正在读取账本',
        message: state.hasError ? presentationError(state.error!) : null,
        loading: !state.hasError,
        actionLabel: '重试',
        onAction: onRefresh == null
            ? null
            : () {
                onRefresh!();
              },
      );
    } else if (content.$1.month != month || content.$2.month != month) {
      body = const StatusPanel(title: '月份数据正在更新', loading: true);
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
      final goal = data.profile.goals.firstOrNull;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.hasError)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('更新失败，当前显示上次结果'),
            ),
          DailyAllowancePanel(snapshot: snapshot, onSetBudget: onSetBudget),
          const SizedBox(height: 12),
          if (snapshot.period != MonthPeriod.future)
            MetricGrid(
              values: [
                ('本月支出', snapshot.spent),
                ('本月收入', report?.totalIncome ?? const Money.fromFen(0)),
                ('今日支出', todayExpense),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (onReports != null)
                TextButton.icon(
                  onPressed: onReports,
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text('周报与月报'),
                ),
              if (onPlans != null)
                TextButton.icon(
                  onPressed: onPlans,
                  icon: const Icon(Icons.event_repeat_outlined),
                  label: const Text('未来7天待办'),
                ),
              if (onCalendar != null)
                TextButton.icon(
                  onPressed: onCalendar,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('记账日历'),
                ),
              if (onGoals != null)
                TextButton.icon(
                  onPressed: onGoals,
                  icon: const Icon(Icons.savings_outlined),
                  label: const Text('我的小目标'),
                ),
            ],
          ),
          if (data.profile.templates.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('常用模板', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: [
                for (final t in data.profile.templates.take(4))
                  ActionChip(
                    avatar: Icon(
                      categoryIcon(t.categoryId, data.categories),
                      size: 18,
                    ),
                    label: Text(t.name),
                    onPressed: onTemplate == null ? null : () => onTemplate!(t),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '最近记录',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (onOpenLedger != null)
                TextButton(onPressed: onOpenLedger, child: const Text('查看全部')),
            ],
          ),
          if (entries.isEmpty)
            StatusPanel(
              title: '还没有消费记录',
              message: '从一笔支出或收入开始',
              actionLabel: '记第一笔',
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
                              ? '今天'
                              : entries[i].localDate,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '支出 ${totals[entries[i].localDate]!.expense.yuan} · 收入 ${totals[entries[i].localDate]!.income.yuan}',
                        ),
                        if (totals[entries[i].localDate]!.count >
                            entries
                                .where(
                                  (e) => e.localDate == entries[i].localDate,
                                )
                                .length)
                          Text(
                            '当日共 ${totals[entries[i].localDate]!.count} 笔，已展示 ${entries.where((e) => e.localDate == entries[i].localDate).length} 笔 · 查看当日账单',
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
          if (goal != null) ...[
            const SizedBox(height: 18),
            InkWell(
              onTap: onGoals,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      goal.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (goal.saved.fen / goal.target.fen).clamp(0.0, 1.0),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFB67A00),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        AmountText(
                          goal.saved,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('/ 目标 ${goal.target.yuan}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '独立登记进度，不扣减生活费预算',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (report != null)
            Text(
              '本月已记录 ${report!.entries.map((e) => e.localDate).toSet().length} 天 · ${report!.entries.length} 笔',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
          TextButton(
            onPressed: onChooseMonth,
            child: Text('${month.year}年${month.month}月 ▾'),
          ),
        ],
      ),
      body: SafeArea(top: false, child: scroll),
    );
  }
}
