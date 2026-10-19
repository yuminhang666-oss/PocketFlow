// Explicit developer preview. Never imported by lib/main.dart or composition.
// Run after the owner resolves dependencies: flutter run -t design/ui-ux/preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/app/routing/pocketflow_shell.dart';
import 'package:pocketflow/contracts/clock.dart';
import 'package:pocketflow/contracts/pocketflow_exception.dart';
import 'package:pocketflow/core/domain/calendar_month.dart';
import 'package:pocketflow/core/domain/ledger_entry.dart';
import 'package:pocketflow/core/domain/ledger_models.dart';
import 'package:pocketflow/core/domain/money.dart';
import 'package:pocketflow/features/budget/domain/budget_calculator.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/home/presentation/home_page.dart';
import 'package:pocketflow/features/home/presentation/widgets/month_picker.dart';
import 'package:pocketflow/features/ledger_list/presentation/entry_details_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/settings/presentation/budget_editor_sheet.dart';
import 'package:pocketflow/features/settings/presentation/settings_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';
import 'package:pocketflow/shared/widgets/status_panel.dart';

void main() => runApp(const ProviderScope(child: _PreviewApp()));

enum _Scene {
  normal('正常'),
  empty('无账单'),
  noBudget('未设置预算'),
  zero('零预算'),
  overspent('超支'),
  past('历史月'),
  future('未来月'),
  loading('加载'),
  error('读取失败'),
  saveError('保存失败');

  const _Scene(this.label);
  final String label;
}

class _PreviewClock implements Clock {
  const _PreviewClock();
  @override
  DateTime now() => DateTime(2026, 10, 17, 12, 20);
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();
  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  ThemeMode _theme = ThemeMode.system;
  @override
  Widget build(BuildContext context) => PocketFlowApp(
    themeMode: _theme,
    home: _PreviewHost(
      theme: _theme,
      onTheme: (value) => setState(() => _theme = value),
    ),
  );
}

class _PreviewHost extends StatefulWidget {
  const _PreviewHost({required this.theme, required this.onTheme});
  final ThemeMode theme;
  final ValueChanged<ThemeMode> onTheme;
  @override
  State<_PreviewHost> createState() => _PreviewHostState();
}

class _PreviewHostState extends State<_PreviewHost> {
  static const _clock = _PreviewClock();
  _Scene _scene = _Scene.normal;
  CalendarMonth _month = CalendarMonth(2026, 10);
  Money? _budget = const Money.fromFen(150000);
  int _sequence = 10;
  List<LedgerEntry> _entries = [];
  final _categories = [
    Category(id: 'food', name: '餐饮', sortOrder: 0),
    Category(id: 'drinks', name: '饮品', sortOrder: 1),
    Category(id: 'shopping', name: '购物', sortOrder: 2),
    Category(id: 'transport', name: '交通', sortOrder: 3),
    Category(id: 'study', name: '学习', sortOrder: 4),
    Category(id: 'fun', name: '娱乐', sortOrder: 5),
    Category(id: 'health', name: '医疗', sortOrder: 6),
    Category(id: 'other', name: '其他', sortOrder: 7),
  ];

  @override
  void initState() {
    super.initState();
    _reset(_Scene.normal);
  }

  void _reset(_Scene scene) {
    _scene = scene;
    _month = CalendarMonth(
      2026,
      scene == _Scene.past
          ? 9
          : scene == _Scene.future
          ? 11
          : 10,
    );
    _budget = scene == _Scene.noBudget
        ? null
        : Money.fromFen(
            scene == _Scene.zero
                ? 0
                : scene == _Scene.overspent
                ? 50000
                : 150000,
          );
    _entries = scene == _Scene.empty
        ? []
        : [
            _fixture('mock-1', 1800, 'food', '食堂午餐', 17, 12),
            _fixture('mock-2', 1200, 'drinks', '一杯拿铁', 17, 9),
            _fixture('mock-3', 800, 'transport', '地铁出行', 17, 8),
            _fixture('mock-4', 56200, 'shopping', '本月生活用品', 12, 10),
          ];
  }

  LedgerEntry _fixture(
    String id,
    int fen,
    String category,
    String note,
    int day,
    int hour,
  ) {
    final date = DateTime(2026, 10, day, hour);
    return LedgerEntry(
      id: id,
      amount: Money.fromFen(fen),
      localDate: calendarDayKey(date),
      categoryId: category,
      note: note,
      occurredAtUtcMs: date.toUtc().millisecondsSinceEpoch,
      createdAtUtcMs: date.toUtc().millisecondsSinceEpoch,
      updatedAtUtcMs: date.toUtc().millisecondsSinceEpoch,
    );
  }

