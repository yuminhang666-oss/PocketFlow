import 'package:pocketflow/l10n/app_strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/contracts.dart';
import '../../features/backup/application/backup_transfer_service.dart';
import '../../features/backup/domain/json_backup_codec.dart';
import '../../features/budget/domain/budget_calculator.dart';
import '../../features/entry_editor/presentation/quick_entry_page.dart';
import '../../features/export/application/report_export_service.dart';
import '../../features/export/data/android_file_transfer_port.dart';
import '../../features/export/domain/markdown_exporter.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/widgets/month_picker.dart';
import '../../features/ledger_list/presentation/entry_details_page.dart';
import '../../features/ledger_list/presentation/ledger_list_page.dart';
import '../../features/settings/presentation/budget_editor_sheet.dart';
import '../../features/settings/presentation/categories_page.dart';
import '../../features/settings/presentation/planning_pages.dart';
import '../../features/settings/presentation/increase_goal_sheet.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/about_pocketflow_page.dart';
import '../../features/settings/domain/release_history.dart';
import '../../features/statistics/domain/ledger_query_service.dart';
import '../../features/statistics/domain/monthly_report_service.dart';
import '../../features/statistics/presentation/statistics_page.dart';
import '../../features/updates/application/app_update_controller.dart';
import '../../features/updates/data/android_app_update_port.dart';
import '../../features/updates/data/github_app_release_source.dart';
import '../../features/updates/presentation/app_updates_page.dart';
import '../../shared/widgets/presentation_errors.dart';
import '../../shared/widgets/status_panel.dart';
import '../pocketflow_app.dart';
import '../routing/pocketflow_shell.dart';
import '../../features/planning/presentation/planning_pages_v3.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/reports/domain/range_report_service.dart';
import '../../features/reminders/domain/budget_notice_policy.dart';
import '../../features/feedback/data/android_feedback_mail_port.dart';
import '../../features/feedback/presentation/feedback_page.dart';

final planningPortProvider = Provider<PlanningPort?>((ref) => null);
final feedbackDraftStoreProvider = Provider<FeedbackDraftStore?>((ref) => null);
final feedbackMailPortProvider = Provider<FeedbackMailPort>(
  (ref) => const AndroidFeedbackMailPort(),
);

