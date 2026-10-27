import 'dart:math' as math;
import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/presentation_errors.dart';

class LedgerCalendarPage extends StatefulWidget {
  const LedgerCalendarPage({
    super.key,
    required this.data,
    required this.view,
    required this.today,
    required this.onOpenDay,
    required this.onMarkZero,
    this.onAddDay,
    this.onEntryTap,
    this.onMoveMonth,
    this.embedded = false,
    this.selectedDate,
    this.onSelectedDate,
  });
  final LedgerMonthData data;
  final LedgerView view;
  final String today;
  final ValueChanged<String> onOpenDay;
  final Future<void> Function(String, bool) onMarkZero;
  final ValueChanged<String>? onAddDay, onSelectedDate;
  final ValueChanged<LedgerEntry>? onEntryTap;
  final ValueChanged<CalendarMonth>? onMoveMonth;
  final bool embedded;
  final String? selectedDate;
  @override
  State<LedgerCalendarPage> createState() => _LedgerCalendarPageState();
}

class _LedgerCalendarPageState extends State<LedgerCalendarPage> {
  String? _selected;
  bool _busy = false;
  String? _error;
  String get selected {
    final month = widget.data.month;
    final previous = _selected ?? widget.selectedDate;
    if (previous == null) {
      return widget.today.startsWith(month.key)
          ? widget.today
          : '${month.key}-01';
    }
    final day = math.min(parseCalendarDay(previous).day, month.days);
    return '${month.key}-${day.toString().padLeft(2, '0')}';
  }

  void move(int delta) {
    final m = widget.data.month;
    final date = DateTime.utc(m.year, m.month + delta);
    if (date.year < 1900 || date.year > 9999) return;
    _selected = selected;
    widget.onSelectedDate?.call(selected);
    widget.onMoveMonth?.call(CalendarMonth.fromDate(date));
  }

  String short(Money amount) => amount.fen >= 1000000
      ? '${(amount.fen / 1000000).toStringAsFixed(1)}万'
      : amount.decimal;
  @override
  Widget build(BuildContext context) {
    final month = widget.data.month, scheme = Theme.of(context).colorScheme;
    final date = selected;
    final dayEntries = widget.view.entries
        .where((e) => e.localDate == date)
        .toList();
    final totals = widget.view.days[date];
    // Zero-spend eligibility uses the full snapshot, even when filters hide expenses.
    final hasExpense = widget.data.entries.any(
      (e) => e.localDate == date && e.kind == EntryKind.expense,
    );
    final zero = widget.data.profile.zeroExpenseDays.contains(date),
        future = date.compareTo(widget.today) > 0;
    final offset = DateTime.utc(month.year, month.month, 1).weekday - 1;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    Future<void> toggle() async {
      if (_busy) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await widget.onMarkZero(date, !zero);
      } catch (e) {
        if (mounted) setState(() => _error = tr(context, presentationError(e)));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: tr(context, '上月'),
                onPressed: () => move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  month.key,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: tr(context, '下月'),
                onPressed: () => move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final speed = d.primaryVelocity ?? 0;
              if (speed.abs() > 100) move(speed > 0 ? -1 : 1);
            },
            child: Column(
              children: [
                Row(
                  children: [
                    for (final day in ['一', '二', '三', '四', '五', '六', '日'])
                      Expanded(child: Center(child: Text(tr(context, day)))),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: math.max(88, 72 * scale),
                  ),
                  itemCount: offset + month.days,
                  itemBuilder: (context, i) {
                    if (i < offset) return const SizedBox.shrink();
                    final day = i - offset + 1,
                        key =
                            '${month.key}-${(i - offset + 1).toString().padLeft(2, '0')}';
                    final t = widget.view.days[key],
                        marked = widget.data.profile.zeroExpenseDays.contains(
                          key,
                        );
                    final isFuture = key.compareTo(widget.today) > 0,
                        active = key == date;
                    return Semantics(
                      selected: active,
                      button: true,
                      label:
                          '$key, ${key == widget.today ? tr(context, "今天") : ""}, ${isFuture
                              ? tr(context, "未来日期")
                              : t == null
                              ? marked
                                    ? tr(context, "已确认零支出")
                                    : tr(context, "尚未记录")
                              : tr(context, "支出 {0} · 收入 {1}", [t.expense.yuan, t.income.yuan])}',
                      child: InkWell(
                        onTap: () {
                          setState(() => _selected = key);
                          widget.onSelectedDate?.call(key);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          key: ValueKey('day-$key'),
                          margin: const EdgeInsets.all(1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active ? scheme.primaryContainer : null,
                            border: active
                                ? Border.all(color: scheme.primary, width: 1.5)
                                : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                key == widget.today ? tr(context, '今') : '$day',
                                style: TextStyle(
                                  fontWeight: key == widget.today
                                      ? FontWeight.w700
                                      : null,
                                  color: isFuture
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                              ),
                              if ((t?.expense.fen ?? 0) > 0)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${tr(context, "支")} ${short(t!.expense)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: flowColor(
                                        context,
                                        EntryKind.expense,
                                      ),
                                    ),
                                  ),
                                ),
                              if ((t?.income.fen ?? 0) > 0)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${tr(context, "收")} ${short(t!.income)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: flowColor(
                                        context,
                                        EntryKind.income,
                                      ),
                                    ),
                                  ),
                                ),
                              if (marked)
                                Icon(
                                  Icons.check,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _selected = widget.today);
              widget.onSelectedDate?.call(widget.today);
              widget.onMoveMonth?.call(
                CalendarMonth.fromDate(parseCalendarDay(widget.today)),
              );
            },
            child: Text(tr(context, '回到今天')),
          ),
          const SizedBox(height: 12),
          Text(
            tr(context, '没有记录的日期保持“尚未记录”，不等同于没有消费。'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 28),
          Text(date, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (future)
            Text(tr(context, '未来日期尚无实际记录'))
          else ...[
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  tr(context, '支出 {0}', [totals?.expense.yuan ?? '¥0.00']),
                  style: TextStyle(
                    color: flowColor(
                      context,
                      EntryKind.expense,
                      amount: totals?.expense ?? const Money.fromFen(0),
                    ),
                  ),
                ),
                Text(
                  tr(context, '收入 {0}', [totals?.income.yuan ?? '¥0.00']),
                  style: TextStyle(
                    color: flowColor(
                      context,
                      EntryKind.income,
                      amount: totals?.income ?? const Money.fromFen(0),
                    ),
                  ),
                ),
              ],
            ),
            if (dayEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(tr(context, zero ? '已确认当天零支出' : '当天暂无符合当前范围的记录')),
              ),
            for (final e in dayEntries)
              EntryTile(
                entry: e,
                categories: widget.data.categories,
                onTap: widget.onEntryTap == null
                    ? null
                    : () => widget.onEntryTap!(e),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onAddDay != null)
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => widget.onAddDay!(date),
                    child: Text(tr(context, '补记这一天')),
                  ),
                if (!hasExpense)
                  TextButton(
                    onPressed: _busy ? null : toggle,
                    child: Text(
                      tr(
                        context,
                        _busy
                            ? '保存中…'
                            : zero
                            ? '取消零支出标记'
                            : '确认当天零支出',
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (_error != null)
            Text(_error!, style: TextStyle(color: scheme.error)),
        ],
      ),
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: Text(tr(context, '记账日历'))),
            body: SafeArea(child: SingleChildScrollView(child: body)),
          );
  }
}
