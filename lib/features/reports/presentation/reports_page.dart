import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/presentation_errors.dart';
import '../domain/range_report_service.dart';
import '../../home/presentation/widgets/month_picker.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.port,
    required this.clock,
    this.initialStart,
    this.initialEnd,
  });
  final PlanningPort port;
  final Clock clock;
  final String? initialStart, initialEnd;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTime now = widget.clock.now();
  late String start =
      widget.initialStart ??
      calendarDayKey(
        calendarDay(now).subtract(Duration(days: now.weekday - 1)),
      );
  late String end = widget.initialEnd ?? calendarDayKey(now);
  bool current = false;
  int refresh = 0;
  @override
  void initState() {
    super.initState();
    current = widget.initialStart == null;
  }

  void select(String a, String b, {bool toDate = false}) => setState(() {
    start = a;
    end = b;
    current = toDate;
    refresh++;
  });
  @override
  Widget build(BuildContext context) {
    final monday = calendarDay(now).subtract(Duration(days: now.weekday - 1)),
        service = const RangeReportService();
    final queryStart = current
        ? calendarDayKey(
            parseCalendarDay(start).subtract(const Duration(days: 7)),
          )
        : start;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, "周报与月报"))),
      body: Column(
        children: [
          SizedBox(
            height: 62,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                TextButton(
                  onPressed: () async {
                    final month = await showMonthPicker(
                      context,
                      CalendarMonth.fromDate(now),
                    );
                    if (month == null || !context.mounted) return;
                    if (month.compareTo(CalendarMonth.fromDate(now)) >= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr(context, "请选择已结束的自然月"))),
                      );
                      return;
                    }
                    if (now.day == 1 &&
                        now.hour < 8 &&
                        month ==
                            CalendarMonth.fromDate(
                              DateTime.utc(now.year, now.month - 1),
                            )) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr(context, "上月完整月报将于今天08:00后提供")),
                        ),
                      );
                      return;
                    }
                    select(
                      '${month.key}-01',
                      calendarDayKey(
                        DateTime.utc(month.year, month.month, month.days),
                      ),
                    );
                  },
                  child: Text(tr(context, "选择历史月报")),
                ),
                TextButton(
                  onPressed: () => select(
                    calendarDayKey(monday),
                    calendarDayKey(now),
                    toDate: true,
                  ),
                  child: Text(tr(context, "本周至今")),
                ),
                for (var i = 1; i <= 5; i++)
                  Builder(
                    builder: (context) {
                      final a = monday.subtract(Duration(days: 7 * i)),
                          b = a.add(const Duration(days: 6));
                      if (!service.retained(calendarDayKey(b), now) ||
                          (i == 1 && now.weekday == 1 && now.hour < 8)) {
                        return const SizedBox.shrink();
                      }
                      return TextButton(
                        onPressed: () =>
                            select(calendarDayKey(a), calendarDayKey(b)),
                        child: Text(
                          tr(context, "{0}/{1}—{2}/{3}周报", [
                            a.month,
                            a.day,
                            b.month,
                            b.day,
                          ]),
                        ),
                      );
                    },
                  ),
                for (var i = 1; i <= 60; i++)
                  Builder(
                    builder: (context) {
                      if (i == 1 && now.day == 1 && now.hour < 8) {
                        return const SizedBox.shrink();
                      }
                      final month = CalendarMonth.fromDate(
                        DateTime.utc(now.year, now.month - i),
                      );
                      return TextButton(
                        onPressed: () => select(
                          '${month.key}-01',
                          calendarDayKey(
                            DateTime.utc(month.year, month.month, month.days),
                          ),
                        ),
                        child: Text(tr(context, "{0}月报", [month.key])),
                      );
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<LedgerRangeData>(
              key: ValueKey('$start:$end:$current:$refresh'),
              stream: widget.port.watchRange(queryStart, end),
              builder: (context, s) {
                if (s.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr(context, presentationError(s.error!))),
                        TextButton(
                          onPressed: () => setState(() => refresh++),
                          child: Text(tr(context, "重试")),
                        ),
                      ],
                    ),
                  );
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final full = s.data!,
                    data = LedgerRangeData(
                      start: start,
                      end: end,
                      entries: full.entries.where(
                        (e) => e.localDate.compareTo(start) >= 0,
                      ),
                      categories: full.categories,
                      zeroExpenseDays: full.zeroExpenseDays.where(
                        (d) => d.compareTo(start) >= 0,
                      ),
                      revision: full.revision,
                    );
                final report = service.build(data, now: widget.clock.now());
                WeeklyReport? previous;
                if (current) {
                  final a = calendarDayKey(
                        parseCalendarDay(
                          start,
                        ).subtract(const Duration(days: 7)),
                      ),
                      b = calendarDayKey(
                        parseCalendarDay(end).subtract(const Duration(days: 7)),
                      );
                  previous = service.build(
                    LedgerRangeData(
                      start: a,
                      end: b,
                      entries: full.entries.where(
                        (e) =>
                            e.localDate.compareTo(a) >= 0 &&
                            e.localDate.compareTo(b) <= 0,
                      ),
                      categories: full.categories,
                      revision: full.revision,
                    ),
                    now: widget.clock.now(),
                  );
                }
                final largest = report.largestExpense;
                final category = largest == null
                    ? null
                    : full.categories
                          .where((c) => c.id == largest.categoryId)
                          .firstOrNull;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '$start — $end',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(tr(context, "按已记录账目 · {0}笔", [data.entries.length])),
                    Text(
                      tr(context, "支出 {0} · 收入 {1}", [
                        report.expense.yuan,
                        report.income.yuan,
                      ]),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(tr(context, "净收支 {0}（收入减支出）", [report.net.yuan])),
                    if (data.entries.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(tr(context, "此期间暂无记录；没有记录不代表实际没有消费。")),
                      ),
                    if (data.entries.isNotEmpty && report.expense.fen == 0)
                      Text(
                        tr(context, "本期记录收入 {0}，暂无支出记录", [report.income.yuan]),
                      ),
                    if (previous != null)
                      Text(
                        previous.expense.fen == 0 ||
                                previous.data.entries.isEmpty
                            ? tr(context, "上周同期暂无可比较支出，不计算变化率")
                            : tr(context, "相比上周同等{0}天，支出变化 {1}%", [
                                now.weekday,
                                ((report.expense.fen - previous.expense.fen) /
                                        previous.expense.fen *
                                        100)
                                    .toStringAsFixed(1),
                              ]),
                      ),
                    const Divider(),
                    Text(
                      tr(context, "每日收支"),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final d in report.daily)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.localDate),
                            Text(
                              d.count == 0
                                  ? (data.zeroExpenseDays.contains(d.localDate)
                                        ? tr(context, "已确认零支出")
                                        : tr(context, "暂无记录"))
                                  : tr(context, "{0}笔", [d.count]),
                            ),
                            Wrap(
                              spacing: 16,
                              children: [
                                Text(tr(context, "支出 {0}", [d.expense.yuan])),
                                Text(tr(context, "收入 {0}", [d.income.yuan])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Text(
                      tr(context, "支出根分类"),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final c in report.categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizedCategoryLabel(
                                context,
                                c.categoryId,
                                c.name,
                              ),
                            ),
                            Text(
                              tr(context, "占比 {0}", [
                                report.expense.fen == 0
                                    ? tr(context, "暂无")
                                    : '${(c.amount.fen / report.expense.fen * 100).toStringAsFixed(1)}%',
                              ]),
                            ),
                            Text(c.amount.yuan),
                          ],
                        ),
                      ),
                    if (report.categoryTieCount > 1)
                      Text(
                        tr(context, "消费最高分类并列共 {0} 类", [
                          report.categoryTieCount,
                        ]),
                      ),
                    const Divider(),
                    Text(
                      tr(context, "最大一笔支出"),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (largest == null)
                      Text(tr(context, "暂无支出记录"))
                    else ...[
                      Text(
                        '${largest.amount.yuan} · ${largest.localDate} · ${category == null ? largest.categoryId : localizedCategoryPath(context, category, full.categories)}',
                      ),
                      if (largest.note.isNotEmpty) Text(largest.note),
                      if (report.largestTieCount > 1)
                        Text(
                          tr(context, "并列最高共 {0} 笔", [report.largestTieCount]),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      tr(context, "按当前账目更新于 {0}", [
                        DateTime.fromMillisecondsSinceEpoch(
                          report.updatedAtUtcMs,
                        ),
                      ]),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(tr(context, "周报按结束日后30个自然日展示。更早记录可从自然月月报重算；账单不会被删除。")),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