class _PromptNavigatorObserver extends NavigatorObserver {
  _PromptNavigatorObserver(this.changed);
  final VoidCallback changed;
  final routes = <Route<dynamic>>[];
  bool get idle => routes.length == 1;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) {
    routes.add(route);
    changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previous) {
    routes.remove(route);
    changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previous) {
    routes.remove(route);
    changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) routes.remove(oldRoute);
    if (newRoute != null) routes.add(newRoute);
    changed();
  }
}

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => throw StateError('Production repository must be injected'),
);
final backupStoreProvider = Provider<BackupStore>(
  (ref) => throw StateError('Production backup store must be injected'),
);
final clockProvider = Provider<Clock>((ref) => const SystemClock());
final appUpdateProvider = Provider<AppUpdateController>((ref) {
  final controller = AppUpdateController(
    platform: const AndroidAppUpdatePort(),
    source: GithubAppReleaseSource(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
final fileTransferProvider = Provider<FileTransferPort>(
  (ref) => const AndroidFileTransferPort(),
);
final monthDataProvider = StreamProvider.autoDispose
    .family<LedgerMonthData, CalendarMonth>(
      (ref, month) => ref.watch(ledgerRepositoryProvider).watchMonth(month),
      // Persistent local startup errors need an explicit retry, not a loading loop.
      retry: (_, _) => null,
    );
final backupTransferProvider = Provider<BackupTransferService>(
  (ref) => BackupTransferService(
    store: ref.watch(backupStoreProvider),
    files: ref.watch(fileTransferProvider),
    codec: const JsonBackupCodec(),
    clock: ref.watch(clockProvider),
  ),
);

class PocketFlowRoot extends ConsumerStatefulWidget {
  const PocketFlowRoot({super.key});
  @override
  ConsumerState<PocketFlowRoot> createState() => _PocketFlowRootState();
}

class _PocketFlowRootState extends ConsumerState<PocketFlowRoot>
    with WidgetsBindingObserver {
  CalendarMonth? _ledgerMonth, _statisticsMonth;
  final _ledgerKey = GlobalKey<LedgerListPageState>();
  Timer? _midnight;
  bool _fileBusy = false;
  late final AppUpdateController _updates;
  late final _PromptNavigatorObserver _promptObserver;
  BuildContext? _promptContext;
  bool _sessionPromptUsed = false,
      _promptChecking = false,
      _promptScheduled = false;
  int _tab = 0;
  final _shellKey = GlobalKey<PocketFlowShellState>();
  int? _lastExport;
  bool _foreground = true;
  // Month snapshots may temporarily be loading. A known app-wide appearance
  // must not revert to defaults while the next financial snapshot is read.
  PersonalProfile _appearance = PersonalProfile();

  @override
  void initState() {
    super.initState();
    _promptObserver = _PromptNavigatorObserver(_schedulePrompt);
    _updates = ref.read(appUpdateProvider)..addListener(_updatesChanged);
    unawaited(_updates.initialize());
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    final plans = ref.read(planningPortProvider);
    if (plans != null) {
      unawaited(
        plans.lastExportUtcMs().then((value) {
          if (mounted) setState(() => _lastExport = value);
        }),
      );
    }
  }

  CalendarMonth get _month =>
      CalendarMonth.fromDate(ref.read(clockProvider).now());

  void _updatesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showUpdates(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => AppUpdatesPage(controller: _updates)),
      );

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = ref.read(clockProvider).now();
    var next = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    if (now.hour < 8) {
      next = now.isUtc
          ? DateTime.utc(now.year, now.month, now.day, 8)
          : DateTime(now.year, now.month, now.day, 8);
    }
    _midnight = Timer(next.difference(now), () {
      if (mounted) {
        setState(() {});
        _scheduleMidnight();
        _schedulePrompt();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_foreground) _sessionPromptUsed = false;
      _foreground = true;
      setState(() {});
      ref.invalidate(monthDataProvider(_month));
      _scheduleMidnight();
      _schedulePrompt();
    } else {
      _foreground = false;
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _updates.removeListener(_updatesChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _message(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, message)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _chooseMonth(
    BuildContext context, {
    bool statistics = false,
  }) async {
    final selected = await showMonthPicker(
      context,
      (statistics ? _statisticsMonth : _ledgerMonth) ?? _month,
    );
    if (selected != null && mounted) {
      setState(() {
        if (statistics) {
          _statisticsMonth = selected;
        } else {
          _ledgerMonth = selected;
        }
      });
    }
  }

  void _openLedger({bool calendar = false}) {
    setState(() => _ledgerMonth = null);
    _shellKey.currentState?.selectDestination(1);
    // Also runs when the current query month needs a fresh snapshot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ledgerKey.currentState?.resetToMonth(calendar: calendar);
    });
  }

  Future<void> _budget(BuildContext context, LedgerMonthData? data) async {
    final month = data?.month ?? _month;
    final saved = await showBudgetEditor(
      context,
      month: month,
      initialBudget: data?.budget?.amount,
      spent: data == null
          ? const Money.fromFen(0)
          : const BudgetCalculator()
                .calculate(
                  month: month,
                  today: ref.read(clockProvider).now(),
                  budget: data.budget?.amount,
                  entries: data.entries,
                )
                .spent,
      onSave: (amount) =>
          ref.read(ledgerRepositoryProvider).saveBudget(month, amount),
    );
    if (saved == true && context.mounted) {
      _message(context, tr(context, "预算已保存"));
    }
  }

  Future<LedgerEntry?> _edit(
    BuildContext context,
    LedgerMonthData data, {
    LedgerEntry? initial,
    EntryTemplate? template,
    String? localDate,
  }) async {
    final now = ref.read(clockProvider).now();
    final repository = ref.read(ledgerRepositoryProvider);
    // A previous save notification must not cover the next editor's controls.
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    final entry = await Navigator.of(context).push<LedgerEntry>(
      MaterialPageRoute(
        builder: (_) => Consumer(
          builder: (route, ref, _) {
            final live =
                ref.watch(monthDataProvider(data.month)).asData?.value ?? data;
            return QuickEntryPage(
              categories: live.categories,
              profile: live.profile,
              clock: ref.read(clockProvider),
              initialEntry: initial,
              template: template,
              initialDate: localDate ?? calendarDayKey(now),
              onSave: (draft) => initial == null
                  ? repository.createExpense(draft)
                  : repository.updateExpense(initial.id, draft),
              onSaveIncome: (draft) => initial == null
                  ? repository.createIncome(draft)
                  : repository.updateIncome(initial.id, draft),
              onAddRecommended: repository.addRecommendedCategories,
              onSaveTemplate: repository.saveTemplate,
              onUndo: ref.read(planningPortProvider)?.undoCreate,
            );
          },
        ),
      ),
    );
    if (entry != null && context.mounted) {
      final port = ref.read(planningPortProvider);
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            persist: false,
            content: Text(
              tr(context, "{0} {1} · {2} · {3}", [
                initial == null ? tr(context, "已保存") : tr(context, "已更新"),
                '${tr(context, entry.kind == EntryKind.expense ? "支出" : "收入")} ${entry.amount.yuan}',
                localizedCategoryById(
                  context,
                  entry.categoryId,
                  data.categories,
                ),
                entry.localDate,
              ]),
            ),
            action:
                initial != null ||
                    port == null ||
                    ref.read(clockProvider).now().millisecondsSinceEpoch -
                            entry.createdAtUtcMs >
                        5000
                ? null
                : SnackBarAction(
                    label: tr(context, "撤销"),
                    onPressed: () async {
                      try {
                        await port.undoCreate(entry);
                      } catch (e) {
                        if (context.mounted) {
                          _message(context, tr(context, presentationError(e)));
                        }
                      }
                    },
                  ),
          ),
        );
    }
    return entry;
  }

  Future<void> _details(
    BuildContext context,
    LedgerMonthData data,
    LedgerEntry entry,
  ) async {
    var current = entry;
    String? notice;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (detailContext) => StatefulBuilder(
          builder: (detailContext, update) => EntryDetailsPage(
            entry: current,
            categories: data.categories,
            notice: notice,
            onEdit: () async {
              final saved = await _edit(detailContext, data, initial: current);
              if (saved != null && detailContext.mounted) {
                update(() {
                  current = saved;
                  if (saved.localDate != entry.localDate ||
                      saved.categoryId != entry.categoryId) {
                    notice = tr(detailContext, "记录的日期或分类已更新，来源列表仍保留原筛选条件");
                  }
                });
              }
            },
            onDelete: () => _delete(detailContext, current),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tr(context, "删除这笔账单？")),
        content: Text(
          tr(context, "{0} · {1}\n删除后将重新计算统计。如来自周期待办，该期会改为已跳过，不会自动重新入账。", [
            entry.amount.yuan,
            entry.localDate,
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(tr(context, "取消")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(tr(context, "删除")),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(ledgerRepositoryProvider).deleteEntry(entry.id);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        _message(context, tr(context, presentationError(error)));
      }
    }
  }

  Widget _dataPage(
    CalendarMonth month,
    Widget Function(BuildContext, LedgerMonthData) builder,
  ) => Consumer(
    builder: (route, ref, _) => ref
        .watch(monthDataProvider(month))
        .when(
          data: (data) => builder(route, data),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: Text(tr(context, "账本"))),
            body: StatusPanel(
              title: tr(context, "无法读取账本"),
              message: tr(context, presentationError(error)),
              actionLabel: tr(context, "重试"),
              onAction: () => ref.invalidate(monthDataProvider(month)),
            ),
          ),
        ),
  );

  Future<void> _ledger(
    BuildContext context,
    CalendarMonth month, {
    String? date,
    String? categoryId,
    EntryKind? kind,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Consumer(
        builder: (route, ref, _) {
          final state = ref.watch(monthDataProvider(month));
          final data = state.asData?.value;
          return LedgerListPage(
            data: data,
            month: month,
            loading: state.isLoading,
            readError: state.hasError ? state.error : null,
            onRetry: () => ref.invalidate(monthDataProvider(month)),
            query: const DefaultLedgerQueryService(),
            asOfLocalDate: calendarDayKey(ref.read(clockProvider).now()),
            initialDate: date,
            initialCategoryId: categoryId,
            initialKind: kind,
            drillDown: true,
            onEntryTap: data == null
                ? null
                : (entry) => _details(route, data, entry),
          );
        },
      ),
    ),
  );

  Future<void> _goals(BuildContext context) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _dataPage(
        _month,
        (route, data) => GoalsPage(
          profile: data.profile,
          onSave: ref.read(ledgerRepositoryProvider).saveGoal,
          onDelete: ref.read(ledgerRepositoryProvider).deleteGoal,
        ),
      ),
    ),
  );

  Future<void> _categories(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _dataPage(
            _month,
            (route, data) => CategoriesPage(
              categories: data.categories,
              onSave: ref.read(ledgerRepositoryProvider).saveCategory,
              onRecommended: ref
                  .read(ledgerRepositoryProvider)
                  .addRecommendedCategories,
              onReorder: ref.read(ledgerRepositoryProvider).reorderCategories,
            ),
          ),
        ),
      );

  Future<void> _templates(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _dataPage(
            _month,
            (route, data) => TemplatesPage(
              profile: data.profile,
              categories: data.categories,
              onDelete: ref.read(ledgerRepositoryProvider).deleteTemplate,
              onUse: (template) {
                Navigator.pop(route);
                _edit(context, data, template: template);
              },
            ),
          ),
        ),
      );

  Future<void> _preferences(
    BuildContext context, {
    ThemeMode? theme,
    String? surfaceStyle,
    String? locale,
    bool? feedback,
  }) async {
    try {
      await ref
          .read(ledgerRepositoryProvider)
          .savePreferences(
            theme: theme?.name,
            surfaceStyle: surfaceStyle,
            locale: locale,
            feedback: feedback,
          );
    } catch (error) {
      if (context.mounted) {
        _message(context, tr(context, presentationError(error)));
      }
    }
  }

  Future<bool?> _fileAction(BuildContext context, String title) =>
      showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(tr(context, "{0} · 保存文件", [title])),
              leading: const Icon(Icons.save_alt),
              onTap: () => Navigator.pop(sheet, false),
            ),
            ListTile(
              title: Text(tr(context, "{0} · 系统分享", [title])),
              leading: const Icon(Icons.share_outlined),
              onTap: () => Navigator.pop(sheet, true),
            ),
          ],
        ),
      );

  Future<void> _files(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        _message(context, tr(context, presentationError(error)));
      }
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _export(BuildContext context, LedgerMonthData data) =>
      _files(context, () async {
        final share = await _fileAction(context, tr(context, "Markdown 月报"));
        if (share == null) return;
        final clock = ref.read(clockProvider);
        final reports = DefaultMonthlyReportService(clock: clock);
        final report = reports.build(
          data,
          asOfLocalDate: reports.defaultCutoff(data.month),
        );
        final service = ReportExportService(
          files: ref.read(fileTransferProvider),
          markdown: DefaultMarkdownExporter(clock: clock),
        );
        final done = share
            ? await service.share(report)
            : await service.save(report);
        if (done && context.mounted) {
          _message(
            context,
            share ? tr(context, "已打开系统分享") : tr(context, "月报已保存"),
          );
        }
      });

  Future<void> _backup(BuildContext context) => _files(context, () async {
    final share = await _fileAction(context, tr(context, "JSON 完整备份"));
    if (share == null) return;
    final service = ref.read(backupTransferProvider);
    final done = share ? await service.share() : await service.save();
    if (done && context.mounted) {
      _message(context, share ? tr(context, "已打开系统分享") : tr(context, "备份已保存"));
    }
    if (done && !share) {
      await ref.read(planningPortProvider)?.recordSuccessfulExport();
      if (mounted) {
        setState(
          () => _lastExport = ref
              .read(clockProvider)
              .now()
              .millisecondsSinceEpoch,
        );
      }
    }
  });

  Future<void> _restore(BuildContext context) => _files(context, () async {
    final result = await ref
        .read(backupTransferProvider)
        .restore(
          confirm: (document) async {
            if (!context.mounted) return false;
            return await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: Text(tr(context, "恢复并替换现有账本？")),
                    content: Text(
                      tr(
                        context,
                        "备份包含 {0} 笔记录、{1} 个月预算、{2} 个分类。\n\n将完整替换现有账本、目标、模板和偏好设置。旧版备份不含的新设置会恢复默认。恢复前会保留本地恢复点。{3}\n导出时间：{4}\n来源格式 v{5} · {6}条周期规则{7}",
                        [
                          document.entries.length,
                          document.budgets.length,
                          document.categories.length,
                          document.entries.isEmpty
                              ? tr(context, "\n此备份没有账单，恢复后账单将为空。")
                              : '',
                          DateTime.fromMillisecondsSinceEpoch(
                            document.exportedAtUtcMs,
                          ),
                          document.sourceFormatVersion,
                          document.plans.rules.length,
                          document.sourceFormatVersion < 3
                              ? tr(context, "\n旧备份不含周期计划/分类预算，确认替换后将为空。")
                              : '',
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: Text(tr(context, "取消")),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: Text(tr(context, "确认替换")),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
        );
    if (result != null && context.mounted) {
      ref.invalidate(monthDataProvider);
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(tr(context, "恢复完成")),
          content: SelectableText(
            tr(context, "已恢复 {0} 笔账单。\n恢复前的本地恢复点：\n{1}", [
              result.entryCount,
              result.recoveryBackupId,
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(tr(context, "完成")),
            ),
          ],
        ),
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final month = _month;
    final state = ref.watch(monthDataProvider(month));
    final current = state.asData?.value;
    final ledgerMonth = _ledgerMonth ?? month;
    final ledgerState = ref.watch(monthDataProvider(ledgerMonth));
    final ledgerData = ledgerState.asData?.value;
    final statisticsMonth = _statisticsMonth ?? month;
    final statisticsState = ref.watch(monthDataProvider(statisticsMonth));
    if (current != null) _appearance = current.profile;
    final today = ref.read(clockProvider).now();
    final themeMode = ThemeMode.values.byName(_appearance.theme);
    final reports = DefaultMonthlyReportService(clock: ref.read(clockProvider));
    final report =
        current == null || month.compareTo(CalendarMonth.fromDate(today)) > 0
        ? null
        : reports.build(current, asOfLocalDate: reports.defaultCutoff(month));
    final pair = state.whenData(
      (data) => (
        data,
        const BudgetCalculator().calculate(
          month: month,
          today: today,
          budget: data.budget?.amount,
          entries: data.entries,
        ),
      ),
    );
    return PocketFlowApp(
      themeMode: themeMode,
      language: _appearance.locale,
      glass: _appearance.surfaceStyle == 'glass',
      navigatorObservers: [_promptObserver],
      home: Builder(
        builder: (context) {
          _promptContext = context;
          _schedulePrompt();
          return PopScope(
            canPop: !_fileBusy,
            child: Stack(
              children: [
                PocketFlowShell(
                  key: _shellKey,
                  onTabChanged: (index) {
                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                    if (index == 1 && _tab != 1) {
                      _ledgerKey.currentState?.showList();
                    }
                    _tab = index;
                    _schedulePrompt();
                  },
                  onAdd:
                      current == null ||
                          month.compareTo(CalendarMonth.fromDate(today)) > 0
                      ? null
                      : () => _edit(context, current),
                  ledger: LedgerListPage(
                    key: _ledgerKey,
                    data: ledgerData,
                    month: ledgerMonth,
                    loading: ledgerState.isLoading,
                    readError: ledgerState.hasError ? ledgerState.error : null,
                    onRetry: () =>
                        ref.invalidate(monthDataProvider(ledgerMonth)),
                    query: const DefaultLedgerQueryService(),
                    asOfLocalDate: calendarDayKey(today),
                    onChooseMonth: () => _chooseMonth(context),
                    onMoveMonth: (value) =>
                        setState(() => _ledgerMonth = value),
                    onCurrentMonth: () => setState(() => _ledgerMonth = null),
                    onMarkZero: ref
                        .read(ledgerRepositoryProvider)
                        .markZeroExpenseDay,
                    onAddDay: ledgerData == null
                        ? null
                        : (date) => _edit(context, ledgerData, localDate: date),
                    onEntryTap: ledgerData == null
                        ? null
                        : (entry) => _details(context, ledgerData, entry),
                    onAdd: current == null
                        ? null
                        : () => _edit(context, current),
                  ),
                  home: HomePage(
                    month: month,
                    state: pair,
                    report: report,
                    todayKey: calendarDayKey(today),
                    onCalendar: () => _openLedger(calendar: true),
                    onGoals: () => _goals(context),
                    onTemplate: current == null
                        ? null
                        : (template) =>
                              _edit(context, current, template: template),
                    onAddExpense:
                        current == null ||
                            month.compareTo(CalendarMonth.fromDate(today)) > 0
                        ? null
                        : () => _edit(context, current),
                    onSetBudget: () => _budget(context, current),
                    onOpenLedger: () => _openLedger(),
                    onMore: () => _shellKey.currentState?.selectDestination(3),
                    onIncreaseGoal: (goal) => increaseSavingsGoal(
                      context,
                      goal,
                      ref.read(ledgerRepositoryProvider).saveGoal,
                    ),
                    onOpenDate: (date) => _ledger(context, month, date: date),
                    onReports: () => _reports(context),
                    onPlans: current == null
                        ? null
                        : () => _recurring(context, current),
                    onEntryTap: current == null
                        ? null
                        : (entry) => _details(context, current, entry),
                    onRefresh: () async {
                      ref.invalidate(monthDataProvider(month));
                    },
                  ),
                  statistics: StatisticsPage(
                    onReports: () => _reports(context),
                    month: statisticsMonth,
                    state: statisticsState,
                    clock: ref.read(clockProvider),
                    onOpenCategory: (id, kind) => _ledger(
                      context,
                      statisticsMonth,
                      categoryId: id,
                      kind: kind,
                    ),
                    onOpenDate: (date, kind) => _ledger(
                      context,
                      statisticsMonth,
                      date: date,
                      kind: kind,
                    ),
                    onChooseMonth: () =>
                        _chooseMonth(context, statistics: true),
                  ),
                  settings: SettingsPage(
                    lastExportUtcMs: _lastExport,
                    onReports: () => _reports(context),
                    onPlans: current == null
                        ? null
                        : () => _recurring(context, current),
                    onRecoveryPoints: () => _recoveryPoints(context),
                    onReminders: () => _reminders(context),
                    onFeedback: () => _feedback(context),
                    onUpdates: () => _showUpdates(context),
                    updateVersion: _updates.update?.versionName,
                    themeMode: themeMode,
                    language: _appearance.locale,
                    onLanguageChanged: (value) =>
                        _preferences(context, locale: value),
                    glass: _appearance.surfaceStyle == 'glass',
                    onGlassSelected: () =>
                        _preferences(context, surfaceStyle: 'glass'),
                    onThemeChanged: (theme) => _preferences(
                      context,
                      theme: theme,
                      surfaceStyle: 'classic',
                    ),
                    feedback: current?.profile.feedback ?? true,
                    onFeedbackChanged: (value) =>
                        _preferences(context, feedback: value),
                    onCalendar: () => _openLedger(calendar: true),
                    onGoals: () => _goals(context),
                    onCategories: () => _categories(context),
                    onTemplates: () => _templates(context),
                    onBudget: current == null
                        ? null
                        : () => _categoryBudgets(context, current),
                    onHistory: () =>
                        _shellKey.currentState?.selectDestination(1),
                    onExport:
                        current == null ||
                            month.compareTo(CalendarMonth.fromDate(today)) > 0
                        ? null
                        : () => _export(context, current),
                    onBackup: () => _backup(context),
                    onRestore: () => _restore(context),
                    onAbout: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => AboutPocketFlowPage(
                          installedVersion:
                              _updates.installed?.versionName ??
                              pocketFlowVersionHistory.first.version,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_fileBusy)
                  const Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: Color(0x55000000),
                        child: Center(
                          child: Icon(Icons.hourglass_top, size: 40),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _reports(BuildContext context, {String? start}) async {
    final port = ref.read(planningPortProvider);
    if (port == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReportsPage(
          port: port,
          clock: ref.read(clockProvider),
          initialStart: start,
          onAdd: () async {
            final data = await ref
                .read(ledgerRepositoryProvider)
                .watchMonth(_month)
                .first;
            if (context.mounted) await _edit(context, data);
          },
          onEntryTap: (entry) async {
            final data = await ref
                .read(ledgerRepositoryProvider)
                .watchMonth(CalendarMonth.fromDate(entry.date))
                .first;
            if (context.mounted) await _details(context, data, entry);
          },
        ),
      ),
    );
  }

  Future<void> _categoryBudgets(
    BuildContext context,
    LedgerMonthData data,
  ) async {
    final port = ref.read(planningPortProvider);
    if (port == null) {
      await _budget(context, data);
      return;
    }
    var selected = data.month;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (route, update) => _dataPage(
            selected,
            (context, live) => CategoryBudgetsPage(
              data: live,
              port: port,
              today: ref.read(clockProvider).now(),
              onTotalBudget: () => _budget(context, live),
              onChooseMonth: () async {
                final picked = await showMonthPicker(context, selected);
                if (picked != null && route.mounted) {
                  update(() => selected = picked);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recurring(BuildContext context, LedgerMonthData data) async {
    final port = ref.read(planningPortProvider);
    if (port == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _dataPage(
          data.month,
          (_, live) => RecurringPlansPage(
            port: port,
            categories: live.categories,
            clock: ref.read(clockProvider),
          ),
        ),
      ),
    );
  }

  Future<void> _recoveryPoints(BuildContext context) async {
    final port = ref.read(planningPortProvider);
    if (port == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecoveryPointsPage(
          port: port,
          backup: ref.read(backupStoreProvider),
        ),
      ),
    );
    if (mounted) {
      ref.invalidate(monthDataProvider);
      setState(() {});
      _scheduleMidnight();
    }
  }

  Future<void> _reminders(BuildContext context) async {
    final port = ref.read(planningPortProvider);
    if (port == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ReminderSettingsPage(port: port)),
    );
  }

  Future<void> _feedback(BuildContext context) async {
    final store = ref.read(feedbackDraftStoreProvider);
    if (store == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FeedbackPage(
          port: ref.read(feedbackMailPortProvider),
          store: store,
          installed: _updates.installed,
        ),
      ),
    );
  }

  bool get _promptReady =>
      mounted &&
      _foreground &&
      !_sessionPromptUsed &&
      !_fileBusy &&
      _tab == 0 &&
      _promptObserver.idle &&
      _promptContext?.mounted == true;
  void _schedulePrompt() {
    if (!mounted ||
        _promptScheduled ||
        _sessionPromptUsed ||
        ref.read(planningPortProvider) == null) {
      return;
    }
    _promptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptScheduled = false;
      if (_promptReady && !_promptChecking) unawaited(_maybePrompt());
    });
  }

  Future<void> _maybePrompt() async {
    if (!_promptReady || _promptChecking) return;
    final port = ref.read(planningPortProvider);
    if (port == null) return;
    _promptChecking = true;
    try {
      final now = ref.read(clockProvider).now(),
          range = const RangeReportService().latestWeeklyRange(
            ref.read(clockProvider).now(),
          );
      if (range != null) {
        final data = await port.watchRange(range.$1, range.$2).first;
        if (!_promptReady) return;
        if (data.entries.isNotEmpty &&
            await port.reserveReport(range.$1, range.$2)) {
          if (!_promptReady) return;
          final fresh = await port.watchRange(range.$1, range.$2).first;
          if (!_promptReady || fresh.entries.isEmpty) return;
          final report = const RangeReportService().build(fresh, now: now);
          _sessionPromptUsed = true;
          final context = _promptContext!;
          if (!context.mounted) return;
          final view = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: Text(tr(context, "上周收支回顾已准备好")),
              content: Text(
                tr(context, "{0} — {1}\n支出 {2} · 收入 {3}\n{4}", [
                  range.$1,
                  range.$2,
                  report.expense.yuan,
                  report.income.yuan,
                  report.categories.isEmpty
                      ? tr(context, "暂无支出记录")
                      : tr(context, "最高支出分类：{0} {1}", [
                          localizedCategoryLabel(
                            context,
                            report.categories.first.categoryId,
                            report.categories.first.name,
                          ),
                          report.categories.first.amount.yuan,
                        ]),
                ]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: Text(tr(context, "稍后再看")),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: Text(tr(context, "查看周报")),
                ),
              ],
            ),
          );
          if (view == true && context.mounted) {
            await _reports(context, start: range.$1);
          }
          return;
        }
      }
      if (!_promptReady || _month != CalendarMonth.fromDate(now)) return;
      final month = _month,
          data = await ref
              .read(ledgerRepositoryProvider)
              .watchMonth(_month)
              .first;
      final snapshot = const BudgetCalculator().calculate(
        month: month,
        today: now,
        budget: data.budget?.amount,
        entries: data.entries,
      );
      final kind = const BudgetNoticePolicy().qualify(
        month: month,
        now: now,
        budget: snapshot.budget,
        spentFen: snapshot.spent.fen,
      );
      if (kind == null ||
          !_promptReady ||
          !await port.reserveBudgetNotice(month) ||
          !_promptReady) {
        return;
      }
      final fresh = await ref
          .read(ledgerRepositoryProvider)
          .watchMonth(month)
          .first;
      final current = const BudgetCalculator().calculate(
        month: month,
        today: ref.read(clockProvider).now(),
        budget: fresh.budget?.amount,
        entries: fresh.entries,
      );
      if (!_promptReady ||
          const BudgetNoticePolicy().qualify(
                month: month,
                now: ref.read(clockProvider).now(),
                budget: current.budget,
                spentFen: current.spent.fen,
              ) ==
              null) {
        return;
      }
      _sessionPromptUsed = true;
      final context = _promptContext!;
      if (!context.mounted) return;
      var mute = false;
      final view = await showDialog<bool>(
        context: context,
        builder: (d) => StatefulBuilder(
          builder: (d, set) => AlertDialog(
            title: Text(tr(context, "预算进度提醒")),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kind == BudgetNoticeKind.zero
                        ? tr(context, "本月预算设为0，按已记录账目已支出 {0}。", [
                            current.spent.yuan,
                          ])
                        : tr(
                            context,
                            "按已记录账目，本月预算已用 {0}，还剩 {1}。最近使用得稍快，可以看看接下来的安排。",
                            [current.spent.yuan, current.remaining!.yuan],
                          ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr(context, "本月不再提醒")),
                    value: mute,
                    onChanged: (v) => set(() => mute = v ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(tr(context, "知道了")),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(tr(context, "看看预算")),
              ),
            ],
          ),
        ),
      );
      if (mute) await port.muteBudgetMonth(month);
      if (view == true && context.mounted) {
        await _categoryBudgets(context, fresh);
      }
    } catch (error) {
      final promptContext = _promptContext;
      if (mounted &&
          promptContext != null &&
          promptContext.mounted &&
          _promptReady) {
        _sessionPromptUsed = true;
        _message(promptContext, tr(promptContext, "暂时无法读取提醒或报告，可进入报告页重试。"));
      }
    } finally {
      _promptChecking = false;
    }
  }
}
