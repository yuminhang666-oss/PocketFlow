import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/completed_modal.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/metric_grid.dart';
import '../../../shared/widgets/status_panel.dart';
import '../../../shared/widgets/presentation_errors.dart';

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
  });
  final LedgerMonthData? data;
  final CalendarMonth? month;
  final bool loading, drillDown;
  final Object? readError;
  final VoidCallback? onRetry, onAdd;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, widget.drillDown ? "筛选明细" : "账单")),
        actions: [
          TextButton(
            onPressed: widget.onChooseMonth,
            child: Text(tr(context, "{0}年{1}月 ▾", [_month.year, _month.month])),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_monthNotice)
                      Text(tr(context, "切换月份后保留分类、收支、搜索和金额条件，日期范围已重置")),
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
                            onDeleted: () => setState(() => _categoryId = null),
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
                            label: Text(tr(context, "{0} 至 {1}", [_from, _to])),
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
                    const SizedBox(height: 10),
                    if (view != null) ...[
                      MetricGrid(
                        values: [
                          (tr(context, "筛选支出"), view.expense),
                          (tr(context, "筛选收入"), view.income),
                          (tr(context, "收支差额"), view.netFlow),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          tr(context, "共 {0} 笔 · 差额不是账户余额", [
                            view.entries.length,
                          ]),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.readError != null)
              SliverToBoxAdapter(
                child: StatusPanel(
                  title: tr(context, "无法读取账单"),
                  message: tr(context, presentationError(widget.readError!)),
                  actionLabel: tr(context, "重试"),
                  onAction: widget.onRetry,
                ),
              )
            else if (view == null)
              SliverToBoxAdapter(
                child: StatusPanel(title: tr(context, "正在读取账本"), loading: true),
              )
            else if (view.entries.isEmpty)
              SliverToBoxAdapter(
                child: StatusPanel(
                  title: tr(context, _filtered ? "没有符合条件的账单" : "本月还没有记录"),
                  actionLabel: tr(context, _filtered ? "清除筛选" : "记第一笔"),
                  onAction: _filtered ? _clear : widget.onAdd,
                ),
              )
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
                                  tr(context, "支出 {0} · 收入 {1} · {2}笔", [
                                    totals.expense.yuan,
                                    totals.income.yuan,
                                    totals.count,
                                  ]),
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
                          categories: _categories,
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
