import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/presentation_errors.dart';
import '../domain/range_report_service.dart';
import '../../home/presentation/widgets/month_picker.dart';
import 'report_content.dart';
import '../../../shared/widgets/ios_controls.dart';

enum _ReportMode { week, month, range }

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.port,
    required this.clock,
    this.initialStart,
    this.onEntryTap,
    this.onAdd,
    this.onExport,
  });
  final PlanningPort port;
  final Clock clock;

  /// A calendar-day anchor for its natural week, never an arbitrary range.
  final String? initialStart;
  final ValueChanged<LedgerEntry>? onEntryTap;
  final VoidCallback? onAdd;
  final ValueChanged<WeeklyReport>? onExport;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool monthly = false;
  bool rangeMode = false;
  int? recentDays = 30;
  ReportDateRange? customRange;
  late DateTime anchor = parseCalendarDay(
    widget.initialStart ?? calendarDayKey(widget.clock.now()),
  );
  int refresh = 0;
  String? streamKey;
  Stream<LedgerRangeData>? stream;
  DateTime get now => calendarDay(widget.clock.now());
  DateTime startFor(DateTime date) => monthly
      ? DateTime.utc(date.year, date.month)
      : calendarDay(date).subtract(Duration(days: date.weekday - 1));
  DateTime endFor(DateTime date) => monthly
      ? DateTime.utc(date.year, date.month + 1, 0)
      : startFor(date).add(const Duration(days: 6));
  bool allowed(DateTime date) {
    final start = startFor(date),
        end = endFor(date),
        instant = widget.clock.now();
    if (start.year < 1900 || start.year > 9999 || start.isAfter(now)) {
      return false;
    }
    if (!monthly &&
        !const RangeReportService().retained(
          calendarDayKey(end.isAfter(now) ? now : end),
          instant,
        )) {
      return false;
    }
    if (instant.hour < 8 && end == now.subtract(const Duration(days: 1))) {
      return false;
    }
    return true;
  }

  void move(int step) {
    final date = monthly
        ? DateTime.utc(anchor.year, anchor.month + step)
        : anchor.add(Duration(days: 7 * step));
    if (allowed(date)) setState(() => anchor = date);
  }

  void switchPeriod(bool value) {
    if (!rangeMode && monthly == value) return;
    setState(() {
      rangeMode = false;
      monthly = value;
      // Keep the viewed date when changing type. Old months outside the
      // retained weekly window return to this week when switching to weekly.
      if (!allowed(anchor)) anchor = now;
    });
  }

  Future<void> chooseRange(ReportDateRange current) async {
    final chosen = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateUtils.dateOnly(widget.clock.now()),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
    );
    if (!mounted || chosen == null) return;
    try {
      final selected = ReportDateRange(
        calendarDayKey(chosen.start),
        calendarDayKey(chosen.end),
        now: widget.clock.now(),
      );
      setState(() {
        recentDays = null;
        customRange = selected;
      });
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, '日期范围须为 1 至 366 天，且不晚于今天'))),
      );
    }
  }

  Future<void> choose() async {
    DateTime? date;
    if (monthly) {
      final month = await showMonthPicker(
        context,
        CalendarMonth.fromDate(anchor),
        maxMonth: CalendarMonth.fromDate(now),
      );
      if (month != null) date = DateTime.utc(month.year, month.month);
    } else {
      date = await showDatePicker(
        context: context,
        initialDate: anchor.isAfter(now) ? now : anchor,
        firstDate: now.subtract(const Duration(days: 36)),
        lastDate: DateTime(now.year, now.month, now.day),
      );
    }
    if (!mounted || date == null) return;
    if (allowed(date)) {
      setState(() => anchor = calendarDay(date!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, '该期间尚未提供或已超过周报范围，请选择历史月报'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = rangeMode
        ? recentDays == null
              ? customRange!
              : ReportDateRange.recent(recentDays!, now: now)
        : null;
    final a = range?.start ?? startFor(anchor);
    final naturalEnd = range?.end ?? endFor(anchor);
    final b = naturalEnd.isAfter(now) ? now : naturalEnd;
    final ongoing = range == null && !naturalEnd.isBefore(now);
    final previousStart = monthly
        ? DateTime.utc(a.year, a.month - 1)
        : a.subtract(const Duration(days: 7));
    final previousNaturalEnd = monthly
        ? DateTime.utc(a.year, a.month, 0)
        : a.subtract(const Duration(days: 1));
    final dayCount = b.difference(a).inDays + 1;
    final previousEnd = previousStart.add(Duration(days: dayCount - 1));
    final comparable =
        ongoing &&
        previousStart.year >= 1900 &&
        !previousEnd.isAfter(previousNaturalEnd);
    final start = calendarDayKey(a),
        end = calendarDayKey(b),
        queryStart = calendarDayKey(comparable ? previousStart : a);
    final key = '$queryStart:$end:$refresh';
    if (key != streamKey) {
      streamKey = key;
      stream = widget.port.watchRange(queryStart, end);
    }
    final before = monthly
        ? DateTime.utc(anchor.year, anchor.month - 1)
        : anchor.subtract(const Duration(days: 7));
    final after = monthly
        ? DateTime.utc(anchor.year, anchor.month + 1)
        : anchor.add(const Duration(days: 7));
    final compactControls =
        MediaQuery.textScalerOf(context).scale(14) > 17.5 ||
        MediaQuery.sizeOf(context).width < 350;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, '周报月报')),
        actions: [
          if (compactControls)
            IconButton(
              tooltip: tr(context, '区间'),
              isSelected: rangeMode,
              onPressed: () => setState(() => rangeMode = true),
              icon: const Icon(Icons.date_range_outlined),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (compactControls) ...[
                    ChoiceChip(
                      label: Text(tr(context, '周报')),
                      selected: !rangeMode && !monthly,
                      onSelected: (_) => switchPeriod(false),
                    ),
                    ChoiceChip(
                      label: Text(tr(context, '月报')),
                      selected: !rangeMode && monthly,
                      onSelected: (_) => switchPeriod(true),
                    ),
                  ] else
                    IosSegmentedControl<_ReportMode>(
                      labels: {
                        _ReportMode.week: tr(context, '周报'),
                        _ReportMode.month: tr(context, '月报'),
                        _ReportMode.range: tr(context, '区间'),
                      },
                      value: rangeMode
                          ? _ReportMode.range
                          : monthly
                          ? _ReportMode.month
                          : _ReportMode.week,
                      onChanged: (mode) {
                        if (mode == _ReportMode.range) {
                          setState(() => rangeMode = true);
                        } else {
                          switchPeriod(mode == _ReportMode.month);
                        }
                      },
                    ),
                  if (!rangeMode && !monthly)
                    TextButton(
                      onPressed: () => switchPeriod(true),
                      child: Text(tr(context, '切换到月报')),
                    ),
                ],
              ),
            ),
            if (range != null) ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final days in [30, 90])
                    ChoiceChip(
                      label: Text(tr(context, '最近 {0} 天', [days])),
                      selected: recentDays == days,
                      onSelected: (_) => setState(() => recentDays = days),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => chooseRange(range),
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(tr(context, '自定义区间')),
                  ),
                ],
              ),
              Text('$start – $end', textAlign: TextAlign.center),
            ] else
              Row(
                children: [
                  IconButton(
                    tooltip: tr(context, '上一期间'),
                    onPressed: allowed(before) ? () => move(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('report-period-picker'),
                      onPressed: choose,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$start — $end', textAlign: TextAlign.center),
                          Text(
                            tr(context, monthly ? '选择月份' : '选择日期'),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr(context, '下一期间'),
                    onPressed: allowed(after) ? () => move(1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            if (ongoing) Text(tr(context, '截至 {0}', [end])),
            Expanded(
              child: StreamBuilder<LedgerRangeData>(
                key: ValueKey(key),
                stream: stream,
                builder: (context, s) {
                  if (s.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tr(context, presentationError(s.error!))),
                          TextButton(
                            onPressed: () => setState(() => refresh++),
                            child: Text(tr(context, '重试')),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final full = s.data!, service = const RangeReportService();
                  LedgerRangeData slice(String from, String to) =>
                      LedgerRangeData(
                        start: from,
                        end: to,
                        entries: full.entries.where(
                          (e) =>
                              e.localDate.compareTo(from) >= 0 &&
                              e.localDate.compareTo(to) <= 0,
                        ),
                        categories: full.categories,
                        zeroExpenseDays: full.zeroExpenseDays.where(
                          (d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0,
                        ),
                        revision: full.revision,
                      );
                  final report = service.build(
                    slice(start, end),
                    now: widget.clock.now(),
                  );
                  return ReportContent(
                    report: report,
                    monthly: !rangeMode && monthly,
                    customRange: rangeMode,
                    onExport: widget.onExport == null
                        ? null
                        : () => widget.onExport!(report),
                    previous: comparable
                        ? service.build(
                            slice(
                              calendarDayKey(previousStart),
                              calendarDayKey(previousEnd),
                            ),
                            now: widget.clock.now(),
                          )
                        : null,
                    onEntryTap: widget.onEntryTap,
                    onAdd: widget.onAdd,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
