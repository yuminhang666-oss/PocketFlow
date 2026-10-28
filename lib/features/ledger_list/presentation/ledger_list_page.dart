import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/completed_modal.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/metric_grid.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/status_panel.dart';
import '../../../shared/widgets/presentation_errors.dart';
import 'ledger_calendar_page.dart';

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
    this.month,
    this.loading = false,
    this.readError,
    this.onRetry,
    this.onAdd,
    this.drillDown = false,
    this.onMoveMonth,
    this.onCurrentMonth,
    this.onMarkZero,
    this.onAddDay,
  });
  final LedgerMonthData? data;
  final CalendarMonth? month;
  final bool loading, drillDown;
  final ValueChanged<CalendarMonth>? onMoveMonth;
  final VoidCallback? onCurrentMonth;
  final Future<void> Function(String, bool)? onMarkZero;
  final ValueChanged<String>? onAddDay;
  final Object? readError;
  final VoidCallback? onRetry, onAdd;
  final LedgerQueryService query;
  final String asOfLocalDate;
  final ValueChanged<LedgerEntry>? onEntryTap;
  final VoidCallback? onChooseMonth;
  final String? initialDate, initialCategoryId;
  final EntryKind? initialKind;
  @override
  State<LedgerListPage> createState() => LedgerListPageState();
}

class LedgerListPageState extends State<LedgerListPage> {
  bool _calendar = false, _filters = false;
  String? _calendarDate;
  void showList() {
    if (mounted) setState(() => _calendar = false);
  }

  void resetToMonth({bool calendar = false}) {
    _clear();
    setState(() {
      _calendar = calendar;
      _filters = false;
      _monthNotice = false;
      _calendarDate = widget.asOfLocalDate;
    });
  }

