import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../contracts/contracts.dart';
import '../../../core/domain/category_catalog.dart';
import '../../../shared/widgets/presentation_errors.dart';
import '../../reports/domain/range_report_service.dart';
import '../../transactions/data/entry_id.dart';

Future<bool> confirmPlanningAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr(context, "取消")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr(context, "确认")),
          ),
        ],
      ),
    ) ??
    false;
Future<Money?> editPlanningAmount(
  BuildContext context,
  String title, {
  Money? initial,
}) async {
  final input = TextEditingController(text: initial?.decimal ?? '');
  String? error;
  final result = await showDialog<Money>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '¥ ',
            errorText: error == null ? null : tr(d, error!),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(tr(context, "取消")),
          ),
          FilledButton(
            onPressed: () {
              try {
                Navigator.pop(d, Money.parse(input.text));
              } on FormatException catch (e) {
                set(() => error = e.message);
              }
            },
            child: Text(tr(context, "保存")),
          ),
        ],
      ),
    ),
  );
  // Dialog route disposal can finish after this Future; defer controller disposal.
  WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
  return result;
}

void _error(BuildContext c, Object e) {
  if (c.mounted) {
    ScaffoldMessenger.of(
      c,
    ).showSnackBar(SnackBar(content: Text(tr(c, presentationError(e)))));
  }
}

