import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pocketflow/l10n/app_strings.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/metric_grid.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../statistics/domain/report_arithmetic.dart';
import '../domain/range_trend.dart';

class ReportContent extends StatelessWidget {
  const ReportContent({
    super.key,
    required this.report,
    this.previous,
    this.onEntryTap,
    this.onAdd,
    required this.monthly,
    this.customRange = false,
    this.onExport,
  });
  final WeeklyReport report;
  final WeeklyReport? previous;
  final bool monthly;
  final bool customRange;
  final VoidCallback? onExport;
  final ValueChanged<LedgerEntry>? onEntryTap;
  final VoidCallback? onAdd;
  Future<void> entries(
    BuildContext context,
    String title,
    Iterable<LedgerEntry> values,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .65,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (values.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(context, '暂无记录')),
            ),
          for (final e in values)
            EntryTile(
              entry: e,
              categories: report.data.categories,
              onTap: onEntryTap == null
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      onEntryTap!(e);
                    },
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme, data = report.data;
    final largest = report.largestExpense;
    final scale = customRange
        ? rangeTrendScale(report.daily.length)
        : RangeTrendScale.day;
    final trend = groupRangeTrend(report.daily, scale);
    final trendLabel = switch (scale) {
      RangeTrendScale.day => '每日趋势',
      RangeTrendScale.week => '每周趋势',
      RangeTrendScale.month => '每月趋势',
    };
    String periodLabel(RangeTrendBucket bucket) => bucket.start == bucket.end
        ? bucket.start
        : '${bucket.start} – ${bucket.end}';
    final peak = trend.fold<int>(
      0,
      (a, d) => math.max(a, math.max(d.expense.fen, d.income.fen)),
    );
    final updated = DateTime.fromMillisecondsSinceEpoch(report.updatedAtUtcMs);
    final updateLabel =
        '${calendarDayKey(updated)} ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
    final rankingKey = GlobalKey(), reviewKey = GlobalKey();
    void jump(GlobalKey key) {
      final target = key.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
        );
      }
    }

    return SingleChildScrollView(
      key: PageStorageKey((monthly, customRange, data.start, data.end)),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetricGrid(
            values: [
              (tr(context, '支出'), report.expense),
              (tr(context, '收入'), report.income),
            ],
          ),
          if (customRange)
            Text(tr(context, '日均支出 {0}', [report.averageDailyExpense.yuan])),
          if (onExport != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(tr(context, '导出报告')),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              Text(tr(context, '按已记录账目 · {0}笔', [data.entries.length])),
              Wrap(
                spacing: 4,
                children: [
                  Text(tr(context, '净收支')),
                  AmountText(
                    report.net,
                    style: TextStyle(
                      color: flowColor(
                        context,
                        report.net.fen < 0
                            ? EntryKind.expense
                            : EntryKind.income,
                        amount: report.net,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (data.entries.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => jump(rankingKey),
                  child: Text(tr(context, '分类排行 ↓')),
                ),
                TextButton(
                  onPressed: () => jump(reviewKey),
                  child: Text(tr(context, '简短回顾 ↓')),
                ),
              ],
            ),
          if (previous != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                previous!.expense.fen == 0 || previous!.data.entries.isEmpty
                    ? tr(context, '上期暂无可比支出，不计算变化率')
                    : tr(context, '相比上期同等{0}天，支出变化 {1}%', [
                        report.daily.length,
                        ((report.expense.fen - previous!.expense.fen) /
                                previous!.expense.fen *
                                100)
                            .toStringAsFixed(1),
                      ]),
              ),
            ),
          if (data.entries.isEmpty) ...[
            const SizedBox(height: 12),
            Text(tr(context, '此期间暂无记录；没有记录不代表实际没有消费。')),
            if (onAdd != null)
              TextButton(onPressed: onAdd, child: Text(tr(context, '开始记账'))),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              tr(context, trendLabel),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                Text(
                  tr(context, '支出'),
                  style: TextStyle(
                    color: flowColor(context, EntryKind.expense),
                  ),
                ),
                Text(
                  tr(context, '收入'),
                  style: TextStyle(color: flowColor(context, EntryKind.income)),
                ),
                Text(
                  tr(context, '金额（元）'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  '${tr(context, trendLabel)} · '
                  '${tr(context, '支出 {0} · 收入 {1}', [report.expense.yuan, report.income.yuan])}',
              excludeSemantics: true,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height < 700 ? 128 : 160,
                child: BarChart(
                  BarChartData(
                    maxY: math.max(1.0, peak / 100 * 1.15),
                    minY: 0,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: scheme.outlineVariant, strokeWidth: .5),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, m) {
                            final i = v.toInt();
                            if (i < 0 ||
                                i >= trend.length ||
                                (trend.length > 10 &&
                                    i != 0 &&
                                    i != trend.length - 1 &&
                                    i % ((trend.length + 4) ~/ 5) != 0)) {
                              return const SizedBox.shrink();
                            }
                            final day = parseCalendarDay(trend[i].start);
                            return Text(
                              scale == RangeTrendScale.day
                                  ? '${day.day}'
                                  : '${day.month}/${day.day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < trend.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: trend[i].expense.fen / 100,
                              width: trend.length > 10 ? 3 : 8,
                              color: flowColor(context, EntryKind.expense),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                            BarChartRodData(
                              toY: trend[i].income.fen / 100,
                              width: trend.length > 10 ? 3 : 8,
                              color: flowColor(context, EntryKind.income),
                              borderRadius: BorderRadius.zero,
                            ),
                          ],
                        ),
                    ],
                    barTouchData: BarTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent && response?.spot != null) {
                          final bucket =
                              trend[response!.spot!.touchedBarGroup.x];
                          entries(
                            context,
                            periodLabel(bucket),
                            data.entries.where(
                              (entry) =>
                                  entry.localDate.compareTo(bucket.start) >=
                                      0 &&
                                  entry.localDate.compareTo(bucket.end) <= 0,
                            ),
                          );
                        }
                      },
                      touchTooltipData: BarTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipColor: (_) => scheme.inverseSurface,
                        getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                          '${periodLabel(trend[g.x])}\n${tr(context, ri == 0 ? "支出" : "收入")} ${(ri == 0 ? trend[g.x].expense : trend[g.x].income).yuan}',
                          TextStyle(color: scheme.onInverseSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(tr(context, '逐日金额与账单')),
              children: [
                for (final d in report.daily)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(d.localDate),
                    subtitle: Text(
                      tr(context, '支出 {0} · 收入 {1}', [
                        d.expense.yuan,
                        d.income.yuan,
                      ]),
                    ),
                    trailing: Text(tr(context, '{0}笔', [d.count])),
                    onTap: () => entries(
                      context,
                      d.localDate,
                      data.entries.where((e) => e.localDate == d.localDate),
                    ),
                  ),
              ],
            ),
            Text(
              tr(context, '零柱仅表示当日已记录支出为零，不代表实际没有消费。'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              tr(context, '分类排行'),
              key: rankingKey,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (report.categories.isEmpty) Text(tr(context, '暂无支出记录')),
            for (final c in report.categories)
              InkWell(
                onTap: () => entries(
                  context,
                  localizedCategoryLabel(context, c.categoryId, c.name),
                  data.entries.where(
                    (e) =>
                        e.kind == EntryKind.expense &&
                        categoryRoot(e.categoryId, data.categories) ==
                            c.categoryId,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            localizedCategoryLabel(
                              context,
                              c.categoryId,
                              c.name,
                            ),
                          ),
                          Text(
                            '${c.amount.yuan} · ${reportPercent(c.amount.fen, report.expense.fen, decimalPlaces: 1)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: c.amount.fen / report.expense.fen,
                        minHeight: 7,
                        color: identityColor(
                          context,
                          c.categoryId,
                          data.categories,
                        ),
                        backgroundColor: scheme.outlineVariant.withValues(
                          alpha: .35,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              tr(context, '简短回顾'),
              key: reviewKey,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, '已记录 {0} 笔，覆盖 {1} 天', [
                data.entries.length,
                data.entries.map((e) => e.localDate).toSet().length,
              ]),
            ),
            if (largest != null) ...[
              Text(tr(context, '最大一笔支出')),
              EntryTile(
                entry: largest,
                categories: data.categories,
                onTap: onEntryTap == null ? null : () => onEntryTap!(largest),
              ),
              if (report.largestTieCount > 1)
                Text(tr(context, '并列最高共 {0} 笔', [report.largestTieCount])),
            ],
          ],
          const SizedBox(height: 20),
          Text(
            tr(context, '按当前账目更新于 {0}', [updateLabel]),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            tr(context, '周报按结束日后30个自然日展示。更早记录可从自然月月报重算；账单不会被删除。'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
