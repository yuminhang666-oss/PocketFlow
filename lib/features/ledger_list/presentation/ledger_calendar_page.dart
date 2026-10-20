import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/amount_text.dart';

class LedgerCalendarPage extends StatefulWidget {
  const LedgerCalendarPage({
    super.key,
    required this.data,
    required this.view,
    required this.today,
    required this.onOpenDay,
    required this.onMarkZero,
    this.onAddDay,
  });
  final LedgerMonthData data;
  final LedgerView view;
  final String today;
  final ValueChanged<String> onOpenDay;
  final Future<void> Function(String, bool) onMarkZero;
  final ValueChanged<String>? onAddDay;
  @override
  State<LedgerCalendarPage> createState() => _LedgerCalendarPageState();
}

class _LedgerCalendarPageState extends State<LedgerCalendarPage> {
  String? _selected;
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final month = widget.data.month, scheme = Theme.of(context).colorScheme;
    final dayLabel = TextPainter(
      text: TextSpan(
        text: '31',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout();
    final calendarWidth = math.max(
      MediaQuery.sizeOf(context).width,
      7.0 * math.max(48.0, dayLabel.width + 14),
    );
    final cellHeight = math.max(66.0, dayLabel.height + 28);
    dayLabel.dispose();
    final offset = DateTime.utc(month.year, month.month, 1).weekday - 1;
    final selected =
        _selected ??
        (widget.today.startsWith(month.key) ? widget.today : '${month.key}-01');
    final totals = widget.view.days[selected];
    final zero = widget.data.profile.zeroExpenseDays.contains(selected);
    final future = selected.compareTo(widget.today) > 0;
    Future<void> toggle() async {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await widget.onMarkZero(selected, !zero);
      } catch (e) {
        if (mounted) setState(() => _error = '操作未完成，请重试');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('${month.year}年${month.month}月 · 记账日历')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: calendarWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (final day in const [
                              '一',
                              '二',
                              '三',
                              '四',
                              '五',
                              '六',
                              '日',
                            ])
                              Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisExtent: cellHeight,
                              ),
                          itemCount: offset + month.days,
                          itemBuilder: (context, i) {
                            if (i < offset) return const SizedBox.shrink();
                            final day = i - offset + 1,
                                date =
                                    '${month.key}-${day.toString().padLeft(2, '0')}';
                            final data = widget.view.days[date],
                                marked = widget.data.profile.zeroExpenseDays
                                    .contains(date);
                            final isFuture = date.compareTo(widget.today) > 0;
                            final desc = isFuture
                                ? '未来日期'
                                : data != null
                                ? '${data.count}笔记录'
                                : marked
                                ? '已确认零支出'
                                : '尚未记录';
                            return Semantics(
                              label: '${month.month}月$day日，$desc',
                              button: true,
                              child: InkWell(
                                onTap: () => setState(() => _selected = date),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: date == selected
                                        ? scheme.primaryContainer
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    border: date == widget.today
                                        ? Border.all(color: scheme.primary)
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$day',
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isFuture
                                              ? scheme.onSurfaceVariant
                                              : scheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if ((data?.expense.fen ?? 0) > 0)
                                            const Icon(
                                              Icons.circle,
                                              size: 6,
                                              color: Color(0xFFBF5700),
                                            ),
                                          if ((data?.income.fen ?? 0) > 0) ...[
                                            const SizedBox(width: 3),
                                            Icon(
                                              Icons.circle,
                                              size: 6,
                                              color: scheme.primary,
                                            ),
                                          ],
                                          if (marked &&
                                              (data?.expense.fen ?? 0) == 0)
                                            Icon(
                                              Icons.check,
                                              size: 12,
                                              color: scheme.primary,
                                            ),
                                        ],
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('橙点：支出 · 蓝点：收入 · 勾选：主动确认零支出'),
                    const SizedBox(height: 6),
                    Text(
                      '没有记录的日期保持“尚未记录”，不等同于没有消费。',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      selected,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (future)
                      const Text('未来日期尚无实际记录')
                    else ...[
                      Text(
                        totals == null
                            ? (zero ? '已确认当天零支出' : '当天尚未记录')
                            : '当天 ${totals.count} 笔',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('支出'),
                              AmountText(
                                totals?.expense ?? const Money.fromFen(0),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('收入'),
                              AmountText(
                                totals?.income ?? const Money.fromFen(0),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => widget.onOpenDay(selected),
                        child: const Text('查看当天账单'),
                      ),
                      if (widget.onAddDay != null)
                        TextButton(
                          onPressed:
                              _busy || selected.compareTo(widget.today) > 0
                              ? null
                              : () => widget.onAddDay!(selected),
                          child: const Text('记入选定日期'),
                        ),
                      if ((totals?.expense.fen ?? 0) == 0)
                        TextButton(
                          onPressed: _busy ? null : toggle,
                          child: Text(
                            _busy
                                ? '保存中…'
                                : zero
                                ? '取消零支出标记'
                                : '确认当天零支出',
                          ),
                        ),
                    ],
                    if (_error != null)
                      Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