class CategoryBudgetsPage extends StatelessWidget {
  const CategoryBudgetsPage({
    super.key,
    required this.data,
    required this.port,
    required this.today,
    required this.onTotalBudget,
  });
  final LedgerMonthData data;
  final PlanningPort port;
  final DateTime today;
  final VoidCallback onTotalBudget;
  @override
  Widget build(BuildContext context) {
    final planned = data.categoryBudgets.fold<int>(
          0,
          (a, b) => a + b.amount.fen,
        ),
        total = data.budget?.amount;
    final expense = rootBreakdown(
      data.entries.where(
        (e) => e.localDate.compareTo(calendarDayKey(today)) <= 0,
      ),
      data.categories,
    );
    final spent = {for (final e in expense) e.categoryId: e.amount.fen};
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, "{0} 预算计划", [data.month.key]))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(context, "总预算 {0}", [total?.yuan ?? tr(context, "未设置")]),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, "分类预算只显示计划进度；总预算是剩余额度的唯一来源。"),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: onTotalBudget,
                        child: Text(tr(context, "设置总预算")),
                      ),
                      if (total != null)
                        TextButton(
                          onPressed: () async {
                            if (await confirmPlanningAction(
                              context,
                              tr(context, "清除总预算？"),
                              tr(context, "仅清除本月额度，不删除账目和分类计划。"),
                            )) {
                              try {
                                await port.clearBudget(data.month);
                              } catch (e) {
                                if (context.mounted) _error(context, e);
                              }
                            }
                          },
                          child: Text(tr(context, "清除总预算")),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    tr(context, "分类计划合计 {0}", [Money.fromFen(planned).yuan]),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (total != null)
                    Text(
                      planned > total.fen
                          ? tr(context, "分类计划超出总预算 {0}", [
                              Money.fromFen(planned - total.fen).yuan,
                            ])
                          : tr(context, "未分配 {0}", [
                              Money.fromFen(total.fen - planned).yuan,
                            ]),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(tr(context, "复制上月分类预算")),
                    onPressed: () async {
                      if (!await confirmPlanningAction(
                        context,
                        tr(context, "复制上月计划？"),
                        tr(context, "同分类的本月计划将被覆盖，只复制仍可用的支出根类。"),
                      )) {
                        return;
                      }
                      try {
                        await port.copyCategoryBudgets(
                          CalendarMonth.fromDate(
                            DateTime.utc(data.month.year, data.month.month - 1),
                          ),
                          data.month,
                        );
                      } catch (e) {
                        if (context.mounted) _error(context, e);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final c in data.categories.where(
            (c) =>
                c.parentId == null &&
                c.kind != EntryKind.income &&
                (!c.isArchived ||
                    data.categoryBudgets.any((b) => b.categoryId == c.id)),
          ))
            Builder(
              builder: (context) {
                final budget = data.categoryBudgets
                    .where((b) => b.categoryId == c.id)
                    .firstOrNull
                    ?.amount;
                final used =
                    data.month.compareTo(CalendarMonth.fromDate(today)) > 0
                    ? 0
                    : spent[c.id] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: Text(
                        tr(context, "{0}{1}", [
                          localizedCategoryName(context, c),
                          c.isArchived ? tr(context, "（已归档）") : '',
                        ]),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tr(context, "已用 {0} / {1}{2}", [
                              Money.fromFen(used).yuan,
                              budget?.yuan ?? tr(context, "未设置"),
                              budget != null && used > budget.fen
                                  ? tr(context, " · 已超出计划")
                                  : '',
                            ]),
                          ),
                          if (budget != null && budget.fen > 0) ...[
                            const SizedBox(height: 8),
                            Semantics(
                              label: tr(context, "预算已用百分之{0}", [
                                (used / budget.fen * 100).toStringAsFixed(0),
                              ]),
                              child: LinearProgressIndicator(
                                value: (used / budget.fen).clamp(0.0, 1.0),
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(4),
                                color: used > budget.fen
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Wrap(
                        children: [
                          if (!c.isArchived)
                            IconButton(
                              tooltip: tr(context, "设置{0}预算", [
                                localizedCategoryName(context, c),
                              ]),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                final amount = await editPlanningAmount(
                                  context,
                                  tr(context, "{0}分类预算", [
                                    localizedCategoryName(context, c),
                                  ]),
                                  initial: budget,
                                );
                                if (amount != null) {
                                  try {
                                    await port.saveCategoryBudget(
                                      CategoryBudget(
                                        month: data.month,
                                        categoryId: c.id,
                                        amount: amount,
                                      ),
                                    );
                                  } catch (e) {
                                    if (context.mounted) _error(context, e);
                                  }
                                }
                              },
                            ),
                          if (budget != null)
                            IconButton(
                              tooltip: tr(context, "清除{0}预算", [
                                localizedCategoryName(context, c),
                              ]),
                              icon: const Icon(Icons.clear),
                              onPressed: () async {
                                if (await confirmPlanningAction(
                                  context,
                                  tr(context, "清除分类预算？"),
                                  tr(context, "仅清除{0}本月计划。", [
                                    localizedCategoryName(context, c),
                                  ]),
                                )) {
                                  try {
                                    await port.clearCategoryBudget(
                                      data.month,
                                      c.id,
                                    );
                                  } catch (e) {
                                    if (context.mounted) _error(context, e);
                                  }
                                }
                              },
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
    );
  }
}

class RecurringPlansPage extends StatefulWidget {
  const RecurringPlansPage({
    super.key,
    required this.port,
    required this.categories,
    required this.clock,
  });
  final PlanningPort port;
  final List<Category> categories;
  final Clock clock;
  @override
  State<RecurringPlansPage> createState() => _RecurringPlansPageState();
}

class _RecurringPlansPageState extends State<RecurringPlansPage> {
  late CalendarMonth month = CalendarMonth.fromDate(widget.clock.now());
  late final Stream<PlanningData> stream = widget.port.watchPlans();
  bool busy = false;
  Future<void> action(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editor([RecurringVersion? version]) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RecurringRuleEditor(
            port: widget.port,
            categories: widget.categories,
            clock: widget.clock,
            initial: version,
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, "周期账单与收入")),
      actions: [
        IconButton(
          tooltip: tr(context, "新增月度规则"),
          onPressed: busy ? null : () => editor(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: StreamBuilder<PlanningData>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) {
          return Center(child: Text(tr(context, presentationError(s.error!))));
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final p = s.data!, now = calendarDay(widget.clock.now());
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr(context, "待办不会自动入账。只有确认后才计入收支；未确认收入不增加预算。")),
            Row(
              children: [
                IconButton(
                  tooltip: tr(context, "上月"),
                  onPressed: () => setState(
                    () => month = CalendarMonth.fromDate(
                      DateTime.utc(month.year, month.month - 1),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(child: Text(month.key, textAlign: TextAlign.center)),
                IconButton(
                  tooltip: tr(context, "下月"),
                  onPressed: () => setState(
                    () => month = CalendarMonth.fromDate(
                      DateTime.utc(month.year, month.month + 1),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            for (final item in [
              for (final period in [
                month,
                if (month == CalendarMonth.fromDate(now))
                  CalendarMonth.fromDate(
                    DateTime.utc(month.year, month.month + 1),
                  ),
              ])
                for (final rule in p.rules) (period, rule),
            ])
              Builder(
                builder: (context) {
                  final month = item.$1, rule = item.$2;
                  final v = p.versionFor(rule.id, month);
                  if (v == null || !v.applies(month)) {
                    return const SizedBox.shrink();
                  }
                  final occurrence = p.occurrences
                      .where((o) => o.ruleId == rule.id && o.period == month)
                      .firstOrNull;
                  final due = parseCalendarDay(v.dueDate(month)),
                      pending = PendingOccurrence(v, month),
                      future = due.isAfter(now);
                  final visible = !now.isBefore(
                    due.subtract(Duration(days: v.leadDays)),
                  );
                  if (month != this.month &&
                      (!visible ||
                          due.isAfter(now.add(const Duration(days: 7))))) {
                    return const SizedBox.shrink();
                  }
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tr(context, "{0} · {1} · {2}", [
                              v.kind == EntryKind.income
                                  ? tr(context, "收入")
                                  : tr(context, "支出"),
                              v.amount.yuan,
                              v.dueDate(month),
                            ]),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${localizedCategoryById(context, v.categoryId, widget.categories)} · ${v.note}',
                          ),
                          Text(
                            occurrence == null
                                ? (future
                                      ? (visible
                                            ? tr(context, "未来7天待办")
                                            : tr(context, "尚未到提前展示日期"))
                                      : tr(context, "待处理"))
                                : (occurrence.status == OccurrenceStatus.settled
                                      ? tr(context, "已确认")
                                      : tr(context, "已跳过")),
                          ),
                          if (occurrence == null)
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: busy || future
                                      ? null
                                      : () => action(() async {
                                          final amount =
                                              await editPlanningAmount(
                                                context,
                                                tr(context, "确认实际{0}", [
                                                  v.kind == EntryKind.income
                                                      ? tr(context, "收入")
                                                      : tr(context, "支出"),
                                                ]),
                                                initial: v.amount,
                                              );
                                          if (amount != null) {
                                            await widget.port.confirm(
                                              pending,
                                              actualAmount: amount,
                                            );
                                          }
                                        }),
                                  child: Text(tr(context, "确认入账")),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => action(() async {
                                          if (await confirmPlanningAction(
                                            context,
                                            tr(context, "跳过本期？"),
                                            tr(context, "不会生成账目；以后可以主动恢复待处理。"),
                                          )) {
                                            await widget.port.skip(pending);
                                          }
                                        }),
                                  child: Text(tr(context, "跳过本期")),
                                ),
                              ],
                            ),
                          if (occurrence?.status == OccurrenceStatus.skipped)
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => action(() async {
                                      if (await confirmPlanningAction(
                                        context,
                                        tr(context, "恢复待处理？"),
                                        tr(context, "本期将重新显示待确认，不会自动入账。"),
                                      )) {
                                        await widget.port.reopen(
                                          rule.id,
                                          month,
                                        );
                                      }
                                    }),
                              child: Text(tr(context, "恢复待处理")),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const Divider(),
            Text(
              tr(context, "规则与版本"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (p.rules.isEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(tr(context, "还没有月度规则，可添加房租、订阅或固定收入。")),
              ),
            for (final rule in p.rules)
              Builder(
                builder: (context) {
                  final versions =
                      p.versions.where((v) => v.ruleId == rule.id).toList()
                        ..sort(
                          (a, b) =>
                              b.effectiveMonth.compareTo(a.effectiveMonth),
                        );
                  final latest = versions.first;
                  return ListTile(
                    title: Text(
                      tr(context, "{0} · 每月{1}日{2}{3}", [
                        latest.amount.yuan,
                        latest.day,
                        !latest.enabled ? tr(context, " · 已暂停") : '',
                        latest.archived ? tr(context, " · 已归档") : '',
                      ]),
                    ),
                    subtitle: Text(
                      tr(context, "最新版本从 {0} 生效", [latest.effectiveMonth.key]),
                    ),
                    trailing: IconButton(
                      tooltip: tr(context, "修改规则"),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: busy ? null : () => editor(latest),
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: Text(tr(context, "不可变规则版本")),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final v in versions)
                                ListTile(
                                  title: Text(
                                    '${v.effectiveMonth.key} · ${v.amount.yuan}',
                                  ),
                                  subtitle: Text(
                                    '${v.kind.name} · ${v.categoryId}\n${v.note}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d),
                            child: Text(tr(context, "关闭")),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    ),
  );
}

class RecurringRuleEditor extends StatefulWidget {
  const RecurringRuleEditor({
    super.key,
    required this.port,
    required this.categories,
    required this.clock,
    this.initial,
  });
  final PlanningPort port;
  final List<Category> categories;
  final Clock clock;
  final RecurringVersion? initial;
  @override
  State<RecurringRuleEditor> createState() => _RecurringRuleEditorState();
}

class _RecurringRuleEditorState extends State<RecurringRuleEditor> {
  late final amount = TextEditingController(
    text: widget.initial?.amount.decimal ?? '',
  );
  late final note = TextEditingController(text: widget.initial?.note ?? '');
  late final effective = TextEditingController(
    text: widget.initial == null
        ? CalendarMonth.fromDate(widget.clock.now()).key
        : CalendarMonth.fromDate(
            DateTime.utc(widget.clock.now().year, widget.clock.now().month + 1),
          ).key,
  );
  late final start = TextEditingController(
    text:
        widget.initial?.startMonth.key ??
        CalendarMonth.fromDate(widget.clock.now()).key,
  );
  late final end = TextEditingController(
    text: widget.initial?.endMonth?.key ?? '',
  );
  late EntryKind kind = widget.initial?.kind ?? EntryKind.expense;
  late String? category = widget.initial?.categoryId;
  late int day = widget.initial?.day ?? 1, lead = widget.initial?.leadDays ?? 7;
  late bool enabled = widget.initial?.enabled ?? true,
      archived = widget.initial?.archived ?? false;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in [amount, note, effective, start, end]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final v = RecurringVersion(
        id: newEntryId(),
        ruleId: widget.initial?.ruleId ?? newEntryId(),
        effectiveMonth: CalendarMonth.parse(effective.text),
        startMonth: CalendarMonth.parse(start.text),
        endMonth: end.text.trim().isEmpty
            ? null
            : CalendarMonth.parse(end.text),
        kind: kind,
        categoryId: category ?? '',
        amount: Money.parse(amount.text),
        day: day,
        leadDays: lead,
        note: note.text,
        enabled: enabled,
        archived: archived,
      );
      await widget.port.saveRuleVersion(v);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : tr(context, presentationError(e)),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.categories
        .where(
          (c) =>
              categoryAvailable(c, widget.categories, kind) ||
              c.id == widget.initial?.categoryId && c.accepts(kind),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? tr(context, "新增月度规则")
              : tr(context, "新建规则版本"),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(context, "修改默认下月生效；已处理期不会被改写。暂停或归档也按生效月份应用。")),
          DropdownButtonFormField<EntryKind>(
            initialValue: kind,
            items: [
              for (final k in EntryKind.values)
                DropdownMenuItem(
                  value: k,
                  child: Text(
                    k == EntryKind.expense
                        ? tr(context, "支出")
                        : tr(context, "收入"),
                  ),
                ),
            ],
            onChanged: saving
                ? null
                : (k) => setState(() {
                    kind = k!;
                    category = null;
                  }),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(kind),
            initialValue: options.any((c) => c.id == category)
                ? category
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr(context, "分类")),
            items: [
              for (final c in options)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    localizedCategoryPath(context, c, widget.categories),
                  ),
                ),
            ],
            onChanged: saving ? null : (v) => setState(() => category = v),
          ),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr(context, "每期金额（元）")),
          ),
          DropdownButtonFormField<int>(
            initialValue: day,
            decoration: InputDecoration(labelText: tr(context, "每月日期（短月取月末）")),
            items: [
              for (var i = 1; i <= 31; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(tr(context, "{0}日", [i])),
                ),
            ],
            onChanged: saving ? null : (v) => day = v!,
          ),
          DropdownButtonFormField<int>(
            initialValue: lead,
            decoration: InputDecoration(labelText: tr(context, "提前可见天数")),
            items: [
              for (var i = 0; i <= 31; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(tr(context, "{0}天", [i])),
                ),
            ],
            onChanged: saving ? null : (v) => lead = v!,
          ),
          TextField(
            controller: effective,
            decoration: InputDecoration(
              labelText: tr(context, "此版本生效月份 YYYY-MM"),
            ),
          ),
          TextField(
            controller: start,
            decoration: InputDecoration(
              labelText: tr(context, "规则起始月份 YYYY-MM"),
            ),
          ),
          TextField(
            controller: end,
            decoration: InputDecoration(labelText: tr(context, "终止月份（可留空）")),
          ),
          TextField(
            controller: note,
            maxLength: 500,
            decoration: InputDecoration(labelText: tr(context, "备注")),
          ),
          SwitchListTile(
            title: Text(tr(context, "启用")),
            value: enabled,
            onChanged: saving ? null : (v) => setState(() => enabled = v),
          ),
          SwitchListTile(
            title: Text(tr(context, "归档")),
            value: archived,
            onChanged: saving ? null : (v) => setState(() => archived = v),
          ),
          if (error != null)
            Text(
              tr(context, error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? tr(context, "保存中…") : tr(context, "保存规则版本")),
          ),
        ],
      ),
    );
  }
}

class RecoveryPointsPage extends StatefulWidget {
  const RecoveryPointsPage({
    super.key,
    required this.port,
    required this.backup,
  });
  final PlanningPort port;
  final BackupStore backup;
  @override
  State<RecoveryPointsPage> createState() => _RecoveryPointsPageState();
}

class _RecoveryPointsPageState extends State<RecoveryPointsPage> {
  late Future<List<RecoveryPoint>> load = widget.port.recoveryPoints();
  bool busy = false;
  Future<void> act(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          load = widget.port.recoveryPoints();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, "本地恢复点"))),
    body: FutureBuilder<List<RecoveryPoint>>(
      future: load,
      builder: (context, s) {
        if (s.hasError) {
          return Center(child: Text(tr(context, presentationError(s.error!))));
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final points = s.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr(
                context,
                "仅保留最近3个且不超过30天。恢复点位于App数据目录，会随卸载或清除数据丢失，不能替代外部JSON备份。",
              ),
            ),
            if (points.isEmpty) ListTile(title: Text(tr(context, "暂无本地恢复点"))),
            if (points.isNotEmpty)
              TextButton(
                onPressed: busy
                    ? null
                    : () => act(() async {
                        if (await confirmPlanningAction(
                          context,
                          tr(context, "清空所有恢复点？"),
                          tr(context, "将删除这 {0} 个内部恢复点，不删除账目。", [
                            points.length,
                          ]),
                        )) {
                          await widget.port.deleteRecoveryPoints(
                            points.map((p) => p.id).toList(),
                          );
                        }
                      }),
                child: Text(tr(context, "清空恢复点")),
              ),
            for (final point in points)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        DateTime.fromMillisecondsSinceEpoch(
                          point.createdAtUtcMs,
                        ).toString(),
                      ),
                      Text(
                        point.corrupted
                            ? tr(context, "此恢复点损坏，其他账目不受影响")
                            : tr(context, "{0}笔 · 编码v{1}", [
                                point.entries,
                                point.encodingVersion,
                              ]),
                      ),
                      Wrap(
                        children: [
                          if (!point.corrupted)
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => act(() async {
                                      final doc = await widget.port
                                          .readRecoveryPoint(point.id);
                                      if (!context.mounted) return;
                                      if (await confirmPlanningAction(
                                        context,
                                        tr(context, "恢复并完整替换？"),
                                        tr(
                                          context,
                                          "恢复点包含{0}笔账目、{1}个月预算、{2}条周期规则。导出时间：{3}。\n会替换财务数据，恢复前将保留当前账本的新恢复点。{4}",
                                          [
                                            doc.entries.length,
                                            doc.budgets.length,
                                            doc.plans.rules.length,
                                            DateTime.fromMillisecondsSinceEpoch(
                                              doc.exportedAtUtcMs,
                                            ),
                                            doc.sourceFormatVersion < 3
                                                ? tr(
                                                    context,
                                                    "旧版不含周期计划/分类预算，替换后将为空。",
                                                  )
                                                : '',
                                          ],
                                        ),
                                      )) {
                                        await widget.backup.replaceAll(doc);
                                      }
                                    }),
                              child: Text(tr(context, "预检并恢复")),
                            ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => act(() async {
                                    if (await confirmPlanningAction(
                                      context,
                                      tr(context, "删除这个恢复点？"),
                                      tr(context, "仅删除所选内部恢复点。"),
                                    )) {
                                      await widget.port.deleteRecoveryPoints([
                                        point.id,
                                      ]);
                                    }
                                  }),
                            child: Text(tr(context, "删除")),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class ReminderSettingsPage extends StatelessWidget {
  const ReminderSettingsPage({super.key, required this.port});
  final PlanningPort port;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, "提醒与记账偏好"))),
    body: StreamBuilder<PlanningData>(
      stream: port.watchPlans(),
      builder: (context, s) {
        if (s.hasError) {
          return Center(child: Text(tr(context, presentationError(s.error!))));
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final settings = s.data!.settings;
        return ListView(
          children: [
            SwitchListTile(
              title: Text(tr(context, "预算进度提醒")),
              subtitle: Text(tr(context, "每月最多2次，至少相隔7天，仅应用内显示")),
              value: settings.budget,
              onChanged: (v) async {
                try {
                  await port.saveReminderSettings(
                    ReminderSettings(budget: v, weekly: settings.weekly),
                  );
                } catch (e) {
                  if (context.mounted) _error(context, e);
                }
              },
            ),
            SwitchListTile(
              title: Text(tr(context, "自动显示周报")),
              subtitle: Text(tr(context, "周一08:00后首次打开时提示，不发后台通知")),
              value: settings.weekly,
              onChanged: (v) async {
                try {
                  await port.saveReminderSettings(
                    ReminderSettings(budget: settings.budget, weekly: v),
                  );
                } catch (e) {
                  if (context.mounted) _error(context, e);
                }
              },
            ),
            for (final kind in EntryKind.values)
              ListTile(
                title: Text(
                  tr(context, "清空{0}最近分类", [
                    kind == EntryKind.expense
                        ? tr(context, "支出")
                        : tr(context, "收入"),
                  ]),
                ),
                onTap: () async {
                  try {
                    await port.clearRecentCategory(kind);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr(context, "已清空最近分类"))),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) _error(context, e);
                  }
                },
              ),
          ],
        );
      },
    ),
  );
}
