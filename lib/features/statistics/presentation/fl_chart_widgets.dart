// Activated during MVP integration with the pinned fl_chart dependency.
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../contracts/contracts.dart';
import '../domain/monthly_chart_data.dart';
import '../domain/report_insights.dart';

/// Theme-derived palette; the numbered legend and labels also work in grayscale.
Color _color(BuildContext context, int index) {
  final scheme = Theme.of(context).colorScheme;
  return [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
    scheme.onSurfaceVariant,
    scheme.primaryContainer,
    scheme.tertiaryContainer,
    scheme.secondaryContainer,
    scheme.outline,
  ][index % 8];
}

final class CategoryExpenseDonut extends StatelessWidget {
  const CategoryExpenseDonut({super.key, required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final categories = report.categoryTotals
        .where((c) => c.amount.fen > 0)
        .toList();
    if (report.totalExpense.fen == 0) return const Text('该统计期间暂无消费');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '分类消费环形图，详情见下方分类列表',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 58,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  sections: [
                    for (var i = 0; i < categories.length; i++)
                      PieChartSectionData(
                        value: categories[i].amount.fen.toDouble(),
                        color: _color(context, i),
                        radius: 32,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // No labels on tiny sectors; wrap long names/large text below the plot.
        for (var i = 0; i < categories.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.circle, size: 12, color: _color(context, i)),
                Text('${i + 1}. ${categories[i].categoryName}'),
                Text(
                  '${categories[i].amount.yuan} · ${report.categoryPercent(categories[i])}',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

FlTitlesData _titles(int lastDay) => FlTitlesData(
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 32,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final day = value.toInt();
        return day == 1 || day == lastDay || day % 5 == 0
            ? Text('$day')
            : const SizedBox.shrink();
      },
    ),
  ),
);

final class DailyExpenseBars extends StatelessWidget {
  const DailyExpenseBars({super.key, required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final points = monthlyChartData(report);
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('每日支出（元） · 点击柱形查看精确金额'),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(constraints.maxWidth, report.month.days * 28.0),
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: math.max(
                    1.0,
                    report.highestDailyExpense.fen / 100 * 1.1,
                  ),
                  titlesData: _titles(report.month.days),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  // Transparent placeholders preserve every calendar-day position.
                  // The projection and tooltips still expose future actuals as null.
                  barGroups: [
                    for (final point in points)
                      BarChartGroupData(
                        x: point.day,
                        barRods: [
                          BarChartRodData(
                            toY: (point.expense?.fen ?? 0) / 100,
                            color: point.expense == null
                                ? Colors.transparent
                                : color,
                            width: 12,
                            borderRadius: BorderRadius.zero,
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) =>
                          Theme.of(context).colorScheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          points[group.x - 1].expense == null
                          ? null
                          : BarTooltipItem(
                              '${report.month.key}-${group.x.toString().padLeft(2, '0')}\n'
                              '${points[group.x - 1].expense!.yuan}',
                              TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onInverseSurface,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Text('截止日后的日期尚未统计'),
        ExpansionTile(
          title: const Text('查看每日金额'),
          children: [
            for (final day in report.daily)
              ListTile(
                title: Text(day.localDate),
                subtitle: Text(day.amount.yuan),
              ),
          ],
        ),
      ],
    );
  }
}

final class RemainingBudgetLines extends StatelessWidget {
  const RemainingBudgetLines({super.key, required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    if (report.budget == null) return const Text('设置月预算后显示余额趋势');
    final points = monthlyChartData(report);
    final scheme = Theme.of(context).colorScheme;
    final budget = report.budget!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('剩余预算（元）：实线为每日末余额，虚线为均匀消耗参考'),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(constraints.maxWidth, report.month.days * 20.0),
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: report.month.days.toDouble(),
                  titlesData: _titles(report.month.days),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      color: scheme.primary,
                      isCurved: false,
                      dotData: const FlDotData(show: true),
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
                          FlSpot(
                            p.day.toDouble(),
                            p.referenceRemaining!.fen / 100,
                          ),
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
                            '${spot.x.toInt() == 0 ? '月初' : '${spot.x.toInt()}日'} '
                            '${spot.barIndex == 0 ? '余额' : '参考'}\n'
                            '${spot.x.toInt() == 0 ? budget.yuan : (spot.barIndex == 0 ? points[spot.x.toInt() - 1].remaining!.yuan : points[spot.x.toInt() - 1].referenceRemaining!.yuan)}',
                            TextStyle(color: scheme.onInverseSurface),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Text('参考线不是消费预测；按当前预算计算，不含历史调额记录。'),
        ExpansionTile(
          title: const Text('查看余额明细'),
          children: [
            for (final p in points)
              if (p.remaining != null)
                ListTile(
                  title: Text('${p.day}日 · ${p.remaining!.yuan}'),
                  subtitle: Text('参考 ${p.referenceRemaining!.yuan}'),
                ),
          ],
        ),
      ],
    );
  }
}
