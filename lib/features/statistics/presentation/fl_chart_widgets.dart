import 'package:pocketflow/l10n/app_strings.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../domain/monthly_chart_data.dart';

String _axisAmount(BuildContext context, double v) {
  if (v.abs() >= 10000) {
    return tr(context, "{0}万元", [(v / 10000).toStringAsFixed(1)]);
  }
  if (v.abs() >= 1000) {
    return tr(context, "{0}千元", [(v / 1000).toStringAsFixed(1)]);
  }
  return tr(context, "{0}元", [
    v.toStringAsFixed(v.abs() < 1 && v != 0 ? 1 : 0),
  ]);
}

FlTitlesData _titles(BuildContext context, int lastDay, double interval) =>
    FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 48,
          interval: interval,
          minIncluded: false,
          maxIncluded: false,
          getTitlesWidget: (v, meta) => Text(
            _axisAmount(context, v),
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final d = v.toInt();
            return d > 0 && (d == 1 || d == lastDay || d % 7 == 0)
                ? Text('$d', style: const TextStyle(fontSize: 11))
                : const SizedBox.shrink();
          },
        ),
      ),
    );
FlGridData _grid(BuildContext context, double interval) => FlGridData(
  show: true,
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant,
    strokeWidth: 0.6,
  ),
);

class CategoryExpenseDonut extends StatelessWidget {
  const CategoryExpenseDonut({
    super.key,
    required this.report,
    this.income = false,
    this.categories = const [],
  });
  final MonthlyReport report;
  final bool income;
  final List<Category> categories;
  @override
  Widget build(BuildContext context) {
    final items = (income ? report.incomeCategoryTotals : report.categoryTotals)
        .where((c) => c.amount.fen > 0)
        .toList();
    final total = income ? report.totalIncome : report.totalExpense;
    if (total.fen == 0) {
      return Text(income ? tr(context, "该统计期间暂无收入") : tr(context, "该统计期间暂无消费"));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: tr(context, "分类{0}环形图，金额见下方列表", [
            income ? tr(context, "收入") : tr(context, "消费"),
          ]),
          child: ExcludeSemantics(
            child: SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 54,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  sections: [
                    for (final c in items)
                      PieChartSectionData(
                        value: c.amount.fen.toDouble(),
                        color: categoryColor(c.categoryId, categories),
                        radius: 28,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: categoryColor(items[i].categoryId, categories),
                ),
                Text(
                  '${i + 1}. ${localizedCategoryLabel(context, items[i].categoryId, items[i].categoryName)}',
                ),
                Text(
                  '${items[i].amount.yuan} · ${(items[i].amount.fen / total.fen * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class DailyExpenseBars extends StatelessWidget {
  const DailyExpenseBars({
    super.key,
    required this.report,
    this.income = false,
    this.onOpenDay,
  });
  final MonthlyReport report;
  final bool income;
  final ValueChanged<String>? onOpenDay;
  @override
  Widget build(BuildContext context) {
    final daily = income ? report.dailyIncome : report.daily;
    final scheme = Theme.of(context).colorScheme;
    final peak = daily.fold<int>(0, (a, d) => math.max(a, d.amount.fen)) / 100;
    final maxY = math.max(1.0, peak * 1.15), interval = maxY / 4;
    final amounts = {for (final d in daily) d.date.day: d.amount};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, "金额（元） · {0}", [
            onOpenDay == null
                ? tr(context, "点击柱形查看金额")
                : tr(context, "点击日期柱查看账单"),
          ]),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              titlesData: _titles(context, report.month.days, interval),
              borderData: FlBorderData(show: false),
              gridData: _grid(context, interval),
              barGroups: [
                for (var day = 1; day <= report.month.days; day++)
                  BarChartGroupData(
                    x: day,
                    barRods: [
                      BarChartRodData(
                        toY: (amounts[day]?.fen ?? 0) / 100,
                        width: 5,
                        color: day > report.asOf.day
                            ? Colors.transparent
                            : (income
                                  ? scheme.primary
                                  : const Color(0xFFBF5700)),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ],
                  ),
              ],
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  final day = response?.spot?.touchedBarGroup.x;
                  if (event is FlTapUpEvent &&
                      day != null &&
                      day <= report.asOf.day) {
                    onOpenDay?.call(
                      '${report.month.key}-${day.toString().padLeft(2, '0')}',
                    );
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      group.x > report.asOf.day
                      ? null
                      : BarTooltipItem(
                          tr(context, "{0}日\n{1}", [
                            group.x,
                            (amounts[group.x] ?? const Money.fromFen(0)).yuan,
                          ]),
                          TextStyle(color: scheme.onInverseSurface),
                        ),
                ),
              ),
            ),
          ),
        ),
        Text(tr(context, "截止日后的日期尚未统计。"), style: TextStyle(fontSize: 12)),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(tr(context, "查看每日金额")),
          children: [
            for (final d in daily)
              ListTile(
                title: Text(d.localDate),
                trailing: Text(d.amount.yuan),
                onTap: onOpenDay == null ? null : () => onOpenDay!(d.localDate),
              ),
          ],
        ),
      ],
    );
  }
}

class RemainingBudgetLines extends StatelessWidget {
  const RemainingBudgetLines({super.key, required this.report});
  final MonthlyReport report;
  @override
  Widget build(BuildContext context) {
    if (report.budget == null) return Text(tr(context, "设置月预算后显示余额趋势"));
    final points = monthlyChartData(report),
        budget = report.budget!,
        scheme = Theme.of(context).colorScheme;
    final min = math.min(0.0, report.remaining!.fen / 100);
    final max = math.max(1.0, budget.fen / 100);
    final interval = (max - min) / 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, "剩余预算（元） · 实线：每日末余额 · 虚线：均匀消耗参考"),
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: report.month.days.toDouble(),
              minY: min - interval * 0.1,
              maxY: max + interval * 0.1,
              titlesData: _titles(context, report.month.days, interval),
              gridData: _grid(context, interval),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  color: scheme.primary,
                  isCurved: false,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  spots: [
                    FlSpot(0, budget.fen / 100),
                    for (final p in points)
                      if (p.remaining != null)
                        FlSpot(p.day.toDouble(), p.remaining!.fen / 100),
                  ],
                ),
                LineChartBarData(
                  color: scheme.onSurfaceVariant,
                  isCurved: false,
                  dashArray: [6, 4],
                  dotData: const FlDotData(show: false),
                  spots: [
                    FlSpot(0, budget.fen / 100),
                    for (final p in points)
                      FlSpot(p.day.toDouble(), p.referenceRemaining!.fen / 100),
                  ],
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        '${spot.x.toInt() == 0 ? tr(context, "月初") : tr(context, "{0}日", [spot.x.toInt()])} ${spot.barIndex == 0 ? tr(context, "余额") : tr(context, "参考")}\n'
                        '${spot.x.toInt() == 0 ? budget.yuan : (spot.barIndex == 0 ? points[spot.x.toInt() - 1].remaining!.yuan : points[spot.x.toInt() - 1].referenceRemaining!.yuan)}',
                        TextStyle(color: scheme.onInverseSurface),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          tr(context, "参考线不是消费预测，按当前预算计算，不含历史调额记录。"),
          style: TextStyle(fontSize: 12),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(tr(context, "查看余额明细")),
          children: [
            for (final p in points)
              if (p.remaining != null)
                ListTile(
                  title: Text(
                    tr(context, "{0}日 · {1}", [p.day, p.remaining!.yuan]),
                  ),
                  subtitle: Text(
                    tr(context, "参考 {0}", [p.referenceRemaining!.yuan]),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
