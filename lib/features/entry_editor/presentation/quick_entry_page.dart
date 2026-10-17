import 'package:flutter/material.dart';

import '../../../contracts/clock.dart';
import '../../../core/domain/calendar_month.dart';
import '../../../core/domain/ledger_entry.dart';
import '../../../core/domain/ledger_models.dart';
import '../../../core/domain/money.dart';
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
    this.clock = const SystemClock(),
    this.initialEntry,
  });

  final List<Category> categories;
  final Future<LedgerEntry> Function(EntryDraft) onSave;
  final Clock clock;
  final LedgerEntry? initialEntry;

  @override
  State<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends State<QuickEntryPage> {
  final _amount = AmountBuffer();
  late DateTime _date;
  late final DateTime _initialDate;
  late final TimeOfDay _time;
  late final String? _initialCategoryId;
  String? _categoryId;
  String _note = '';
  late final String _initialAmount;
  late final String _initialNote;
  String? _error;
  bool get _dirty =>
      _amount.value != _initialAmount ||
      _note != _initialNote ||
      _date != _initialDate ||
      _categoryId != _initialCategoryId;
  bool _saving = false;
  bool _allowPop = false;
  bool _confirming = false;

  List<Category> get _categories =>
      widget.categories
          .where(
            (c) => !c.isArchived || c.id == widget.initialEntry?.categoryId,
          )
          .toList()
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });

  @override
  void initState() {
    super.initState();
    final now = widget.clock.now();
    final initial = widget.initialEntry;
    _amount.value = initial?.amount.decimal ?? '';
    _initialAmount = _amount.value;
    _note = initial?.note ?? '';
    _initialNote = _note;
    _date = initial?.date ?? calendarDay(now);
    _initialDate = _date;
    _time = TimeOfDay.fromDateTime(
      initial == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(initial.occurredAtUtcMs),
    );
    final available = _categories;
    final food = available.where((c) => c.id == 'food');
    _categoryId =
        initial?.categoryId ??
        (food.isNotEmpty
            ? food.first.id
            : available.isEmpty
            ? null
            : available.first.id);
    _initialCategoryId = _categoryId;
  }

  @override
  void didUpdateWidget(covariant QuickEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_categoryId != null && !_categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
      _error = '原分类已不可用，请重新选择';
    }
  }

  void _key(String key) {
    if (_saving) return;
    setState(() {
      _error = _amount.insert(key);
    });
  }

  Future<void> _chooseDate() async {
    final today = calendarDay(widget.clock.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: '选择消费日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected != null && mounted) {
      setState(() {
        _date = calendarDay(selected);
        _error = null;
      });
    }
  }

  Future<void> _editNote() async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => NoteEditor(initialNote: _note),
    );
    if (note != null && mounted) {
      setState(() {
        _note = note;
      });
    }
  }

  Future<void> _leave() async {
    if (_saving || _confirming || _allowPop) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃这笔记录？'),
        content: const Text('尚未保存的金额和备注将不会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (discard == true && mounted) _pop();
  }

  void _pop([LedgerEntry? entry]) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(entry);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    try {
      final amount = Money.parse(_amount.parseable);
      if (amount.fen <= 0) throw const FormatException('请输入大于零的金额');
      if (_categoryId == null || !_categories.any((c) => c.id == _categoryId)) {
        throw const FormatException('请选择可用分类');
      }
      if (_date.isAfter(calendarDay(widget.clock.now()))) {
        throw const FormatException('支出日期不能晚于今天');
      }
      final occurred = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );
      final draft = EntryDraft(
        amount: amount,
        localDate: calendarDayKey(_date),
        occurredAtUtcMs: widget.initialEntry?.localDate == calendarDayKey(_date)
            ? widget.initialEntry!.occurredAtUtcMs
            : occurred.toUtc().millisecondsSinceEpoch,
        categoryId: _categoryId!,
        note: _note,
      );
      setState(() {
        _saving = true;
        _error = null;
      });
      final entry = await widget.onSave(draft);
      if (mounted) _pop(entry);
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = presentationError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    final keypad = AmountKeypad(onKey: _key, enabled: !_saving);
    final save = FilledButton(
      onPressed: _saving || _categories.isEmpty || _amount.value.isEmpty
          ? null
          : _save,
      child: _saving
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('保存中…'),
              ],
            )
          : Text(widget.initialEntry == null ? '保存支出' : '保存修改'),
    );
    return PopScope<LedgerEntry>(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialEntry == null ? '记一笔' : '编辑账单'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: _saving ? null : _leave,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 650 || large;
                  final fields = AbsorbPointer(
                    absorbing: _saving,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('支出金额'),
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          label:
                              '支出金额 ${_amount.value.isEmpty ? '未输入' : _amount.value} 元',
                          excludeSemantics: true,
                          child: Text(
                            '¥ ${_amount.value.isEmpty ? '0.00' : _amount.value}',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_categories.isEmpty)
                          const Text('暂无可用分类，暂时无法保存')
                        else
                          CategorySelector(
                            categories: _categories,
                            selectedId: _categoryId,
                            enabled: !_saving,
                            onSelected: (id) => setState(() {
                              _categoryId = id;
                              _error = null;
                            }),
                          ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('日期'),
                          subtitle: Text(calendarDayKey(_date)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _saving ? null : _chooseDate,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('备注'),
                          subtitle: Text(
                            _note.isEmpty ? '添加备注（选填）' : _note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _saving ? null : _editNote,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                  if (compact) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          fields,
                          keypad,
                          const SizedBox(height: 12),
                          save,
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: SingleChildScrollView(child: fields)),
                        keypad,
                        const SizedBox(height: 12),
                        save,
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