  final _search = TextEditingController();
  EntryKind? _kind;
  String? _categoryId, _from, _to;
  int? _min, _max;
  bool _monthNotice = false;
  final _scroll = ScrollController();
  double? _restoreOffset;
  List<Category> _categories = const [];
  CalendarMonth get _month => widget.month ?? widget.data!.month;
  bool get _filtered =>
      _search.text.isNotEmpty ||
      _kind != null ||
      _categoryId != null ||
      _from != null ||
      _min != null ||
      _max != null;
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
    if ((oldWidget.month ?? oldWidget.data?.month) != _month) {
      _from = null;
      _to = null;
      _monthNotice = true;
      _restoreOffset = null;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else if ((widget.loading || widget.readError != null) &&
        _restoreOffset == null &&
        _scroll.hasClients) {
      _restoreOffset = _scroll.offset;
    } else if (!widget.loading &&
        widget.readError == null &&
        _restoreOffset != null) {
      final offset = _restoreOffset!;
      _restoreOffset = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
        }
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _range() async {
    final month = _month;
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
      helpText: tr(context, "筛选当前月份日期"),
      saveText: tr(context, "确定"),
      initialDateRange: _from == null || _to == null
          ? null
          : DateTimeRange(
              start: parseCalendarDay(_from!),
              end: parseCalendarDay(_to!),
            ),
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
              Text(
                tr(context, "分类与金额筛选"),
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category ?? '',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(context, "分类（包含细分类）"),
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text(tr(context, "全部分类"))),
                  for (final c in _categories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        localizedCategoryPath(context, c, _categories),
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
                decoration: InputDecoration(
                  labelText: tr(context, "最低金额（元，选填）"),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: max,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: tr(context, "最高金额（元，选填）"),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    tr(context, error!),
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
                      throw FormatException(tr(context, "最低金额不能高于最高金额"));
                    }
                    _min = low;
                    _max = high;
                    _categoryId = category;
                    Navigator.pop(sheet, true);
                  } on FormatException catch (e) {
                    setSheet(() => error = e.message);
                  }
                },
                child: Text(tr(context, "应用筛选")),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                child: Text(tr(context, "取消")),
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
    final data = widget.data;
    if (data != null) _categories = data.categories;
    final selectedCategory = _categories
        .where((c) => c.id == _categoryId)
        .firstOrNull;
    final view =
        data == null ||
            data.month != _month ||
            widget.loading ||
            widget.readError != null
        ? null
        : widget.query.filter(
            data,
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
    final historical =
        _month !=
        CalendarMonth.fromDate(parseCalendarDay(widget.asOfLocalDate));
    void move(int delta) {
      final date = DateTime.utc(_month.year, _month.month + delta);
      if (date.year >= 1900 && date.year <= 9999) {
        widget.onMoveMonth?.call(CalendarMonth.fromDate(date));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, widget.drillDown ? '筛选明细' : '账单')),
        actions: [
          IconButton(
            tooltip: tr(context, '搜索与筛选'),
            isSelected: _filters,
            onPressed: () => setState(() => _filters = !_filters),
            icon: Icon(_filtered ? Icons.filter_alt : Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (!widget.drillDown)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Center(
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(tr(context, '列表')),
                          icon: const Icon(Icons.view_list_outlined),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(tr(context, '日历')),
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ],
                      selected: {_calendar},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        ScaffoldMessenger.of(context).removeCurrentSnackBar();
                        setState(() => _calendar = value.single);
                      },
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Column(
                      children: [
                        if (historical)
                          Text(
                            tr(context, '查看月份'),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: tr(context, '上月'),
                              onPressed: widget.onMoveMonth == null
                                  ? null
                                  : () => move(-1),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: widget.onChooseMonth,
                                child: Text(
                                  tr(context, '{0}年{1}月 ▾', [
                                    _month.year,
                                    _month.month,
                                  ]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: tr(context, '下月'),
                              onPressed: widget.onMoveMonth == null
                                  ? null
                                  : () => move(1),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        if (historical)
                          TextButton(
                            onPressed: () {
                              _calendarDate = widget.asOfLocalDate;
                              widget.onCurrentMonth?.call();
                            },
                            child: Text(tr(context, '回到本月')),
                          ),
                        if (view != null && _calendar)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    Text(tr(context, '支出')),
                                    AmountText(
                                      view.expense,
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: flowColor(
                                          context,
                                          EntryKind.expense,
                                          amount: view.expense,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    Text(tr(context, '收入')),
                                    AmountText(
                                      view.income,
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: flowColor(
                                          context,
                                          EntryKind.income,
                                          amount: view.income,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (view != null && !_calendar)
                          MetricGrid(
                            compact: true,
                            values: [
                              (
                                tr(context, _filtered ? '筛选支出' : '支出'),
                                view.expense,
                              ),
                              (
                                tr(context, _filtered ? '筛选收入' : '收入'),
                                view.income,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_filters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: tr(context, "搜索备注或分类"),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          ChoiceChip(
                            label: Text(tr(context, "全部")),
                            selected: _kind == null,
                            onSelected: (_) => setState(() => _kind = null),
                          ),
                          ChoiceChip(
                            label: Text(tr(context, "支出")),
                            selected: _kind == EntryKind.expense,
                            onSelected: (_) =>
                                setState(() => _kind = EntryKind.expense),
                          ),
                          ChoiceChip(
                            label: Text(tr(context, "收入")),
                            selected: _kind == EntryKind.income,
                            onSelected: (_) =>
                                setState(() => _kind = EntryKind.income),
                          ),
                          ActionChip(
                            label: Text(tr(context, "分类 / 金额")),
                            onPressed: _advanced,
                          ),
                          ActionChip(
                            label: Text(
                              _from == null
                                  ? tr(context, "日期")
                                  : tr(context, "{0} 至 {1}", [_from, _to]),
                            ),
                            onPressed: _range,
                          ),
                          if (_search.text.isNotEmpty ||
                              _kind != null ||
                              _categoryId != null ||
                              _from != null ||
                              _min != null ||
                              _max != null)
                            ActionChip(
                              label: Text(tr(context, "清除筛选")),
                              onPressed: _clear,
                            ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (_categoryId != null)
                            InputChip(
                              label: Text(
                                tr(context, "分类：{0}", [
                                  selectedCategory != null
                                      ? localizedCategoryPath(
                                          context,
                                          selectedCategory,
                                          _categories,
                                        )
                                      : tr(context, "未识别分类"),
                                ]),
                              ),
                              onDeleted: () =>
                                  setState(() => _categoryId = null),
                            ),
                          if (_min != null)
                            InputChip(
                              label: Text(
                                tr(context, "最低 {0}", [
                                  Money.fromFen(_min!).yuan,
                                ]),
                              ),
                              onDeleted: () => setState(() => _min = null),
                            ),
                          if (_max != null)
                            InputChip(
                              label: Text(
                                tr(context, "最高 {0}", [
                                  Money.fromFen(_max!).yuan,
                                ]),
                              ),
                              onDeleted: () => setState(() => _max = null),
                            ),
                          if (_from != null)
                            InputChip(
                              label: Text(
                                tr(context, "{0} 至 {1}", [_from, _to]),
                              ),
                              onDeleted: () => setState(() {
                                _from = null;
                                _to = null;
                              }),
                            ),
                          if (_kind != null)
                            InputChip(
                              label: Text(
                                tr(
                                  context,
                                  _kind == EntryKind.expense ? "支出" : "收入",
                                ),
                              ),
                              onDeleted: () => setState(() => _kind = null),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (view != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_monthNotice && _filtered)
                        Text(
                          tr(context, '切换月份后保留分类、收支、搜索和金额条件，日期范围已重置'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (_filtered && !_filters)
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              tr(context, '已启用筛选'),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            if (_search.text.isNotEmpty) Text(_search.text),
                            if (_kind != null)
                              Text(
                                tr(
                                  context,
                                  _kind == EntryKind.expense ? '支出' : '收入',
                                ),
                              ),
                            if (selectedCategory != null)
                              Text(
                                localizedCategoryPath(
                                  context,
                                  selectedCategory,
                                  _categories,
                                ),
                              ),
                            if (_from != null)
                              Text(tr(context, '{0} 至 {1}', [_from, _to])),
                            if (_min != null)
                              Text(
                                tr(context, '最低 {0}', [
                                  Money.fromFen(_min!).yuan,
                                ]),
                              ),
                            if (_max != null)
                              Text(
                                tr(context, '最高 {0}', [
                                  Money.fromFen(_max!).yuan,
                                ]),
                              ),
                            TextButton(
                              onPressed: _clear,
                              child: Text(tr(context, '清除筛选')),
                            ),
                          ],
                        ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          Text(
                            tr(context, '当前范围共 {0} 笔', [view.entries.length]),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Wrap(
                            spacing: 4,
                            children: [
                              Text(
                                tr(context, '净收支'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              AmountText(
                                view.netFlow,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: flowColor(
                                        context,
                                        view.netFlow.fen < 0
                                            ? EntryKind.expense
                                            : EntryKind.income,
                                        amount: view.netFlow,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.readError != null)
              SliverToBoxAdapter(
                child: StatusPanel(
                  title: tr(context, '无法读取账单'),
                  message: tr(context, presentationError(widget.readError!)),
                  actionLabel: tr(context, '重试'),
                  onAction: widget.onRetry,
                ),
              )
            else if (view == null)
              SliverToBoxAdapter(
                child: StatusPanel(title: tr(context, '正在读取账本'), loading: true),
              )
            else if (_calendar && widget.onMarkZero != null)
              SliverToBoxAdapter(
                child: LedgerCalendarPage(
                  embedded: true,
                  selectedDate: _calendarDate,
                  onSelectedDate: (d) => _calendarDate = d,
                  data: data!,
                  view: view,
                  today: widget.asOfLocalDate,
                  onOpenDay: (_) {},
                  onMarkZero: widget.onMarkZero!,
                  onAddDay: widget.onAddDay,
                  onEntryTap: widget.onEntryTap,
                  onMoveMonth: widget.onMoveMonth,
                ),
              )
            else if (view.entries.isEmpty)
              SliverToBoxAdapter(
                child: StatusPanel(
                  title: tr(context, _filtered ? '没有符合条件的账单' : '本月还没有记录'),
                  actionLabel: tr(context, _filtered ? '清除筛选' : '记第一笔'),
                  onAction: _filtered ? _clear : widget.onAdd,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: view.days.length,
                  itemBuilder: (context, i) {
                    final day = view.days.keys.toList()
                      ..sort((a, b) => b.compareTo(a));
                    final date = day[i], totals = view.days[date]!;
                    final entries = view.entries
                        .where((e) => e.localDate == date)
                        .toList();
                    return Card(
                      key: ValueKey('ledger-day-$date'),
                      margin: const EdgeInsets.only(bottom: 10),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: scheme.surfaceContainerLow,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  date,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  tr(context, '支出 {0} · 收入 {1}', [
                                    totals.expense.yuan,
                                    totals.income.yuan,
                                  ]),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              children: [
                                for (var j = 0; j < entries.length; j++) ...[
                                  if (j > 0) const Divider(height: 1),
                                  EntryTile(
                                    compact: true,
                                    entry: entries[j],
                                    categories: _categories,
                                    onTap: widget.onEntryTap == null
                                        ? null
                                        : () => widget.onEntryTap!(entries[j]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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
