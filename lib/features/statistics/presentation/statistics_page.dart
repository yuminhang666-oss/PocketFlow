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
  });
  final CalendarMonth month;
  final AsyncValue<LedgerMonthData> state;
  final Clock clock;
  final VoidCallback? onChooseMonth;
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
      title: const Text('统计'),
      actions: [
        TextButton(
          onPressed: widget.onChooseMonth,
          child: Text('${widget.month.year}年${widget.month.month}月 ▾'),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: widget.state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            StatusPanel(title: '统计暂不可用', message: presentationError(e)),
        data: (data) {
          if (widget.month.compareTo(
                CalendarMonth.fromDate(widget.clock.now()),
              ) >
              0) {
            return const StatusPanel(
              title: '未来月份尚无实际统计',
              message: '可以先在首页设置预算',
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
                          ('本月支出', report.totalExpense),
                          ('本月收入', report.totalIncome),
                          ('本月净收支', report.netFlow),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '统计至 ${report.asOfLocalDate} · 净收支为收入减支出',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < 3; i++)
                            ChoiceChip(
                              label: Text(['支出分析', '收入分析', '预算趋势'][i]),
                              selected: _section == i,
                              onSelected: (_) => setState(() {
                                _section = i;
                                _all = false;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_section == 2) ...[
                        if (report.budget == null)
                          const StatusPanel(
                            title: '还没有设置月预算',
                            message: '在总览或“我的”中设置后，可以查看剩余预算的变化。',
                          )
                        else ...[
                          MetricGrid(
                            values: [
                              ('本月预算', report.budget),
                              ('已支出', report.totalExpense),
                              ('剩余预算', report.remaining),
                            ],
                          ),
                          const SizedBox(height: 18),
                          RemainingBudgetLines(report: report),
                          const SizedBox(height: 12),
                          const Text('收入独立统计，不会自动增加预算。'),
                        ],
                      ] else if (total.fen == 0)
                        StatusPanel(
                          title: income ? '这个月还没有收入记录' : '这个月还没有支出记录',
                          message: '点击底部“记账”，记录第一笔。',
                        )
                      else ...[
                        Text(
                          income ? '收入从哪里来' : '钱花在哪里',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        for (final c
                            in (_all ? categories : categories.take(5)))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
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
                                            c.categoryName,
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
                              _all ? '收起排行' : '查看全部 ${categories.length} 个分类',
                            ),
                          ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('查看分类环形图'),
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
                          '每日${income ? '收入' : '支出'}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        DailyExpenseBars(
                          report: report,
                          income: income,
                          onOpenDay: widget.onOpenDate == null
                              ? null
                              : (date) => widget.onOpenDate!(date, kind),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '共 $count 笔 · 单日最高 ${Money.fromFen(peak).yuan}',
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
