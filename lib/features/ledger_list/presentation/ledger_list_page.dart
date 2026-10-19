import 'package:flutter/material.dart';
import '../../../shared/widgets/completed_modal.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/metric_grid.dart';
import '../../../shared/widgets/status_panel.dart';
import '../../../core/domain/category_catalog.dart';

class LedgerListPage extends StatefulWidget {
  const LedgerListPage({
    super.key,
    required this.data,
    required this.query,
    required this.asOfLocalDate,
    this.onEntryTap,
    this.onChooseMonth,
    this.initialDate,
    this.initialCategoryId,
    this.initialKind,
  });
  final LedgerMonthData data;
  final LedgerQueryService query;
  final String asOfLocalDate;
  final ValueChanged<LedgerEntry>? onEntryTap;
  final VoidCallback? onChooseMonth;
  final String? initialDate, initialCategoryId;
  final EntryKind? initialKind;
  @override
  State<LedgerListPage> createState() => _LedgerListPageState();
}

class _LedgerListPageState extends State<LedgerListPage> {
  final _search = TextEditingController();
  EntryKind? _kind;
  String? _categoryId, _from, _to;
  int? _min, _max;
  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _categoryId = widget.initialCategoryId;
    _from = widget.initialDate;
    _to = widget.initialDate;
  }

  @override
  void didUpdateWidget(covariant LedgerListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.month != widget.data.month) {
      _from = null;
      _to = null;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _range() async {
    final month = widget.data.month;
    final end = DateTime.utc(month.year, month.month, month.days);
    final last = end.isAfter(parseCalendarDay(widget.asOfLocalDate))
        ? parseCalendarDay(widget.asOfLocalDate)
        : end;
    final first = DateTime(month.year, month.month, 1);
    if (last.isBefore(first)) return;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: DateTime(last.year, last.month, last.day),
      helpText: '筛选当前月份日期',
      saveText: '确定',
    );
    if (picked != null && mounted) {
      setState(() {
        _from = calendarDayKey(picked.start);
        _to = calendarDayKey(picked.end);
      });
    }
  }

  Future<void> _advanced() async {
    final min = TextEditingController(
      text: _min == null ? '' : Money.fromFen(_min!).decimal,
    );
    final max = TextEditingController(
      text: _max == null ? '' : Money.fromFen(_max!).decimal,
    );
    var category = _categoryId;
    String? error;
    final ok = await showCompletedBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(sheet).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('分类与金额筛选', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '分类（包含细分类）'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部分类')),
                  for (final c in widget.data.categories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        categoryPath(c, widget.data.categories),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setSheet(() => category = v == '' ? null : v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: min,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '最低金额（元，选填）'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: max,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '最高金额（元，选填）'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(sheet).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  try {
                    final low = min.text.trim().isEmpty
                        ? null
                        : Money.parse(min.text).fen;
                    final high = max.text.trim().isEmpty
                        ? null
                        : Money.parse(max.text).fen;
                    if (low != null && high != null && low > high) {
                      throw const FormatException('最低金额不能高于最高金额');
                    }
                    _min = low;
                    _max = high;
                    _categoryId = category;
                    Navigator.pop(sheet, true);
                  } on FormatException catch (e) {
                    setSheet(() => error = e.message);
                  }
                },
                child: const Text('应用筛选'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
    min.dispose();
    max.dispose();
    if (ok == true && mounted) setState(() {});
  }

  void _clear() => setState(() {
    _search.clear();
    _kind = null;
    _categoryId = null;
    _from = null;
    _to = null;
    _min = null;
    _max = null;
  });
  @override
  Widget build(BuildContext context) {
    final view = widget.query.filter(
      widget.data,
      LedgerFilter(
        query: _search.text,
        kind: _kind,
        categoryId: _categoryId,
        fromDate: _from,
        toDate: _to,
        minFen: _min,
        maxFen: _max,
      ),
      asOfLocalDate: widget.asOfLocalDate,
    );
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单'),
        actions: [
          TextButton(
            onPressed: widget.onChooseMonth,
            child: Text(
              '${widget.data.month.year}年${widget.data.month.month}月 ▾',
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '搜索备注或分类',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: _kind == null,
                          onSelected: (_) => setState(() => _kind = null),
                        ),
                        ChoiceChip(
                          label: const Text('支出'),
                          selected: _kind == EntryKind.expense,
                          onSelected: (_) =>
                              setState(() => _kind = EntryKind.expense),
                        ),
                        ChoiceChip(
                          label: const Text('收入'),
                          selected: _kind == EntryKind.income,
                          onSelected: (_) =>
                              setState(() => _kind = EntryKind.income),
                        ),
                        ActionChip(
                          label: const Text('分类 / 金额'),
                          onPressed: _advanced,
                        ),
                        ActionChip(
                          label: Text(_from == null ? '日期' : '$_from 至 $_to'),
                          onPressed: _range,
                        ),
                        if (_search.text.isNotEmpty ||
                            _kind != null ||
                            _categoryId != null ||
                            _from != null ||
                            _min != null ||
                            _max != null)
                          ActionChip(
                            label: const Text('清除筛选'),
                            onPressed: _clear,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MetricGrid(
                      values: [
                        ('筛选支出', view.expense),
                        ('筛选收入', view.income),
                        ('收支差额', view.netFlow),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '共 ${view.entries.length} 笔 · 差额不是账户余额',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (view.entries.isEmpty)
              const SliverToBoxAdapter(child: StatusPanel(title: '没有符合条件的账单'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: view.entries.length,
                  itemBuilder: (context, i) {
                    final e = view.entries[i];
                    final start =
                        i == 0 || e.localDate != view.entries[i - 1].localDate;
                    final totals = view.days[e.localDate]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (start)
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  e.localDate,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  '支出 ${totals.expense.yuan} · 收入 ${totals.income.yuan} · ${totals.count}笔',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        EntryTile(
                          entry: e,
                          categories: widget.data.categories,
                          onTap: widget.onEntryTap == null
                              ? null
                              : () => widget.onEntryTap!(e),
                        ),
                        const Divider(height: 1),
                      ],
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
