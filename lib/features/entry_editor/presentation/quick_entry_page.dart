import 'dart:async';
import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/completed_modal.dart';
import 'package:flutter/services.dart';
import '../../../contracts/contracts.dart';
import '../../../core/domain/category_catalog.dart';
import '../../../shared/widgets/presentation_errors.dart';
import 'amount_buffer.dart';
import 'widgets/amount_keypad.dart';
import 'widgets/category_selector.dart';
import 'widgets/note_editor.dart';

class QuickEntryPage extends StatefulWidget {
  const QuickEntryPage({
    super.key,
    required this.categories,
    required this.onSave,
    this.onSaveIncome,
    this.onAddRecommended,
    this.onSaveTemplate,
    this.clock = const SystemClock(),
    this.initialEntry,
    this.template,
    this.profile,
    this.initialKind = EntryKind.expense,
    this.initialDate,
    this.onUndo,
  });
  final List<Category> categories;
  final Future<LedgerEntry> Function(EntryDraft) onSave;
  final Future<LedgerEntry> Function(EntryDraft)? onSaveIncome;
  final Future<void> Function()? onAddRecommended;
  final Future<void> Function(EntryTemplate)? onSaveTemplate;
  final Clock clock;
  final LedgerEntry? initialEntry;
  final EntryTemplate? template;
  final PersonalProfile? profile;
  final EntryKind initialKind;
  final String? initialDate;
  final Future<void> Function(LedgerEntry)? onUndo;
  @override
  State<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends State<QuickEntryPage> {
  final _amount = AmountBuffer();
  late DateTime _date;
  late TimeOfDay _time;
  late EntryKind _kind;
  String? _categoryId;
  String _note = '';
  String? _error;
  String? _notice;
  bool _saving = false, _allowPop = false, _confirming = false;
  String _cleanAmount = '', _cleanNote = '';
  String? _cleanCategory;
  late DateTime _cleanDate;
  LedgerEntry? _undoEntry;
  Timer? _undoExpiry;
  String? _savedFeedback;
  bool _undoing = false;
  final _selectedByKind = <EntryKind, String?>{};
  int _savedCount = 0;

  List<Category> get _available => widget.categories
      .where(
        (c) =>
            (categoryAvailable(c, widget.categories, _kind) &&
                (_kind == EntryKind.expense ||
                    c.kind == EntryKind.income ||
                    c.id == widget.initialEntry?.categoryId)) ||
            c.id == widget.initialEntry?.categoryId,
      )
      .toList();
  bool get _dirty =>
      _amount.value != _cleanAmount ||
      _note != _cleanNote ||
      _categoryId != _cleanCategory ||
      _date != _cleanDate;
  void _markClean() {
    _cleanAmount = _amount.value;
    _cleanNote = _note;
    _cleanCategory = _categoryId;
    _cleanDate = _date;
  }

  void _defaultCategory([String? preferred]) {
    final stored = _kind == EntryKind.expense
        ? widget.profile?.lastExpenseCategoryId
        : widget.profile?.lastIncomeCategoryId;
    final options = _available;
    if ((preferred ?? stored) != null &&
        !options.any((c) => c.id == (preferred ?? stored))) {
      _categoryId = null;
      _error = "最近分类已归档或不可用，请重新选择分类";
      return;
    }
    _categoryId =
        options.where((c) => c.id == (preferred ?? stored)).firstOrNull?.id ??
        options
            .where(
              (c) =>
                  c.id ==
                  (_kind == EntryKind.expense ? 'food' : 'income_family'),
            )
            .firstOrNull
            ?.id ??
        options.firstOrNull?.id;
  }

  @override
  void initState() {
    super.initState();
    final now = widget.clock.now(),
        initial = widget.initialEntry,
        t = widget.template;
    _kind = initial?.kind ?? t?.kind ?? widget.initialKind;
    _amount.value = initial?.amount.decimal ?? t?.amount.decimal ?? '';
    _note = initial?.note ?? t?.note ?? '';
    _date =
        initial?.date ??
        (widget.initialDate == null
            ? calendarDay(now)
            : parseCalendarDay(widget.initialDate!));
    _time = TimeOfDay.fromDateTime(
      initial == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(initial.occurredAtUtcMs),
    );
    _defaultCategory(initial?.categoryId ?? t?.categoryId);
    if (t != null && !_available.any((c) => c.id == t.categoryId)) {
      _categoryId = null;
      _error = "模板分类已归档或不可用，请重新选择分类";
    }
    final recent = _kind == EntryKind.expense
        ? widget.profile?.lastExpenseCategoryId
        : widget.profile?.lastIncomeCategoryId;
    if (initial == null &&
        t == null &&
        recent != null &&
        !_available.any((c) => c.id == recent)) {
      _categoryId = null;
      _error = "最近分类已归档或不可用，请重新选择分类";
    }
    _markClean();
  }

  @override
  void didUpdateWidget(covariant QuickEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_categoryId != null && !_available.any((c) => c.id == _categoryId)) {
      _categoryId = null;
      _error = tr(context, "原分类已不可用，请重新选择分类");
    } else if (oldWidget.categories.isEmpty &&
        _available.isNotEmpty &&
        widget.template == null) {
      _defaultCategory();
    }
  }