  LedgerMonthData get _ledger => LedgerMonthData(
    month: _month,
    budget: _budget == null
        ? null
        : MonthlyBudget(
            month: _month,
            amount: _budget!,
            updatedAtUtcMs: _clock.now().toUtc().millisecondsSinceEpoch,
          ),
    entries: _entries.where(
      (entry) => CalendarMonth.fromDate(entry.date) == _month,
    ),
    categories: _categories,
  );

  AsyncValue<(LedgerMonthData, BudgetSnapshot)> get _state {
    if (_scene == _Scene.loading) return const AsyncLoading();
    if (_scene == _Scene.error) {
      return AsyncError(
        const PocketFlowException(PocketFlowErrorCode.storageFailure),
        StackTrace.current,
      );
    }
    final ledger = _ledger;
    // Reuse B's algorithm only inside this isolated preview, never copy it.
    final snapshot = const BudgetCalculator().calculate(
      month: _month,
      today: _clock.now(),
      budget: ledger.budget?.amount,
      entries: ledger.entries,
    );
    return AsyncData((ledger, snapshot));
  }

  Future<LedgerEntry> _save(EntryDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_scene == _Scene.saveError) {
      throw const PocketFlowException(PocketFlowErrorCode.storageFailure);
    }
    final now = _clock.now().toUtc().millisecondsSinceEpoch;
    final entry = LedgerEntry(
      id: 'mock-${++_sequence}',
      amount: draft.amount,
      localDate: draft.localDate,
      categoryId: draft.categoryId,
      note: draft.note,
      occurredAtUtcMs: draft.occurredAtUtcMs,
      createdAtUtcMs: now,
      updatedAtUtcMs: now,
    );
    if (mounted) {
      setState(() {
        _entries = [entry, ..._entries]
          ..sort((a, b) {
            final time = b.occurredAtUtcMs.compareTo(a.occurredAtUtcMs);
            return time == 0 ? a.id.compareTo(b.id) : time;
          });
      });
    }
    return entry;
  }

  Future<void> _add() async {
    final entry = await Navigator.of(context).push<LedgerEntry>(
      MaterialPageRoute(
        builder: (context) => QuickEntryPage(
          categories: _categories,
          onSave: _save,
          clock: _clock,
        ),
      ),
    );
    if (entry != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存支出（仅本次演示）')));
    }
  }

  void _detail(LedgerEntry entry) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          EntryDetailsPage(entry: entry, categories: _categories),
    ),
  );

  void _list() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => LedgerListPage(
        data: _ledger,
        query: const DefaultLedgerQueryService(),
        asOfLocalDate: calendarDayKey(_clock.now()),
        onEntryTap: _detail,
      ),
    ),
  );

  Future<void> _setBudget() async {
    await showBudgetEditor(
      context,
      month: _month,
      initialBudget: _budget,
      onSave: (amount) async {
        final value = MonthlyBudget(
          month: _month,
          amount: amount,
          updatedAtUtcMs: _clock.now().toUtc().millisecondsSinceEpoch,
        );
        if (mounted) setState(() => _budget = amount);
        return value;
      },
    );
  }

  Future<void> _chooseMonth() async {
    final value = await showMonthPicker(context, _month);
    if (value != null && mounted) setState(() => _month = value);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SafeArea(
        bottom: false,
        child: Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Expanded(child: Text('演示环境 · 示例数据不保存')),
                PopupMenuButton<_Scene>(
                  tooltip: '选择演示场景',
                  onSelected: (scene) => setState(() => _reset(scene)),
                  itemBuilder: (context) => [
                    for (final scene in _Scene.values)
                      PopupMenuItem(value: scene, child: Text(scene.label)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: PocketFlowShell(
          onAdd: _add,
          ledger: LedgerListPage(
            data: _ledger,
            query: const DefaultLedgerQueryService(),
            asOfLocalDate: calendarDayKey(_clock.now()),
            onEntryTap: _detail,
          ),
          home: HomePage(
            month: _month,
            state: _state,
            onAddExpense: _add,
            onSetBudget: _setBudget,
            onOpenLedger: _list,
            onEntryTap: _detail,
            onChooseMonth: _chooseMonth,
            onRefresh: () async {
              setState(() => _scene = _Scene.normal);
            },
          ),
          statistics: const Scaffold(
            appBar: null,
            body: Center(
              child: StatusPanel(
                title: '统计展示区域',
                message: '图表由 C 模块提供，此处仅为演示占位',
                icon: Icons.bar_chart_rounded,
              ),
            ),
          ),
          settings: SettingsPage(
            themeMode: widget.theme,
            onThemeChanged: widget.onTheme,
            onBudget: _setBudget,
            onHistory: _list,
            onAbout: () => showAboutDialog(
              context: context,
              applicationName: 'PocketFlow',
              applicationVersion: 'UI 演示 v1',
              children: const [Text('离线生活费管理 · 示例数据不会写入手机账本。')],
            ),
          ),
        ),
      ),
    ],
  );
}
