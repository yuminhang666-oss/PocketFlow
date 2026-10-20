import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/metric_grid.dart';
import '../../../shared/widgets/presentation_errors.dart';
import '../../../shared/widgets/status_panel.dart';
import '../domain/monthly_report_service.dart';
import 'fl_chart_widgets.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.month,
    required this.state,
    required this.clock,
    this.onChooseMonth,
    this.onOpenCategory,
    this.onOpenDate,
    this.onReports,
  });
  final CalendarMonth month;
  final AsyncValue<LedgerMonthData> state;
  final Clock clock;
  final VoidCallback? onChooseMonth;
  final VoidCallback? onReports;
  final void Function(String, EntryKind)? onOpenCategory, onOpenDate;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _section = 0;
  bool _all = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, "统计")),
      actions: [
        if (widget.onReports != null)
          IconButton(
            tooltip: tr(context, "本周至今与历史报告"),
            onPressed: widget.onReports,
            icon: const Icon(Icons.summarize_outlined),
          ),
        TextButton(
          onPressed: widget.onChooseMonth,
          child: Text(
            tr(context, "{0}年{1}月 ▾", [widget.month.year, widget.month.month]),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: widget.state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StatusPanel(
          title: tr(context, "统计暂不可用"),
          message: tr(context, presentationError(e)),
        ),
        data: (data) {
          if (widget.month.compareTo(
                CalendarMonth.fromDate(widget.clock.now()),
              ) >
              0) {
            return StatusPanel(
              title: tr(context, "未来月份尚无实际统计"),
              message: tr(context, "可以先在首页设置预算"),
            );
          }
          final service = DefaultMonthlyReportService(clock: widget.clock);
          final report = service.build(
            data,
            asOfLocalDate: service.defaultCutoff(widget.month),
          );
          final income = _section == 1,
              kind = income ? EntryKind.income : EntryKind.expense;
          final total = income ? report.totalIncome : report.totalExpense;
          final daily = income ? report.dailyIncome : report.daily;
          final categories =
              (income ? report.incomeCategoryTotals : report.categoryTotals)
                  .where((c) => c.amount.fen > 0)
                  .toList()
                ..sort((a, b) => b.amount.fen.compareTo(a.amount.fen));
          final count = report.entries.where((e) => e.kind == kind).length;
          final peak = daily.fold<int>(
            0,
            (a, d) => a > d.amount.fen ? a : d.amount.fen,
          );
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MetricGrid(
                        values: [
                          (tr(context, "本月支出"), report.totalExpense),
                          (tr(context, "本月收入"), report.totalIncome),
                          (tr(context, "本月净收支"), report.netFlow),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, "统计至 {0} · 净收支为收入减支出", [
                          report.asOfLocalDate,
                        ]),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < 3; i++)
                              ChoiceChip(
                                label: Text(
                                  [
                                    tr(context, "支出分析"),
                                    tr(context, "收入分析"),
                                    tr(context, "预算趋势"),
                                  ][i],
                                ),
                                selected: _section == i,
                                onSelected: (_) => setState(() {
                                  _section = i;
                                  _all = false;
                                }),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_section == 2) ...[
                        if (report.budget == null)
                          StatusPanel(
                            title: tr(context, "还没有设置月预算"),
                            message: tr(context, "在总览或“我的”中设置后，可以查看剩余预算的变化。"),
                          )
                        else ...[
                          MetricGrid(
                            values: [
                              (tr(context, "本月预算"), report.budget),
                              (tr(context, "已支出"), report.totalExpense),
                              (tr(context, "剩余预算"), report.remaining),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: RemainingBudgetLines(report: report),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(tr(context, "收入独立统计，不会自动增加预算。")),
                        ],
                      ] else if (total.fen == 0)
                        StatusPanel(
                          title: income
                              ? tr(context, "这个月还没有收入记录")
                              : tr(context, "这个月还没有支出记录"),
                          message: tr(context, "点击底部“记账”，记录第一笔。"),
                        )
                      else ...[
                        Text(
                          income ? tr(context, "收入从哪里来") : tr(context, "钱花在哪里"),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        for (final c
                            in (_all ? categories : categories.take(5)))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: widget.onOpenCategory == null
                                    ? null
                                    : () => widget.onOpenCategory!(
                                        c.categoryId,
                                        kind,
                                      ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Icon(
                                            categoryIcon(
                                              c.categoryId,
                                              data.categories,
                                            ),
                                            size: 20,
                                            color: categoryColor(
                                              c.categoryId,
                                              data.categories,
                                            ),
                                          ),
                                          Text(
                                            localizedCategoryLabel(
                                              context,
                                              c.categoryId,
                                              c.categoryName,
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          Text(
                                            '${c.amount.yuan} · ${(c.amount.fen / total.fen * 100).toStringAsFixed(1)}%',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      LinearProgressIndicator(
                                        value: c.amount.fen / total.fen,
                                        minHeight: 5,
                                        borderRadius: BorderRadius.circular(5),
                                        color: categoryColor(
                                          c.categoryId,
                                          data.categories,
                                        ),
                                        backgroundColor:
                                            scheme.surfaceContainerHighest,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (categories.length > 5)
                          TextButton(
                            onPressed: () => setState(() => _all = !_all),
                            child: Text(
                              _all
                                  ? tr(context, "收起排行")
                                  : tr(context, "查看全部 {0} 个分类", [
                                      categories.length,
                                    ]),
                            ),
                          ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(tr(context, "查看分类环形图")),
                          children: [
                            CategoryExpenseDonut(
                              report: report,
                              income: income,
                              categories: data.categories,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          tr(context, "每日{0}", [
                            income ? tr(context, "收入") : tr(context, "支出"),
                          ]),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                            child: DailyExpenseBars(
                              report: report,
                              income: income,
                              onOpenDay: widget.onOpenDate == null
                                  ? null
                                  : (date) => widget.onOpenDate!(date, kind),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr(context, "共 {0} 笔 · 单日最高 {1}", [
                            count,
                            Money.fromFen(peak).yuan,
                          ]),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