  void _key(String key) {
    if (!_saving) {
      setState(() {
        _error = _amount.insert(key);
      });
    }
  }

  void _switch(EntryKind kind) {
    if (_saving || widget.initialEntry != null) return;
    setState(() {
      _selectedByKind[_kind] = _categoryId;
      _kind = kind;
      _defaultCategory(_selectedByKind[kind]);
      _error = _categoryId == null ? tr(context, "请选择可用分类") : null;
    });
  }

  Future<void> _chooseDate() async {
    final today = calendarDay(widget.clock.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: tr(context, "选择发生日期"),
      cancelText: tr(context, "取消"),
      confirmText: tr(context, "确定"),
    );
    if (date != null && mounted) setState(() => _date = calendarDay(date));
  }

  Future<void> _editNote() async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NoteEditor(initialNote: _note),
    );
    if (note != null && mounted) setState(() => _note = note);
  }

  void _pop([LedgerEntry? value]) {
    _undoExpiry?.cancel();
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, value);
    });
  }

  Future<void> _leave() async {
    if (_saving || _undoing || _confirming || _allowPop) return;
    if (!_dirty) {
      _pop();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tr(context, "放弃这笔记录？")),
        content: Text(tr(context, "尚未保存的金额和备注将不会保留。")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(tr(context, "继续编辑")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(tr(context, "放弃")),
          ),
        ],
      ),
    );
    _confirming = false;
    if (discard == true && mounted) _pop();
  }

  EntryDraft _draft() {
    final amount = Money.parse(_amount.parseable);
    if (amount.fen <= 0) throw FormatException(tr(context, "请输入大于零的金额"));
    if (_categoryId == null || !_available.any((c) => c.id == _categoryId)) {
      throw FormatException(tr(context, "请选择可用分类"));
    }
    if (_date.isAfter(calendarDay(widget.clock.now()))) {
      throw FormatException(tr(context, "日期不能晚于今天"));
    }
    final occurred = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    return EntryDraft(
      amount: amount,
      localDate: calendarDayKey(_date),
      occurredAtUtcMs: widget.initialEntry?.localDate == calendarDayKey(_date)
          ? widget.initialEntry!.occurredAtUtcMs
          : occurred.toUtc().millisecondsSinceEpoch,
      categoryId: _categoryId!,
      note: _note,
    );
  }

  Future<void> _save({bool more = false}) async {
    if (_saving || _undoing) return;
    try {
      final draft = _draft();
      if (_kind == EntryKind.income && widget.onSaveIncome == null) {
        throw FormatException(tr(context, "收入保存尚不可用"));
      }
      setState(() {
        _saving = true;
        _error = null;
      });
      final entry = await (_kind == EntryKind.income
          ? widget.onSaveIncome!(draft)
          : widget.onSave(draft));
      if (!mounted) return;
      if (widget.profile?.feedback ?? true) HapticFeedback.lightImpact();
      if (more) {
        _undoExpiry?.cancel();
        setState(() {
          _undoEntry = widget.onUndo == null ? null : entry;
          _saving = false;
          _amount.value = '';
          _note = '';
          _time = TimeOfDay.fromDateTime(widget.clock.now());
          _savedCount++;
          _savedFeedback = tr(context, "已保存 {0} 笔 · {1} · {2} · {3}", [
            _savedCount,
            entry.amount.yuan,
            localizedCategoryById(context, entry.categoryId, widget.categories),
            entry.localDate,
          ]);
          _markClean();
        });
        _undoExpiry = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _undoEntry = null;
              _savedFeedback = null;
            });
          }
        });
      } else {
        _pop(entry);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = tr(context, presentationError(e));
        });
      }
    }
  }

  Future<void> _undo() async {
    final entry = _undoEntry;
    if (entry == null || _saving || _undoing) return;
    setState(() {
      _undoEntry = null;
      _undoing = true;
    });
    try {
      await widget.onUndo!(entry);
      if (mounted) {
        setState(() {
          _savedCount--;
          _savedFeedback = tr(context, "已撤销上一笔，当前输入已保留");
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = tr(context, presentationError(error)));
      }
    } finally {
      if (mounted) setState(() => _undoing = false);
    }
  }

  @override
  void dispose() {
    _undoExpiry?.cancel();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    try {
      final draft = _draft();
      final name = TextEditingController();
      final chosen = await showCompletedDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(tr(context, "保存为常用模板")),
          content: TextField(
            controller: name,
            maxLength: 40,
            decoration: InputDecoration(hintText: tr(context, "例如：食堂午餐")),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(tr(context, "取消")),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, name.text.trim()),
              child: Text(tr(context, "保存模板")),
            ),
          ],
        ),
      );
      name.dispose();
      if (chosen == null || chosen.isEmpty) return;
      await widget.onSaveTemplate!(
        EntryTemplate(
          id: 'template-${DateTime.now().microsecondsSinceEpoch}',
          name: chosen,
          kind: _kind,
          amount: draft.amount,
          categoryId: draft.categoryId,
          note: draft.note,
        ),
      );
      if (mounted) {
        setState(() => _notice = tr(context, "模板已保存"));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : tr(context, presentationError(e)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.initialEntry == null &&
            CalendarMonth.fromDate(_date) !=
                CalendarMonth.fromDate(widget.clock.now()))
          Text(
            tr(context, "补记 {0} · {1}", [
              CalendarMonth.fromDate(_date).key,
              calendarDayKey(_date),
            ]),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kind == EntryKind.income
                        ? tr(context, "收入金额")
                        : tr(context, "支出金额"),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Semantics(
                    liveRegion: true,
                    label: tr(context, "金额 {0} 元", [
                      _amount.value.isEmpty
                          ? tr(context, "未输入")
                          : _amount.value,
                    ]),
                    excludeSemantics: true,
                    child: Text(
                      '¥ ${_amount.value.isEmpty ? '0.00' : _amount.value}',
                      softWrap: true,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: scheme.primary, fontSize: 36),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onSaveTemplate != null)
              IconButton(
                tooltip: tr(context, "保存为模板"),
                onPressed: _saving ? null : _saveTemplate,
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_available.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr(context, "暂无可用分类")),
              if (widget.onAddRecommended != null)
                TextButton(
                  onPressed: _saving ? null : widget.onAddRecommended,
                  child: Text(tr(context, "补全推荐分类")),
                ),
            ],
          )
        else
          CategorySelector(
            categories: widget.categories,
            selectedId: _categoryId,
            kind: _kind,
            enabled: !_saving,
            onSelected: (id) => setState(() {
              _categoryId = id;
              _error = null;
            }),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            TextButton.icon(
              onPressed: _saving ? null : _chooseDate,
              icon: const Icon(Icons.today_outlined, size: 18),
              label: Text(
                calendarDayKey(_date) == calendarDayKey(widget.clock.now())
                    ? tr(context, "今天")
                    : calendarDayKey(_date),
              ),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _editNote,
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              label: Text(
                _note.isEmpty ? tr(context, "备注（选填）") : tr(context, "已填写备注"),
              ),
            ),
          ],
        ),
        if (_note.isNotEmpty)
          Text(
            _note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              tr(context, _error!),
              style: TextStyle(color: scheme.error),
            ),
          ),
        if (_notice != null)
          Semantics(
            liveRegion: true,
            child: Text(_notice!, style: TextStyle(color: scheme.primary)),
          ),
        const SizedBox(height: 4),
      ],
    );
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_savedFeedback != null)
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _savedFeedback!,
                    key: const ValueKey('save-feedback'),
                  ),
                ),
                if (_undoEntry != null)
                  TextButton(
                    onPressed: _saving || _undoing ? null : _undo,
                    child: Text(tr(context, "撤销")),
                  ),
              ],
            ),
          ),
        AmountKeypad(onKey: _key, enabled: !_saving),
        const SizedBox(height: 6),
        Row(
          children: [
            if (widget.initialEntry == null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _saving ||
                          _undoing ||
                          _amount.value.isEmpty ||
                          _available.isEmpty
                      ? null
                      : () => _save(more: true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    tr(context, "保存并继续"),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton(
                onPressed:
                    _saving ||
                        _undoing ||
                        _amount.value.isEmpty ||
                        _available.isEmpty
                    ? null
                    : () => _save(),
                child: Text(
                  _saving
                      ? tr(context, "保存中…")
                      : widget.initialEntry != null
                      ? tr(context, "保存修改")
                      : _kind == EntryKind.income
                      ? tr(context, "保存收入")
                      : tr(context, "保存支出"),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return PopScope<LedgerEntry>(
      canPop: _allowPop || (!_dirty && !_saving && !_undoing),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: tr(context, "返回"),
            onPressed: _saving ? null : _leave,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: widget.initialEntry != null
              ? Text(
                  _kind == EntryKind.income
                      ? tr(context, "编辑收入")
                      : tr(context, "编辑账单"),
                )
              : SegmentedButton<EntryKind>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: EntryKind.expense,
                      label: Text(tr(context, "支出")),
                    ),
                    ButtonSegment(
                      value: EntryKind.income,
                      label: Text(tr(context, "收入")),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: _saving ? null : (v) => _switch(v.first),
                ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxHeight < 400 ||
                      MediaQuery.textScalerOf(context).scale(14) > 24) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [fields, controls]),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: AbsorbPointer(
                              absorbing: _saving,
                              child: fields,
                            ),
                          ),
                        ),
                        controls,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
