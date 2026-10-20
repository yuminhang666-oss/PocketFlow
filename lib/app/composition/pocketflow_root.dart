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
import '../../features/ledger_list/presentation/ledger_calendar_page.dart';
import '../../features/settings/presentation/budget_editor_sheet.dart';
import '../../features/settings/presentation/categories_page.dart';
import '../../features/settings/presentation/planning_pages.dart';
import '../../features/settings/presentation/settings_page.dart';
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
  CalendarMonth? _selectedMonth;
  Timer? _midnight;
  bool _fileBusy = false;
  late final AppUpdateController _updates;
  late final _PromptNavigatorObserver _promptObserver;
  BuildContext? _promptContext;
  bool _sessionPromptUsed = false,
      _promptChecking = false,
      _promptScheduled = false;
  int _tab = 0;
  int? _lastExport;
  bool _foreground = true;

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
      _selectedMonth ?? CalendarMonth.fromDate(ref.read(clockProvider).now());

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
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _chooseMonth(BuildContext context) async {
    final selected = await showMonthPicker(context, _month);
    if (selected != null && mounted) {
      setState(() {
        _selectedMonth =
            selected == CalendarMonth.fromDate(ref.read(clockProvider).now())
            ? null
            : selected;
      });
    }
  }

  Future<void> _budget(BuildContext context, LedgerMonthData? data) async {
    final month = _month;
    final saved = await showBudgetEditor(
      context,
      month: month,
      initialBudget: data?.budget?.amount,
      onSave: (amount) =>
          ref.read(ledgerRepositoryProvider).saveBudget(month, amount),
    );
    if (saved == true && context.mounted) _message(context, '预算已保存');
  }

  Future<void> _edit(
    BuildContext context,
    LedgerMonthData data, {
    LedgerEntry? initial,
    EntryTemplate? template,
    String? localDate,
  }) async {
    final now = ref.read(clockProvider).now();
    if (initial == null &&
        data.month.compareTo(CalendarMonth.fromDate(now)) > 0) {
      return;
    }
    final repository = ref.read(ledgerRepositoryProvider);
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
              initialDate:
                  localDate ??
                  (data.month == CalendarMonth.fromDate(now)
                      ? calendarDayKey(now)
                      : calendarDayKey(
                          DateTime.utc(
                            data.month.year,
                            data.month.month,
                            data.month.days,
                          ),
                        )),
              onSave: (draft) => initial == null
                  ? repository.createExpense(draft)
                  : repository.updateExpense(initial.id, draft),
              onSaveIncome: (draft) => initial == null
                  ? repository.createIncome(draft)
                  : repository.updateIncome(initial.id, draft),
              onAddRecommended: repository.addRecommendedCategories,
              onSaveTemplate: repository.saveTemplate,
            );
          },
        ),
      ),
    );
    if (entry != null && context.mounted) {
      final port = ref.read(planningPortProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            '${initial == null ? '已保存' : '已更新'} ${entry.amount.yuan} · ${data.categories.where((c) => c.id == entry.categoryId).firstOrNull?.name ?? entry.categoryId} · ${entry.localDate}',
          ),
          action:
              initial != null ||
                  port == null ||
                  ref.read(clockProvider).now().millisecondsSinceEpoch -
                          entry.createdAtUtcMs >
                      5000
              ? null
              : SnackBarAction(
                  label: '撤销',
                  onPressed: () async {
                    try {
                      await port.undoCreate(entry);
                    } catch (e) {
                      if (context.mounted) {
                        _message(context, presentationError(e));
                      }
                    }
                  },
                ),
        ),
      );
    }
  }

  Future<void> _details(
    BuildContext context,
    LedgerMonthData data,
    LedgerEntry entry,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (detailContext) => EntryDetailsPage(
        entry: entry,
        categories: data.categories,
        onEdit: () {
          Navigator.pop(detailContext);
          _edit(context, data, initial: entry);
        },
        onDelete: () => _delete(detailContext, entry),
      ),
    ),
  );

  Future<void> _delete(BuildContext context, LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('删除这笔账单？'),
        content: Text(
          '${entry.amount.yuan} · ${entry.localDate}\n删除后将重新计算统计。如来自周期待办，该期会改为已跳过，不会自动重新入账。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(ledgerRepositoryProvider).deleteEntry(entry.id);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) _message(context, presentationError(error));
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
            appBar: AppBar(title: const Text('账本')),
            body: StatusPanel(
              title: '无法读取账本',
              message: presentationError(error),
              actionLabel: '重试',
              onAction: () => ref.invalidate(monthDataProvider(month)),
            ),
          ),
        ),
  );

  Widget _ledgerPage(
    BuildContext context,
    LedgerMonthData data, {
    String? date,
    String? categoryId,
    EntryKind? kind,
    bool monthPicker = false,
  }) => LedgerListPage(
    data: data,
    query: const DefaultLedgerQueryService(),
    asOfLocalDate: calendarDayKey(ref.read(clockProvider).now()),
    initialDate: date,
    initialCategoryId: categoryId,
    initialKind: kind,
    onChooseMonth: monthPicker ? () => _chooseMonth(context) : null,
    onEntryTap: (entry) => _details(context, data, entry),
  );

  Future<void> _ledger(
    BuildContext context,
    CalendarMonth month, {
    String? date,
    String? categoryId,
    EntryKind? kind,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _dataPage(
        month,
        (route, data) => _ledgerPage(
          route,
          data,
          date: date,
          categoryId: categoryId,
          kind: kind,
        ),
      ),
    ),
  );

  Future<void> _calendar(BuildContext context, CalendarMonth month) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _dataPage(month, (route, data) {
            final today = calendarDayKey(ref.read(clockProvider).now());
            return LedgerCalendarPage(
              data: data,
              today: today,
              view: const DefaultLedgerQueryService().filter(
                data,
                const LedgerFilter(),
                asOfLocalDate: today,
              ),
              onOpenDay: (date) => _ledger(route, month, date: date),
              onAddDay: (date) => _edit(route, data, localDate: date),
              onMarkZero: ref.read(ledgerRepositoryProvider).markZeroExpenseDay,
            );
          }),
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
    bool? feedback,
  }) async {
    try {
      await ref
          .read(ledgerRepositoryProvider)
          .savePreferences(theme: theme?.name, feedback: feedback);
    } catch (error) {
      if (context.mounted) _message(context, presentationError(error));
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
              title: Text('$title · 保存文件'),
              leading: const Icon(Icons.save_alt),
              onTap: () => Navigator.pop(sheet, false),
            ),
            ListTile(
              title: Text('$title · 系统分享'),
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
      if (context.mounted) _message(context, presentationError(error));
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _export(BuildContext context, LedgerMonthData data) =>
      _files(context, () async {
        final share = await _fileAction(context, 'Markdown 月报');
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
          _message(context, share ? '已打开系统分享' : '月报已保存');
        }
      });

  Future<void> _backup(BuildContext context) => _files(context, () async {
    final share = await _fileAction(context, 'JSON 完整备份');
    if (share == null) return;
    final service = ref.read(backupTransferProvider);
    final done = share ? await service.share() : await service.save();
    if (done && context.mounted) _message(context, share ? '已打开系统分享' : '备份已保存');
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
                    title: const Text('恢复并替换现有账本？'),
                    content: Text(
                      '备份包含 ${document.entries.length} 笔记录、'
                      '${document.budgets.length} 个月预算、${document.categories.length} 个分类。\n\n'
                      '将完整替换现有账本、目标、模板和偏好设置。旧版备份不含的新设置会恢复默认。恢复前会保留本地恢复点。'
                      '${document.entries.isEmpty ? '\n此备份没有账单，恢复后账单将为空。' : ''}'
                      '\n导出时间：${DateTime.fromMillisecondsSinceEpoch(document.exportedAtUtcMs)}\n来源格式 v${document.sourceFormatVersion} · ${document.plans.rules.length}条周期规则'
                      '${document.sourceFormatVersion < 3 ? '\n旧备份不含周期计划/分类预算，确认替换后将为空。' : ''}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('确认替换'),
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
          title: const Text('恢复完成'),
          content: SelectableText(
            '已恢复 ${result.entryCount} 笔账单。\n'
            '恢复前的本地恢复点：\n${result.recoveryBackupId}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('完成'),
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
    final today = ref.read(clockProvider).now();
    final themeMode = ThemeMode.values.byName(
      current?.profile.theme ?? 'system',
    );
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
                  onTabChanged: (index) {
                    _tab = index;
                    _schedulePrompt();
                  },
                  onAdd:
                      current == null ||
                          month.compareTo(CalendarMonth.fromDate(today)) > 0
                      ? null
                      : () => _edit(context, current),
                  ledger: state.when(
                    data: (data) =>
                        _ledgerPage(context, data, monthPicker: true),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => StatusPanel(
                      title: '无法读取账单',
                      message: presentationError(error),
                      actionLabel: '重试',
                      onAction: () => ref.invalidate(monthDataProvider(month)),
                    ),
                  ),
                  home: HomePage(
                    month: month,
                    state: pair,
                    report: report,
                    todayKey: calendarDayKey(today),
                    onCalendar: () => _calendar(context, month),
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
                    onOpenLedger: () => _ledger(context, month),
                    onOpenDate: (date) => _ledger(context, month, date: date),
                    onReports: () => _reports(context),
                    onPlans: current == null
                        ? null
                        : () => _recurring(context, current),
                    onEntryTap: current == null
                        ? null
                        : (entry) => _details(context, current, entry),
                    onChooseMonth: () => _chooseMonth(context),
                    onRefresh: () async {
                      ref.invalidate(monthDataProvider(month));
                    },
                  ),
                  statistics: StatisticsPage(
                    onReports: () => _reports(context),
                    month: month,
                    state: state,
                    clock: ref.read(clockProvider),
                    onOpenCategory: (id, kind) =>
                        _ledger(context, month, categoryId: id, kind: kind),
                    onOpenDate: (date, kind) =>
                        _ledger(context, month, date: date, kind: kind),
                    onChooseMonth: () => _chooseMonth(context),
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
                    onThemeChanged: (theme) =>
                        _preferences(context, theme: theme),
                    feedback: current?.profile.feedback ?? true,
                    onFeedbackChanged: (value) =>
                        _preferences(context, feedback: value),
                    onCalendar: () => _calendar(context, month),
                    onGoals: () => _goals(context),
                    onCategories: () => _categories(context),
                    onTemplates: () => _templates(context),
                    onBudget: current == null
                        ? null
                        : () => _categoryBudgets(context, current),
                    onHistory: () => _ledger(context, month),
                    onExport:
                        current == null ||
                            month.compareTo(CalendarMonth.fromDate(today)) > 0
                        ? null
                        : () => _export(context, current),
                    onBackup: () => _backup(context),
                    onRestore: () => _restore(context),
                    onAbout: () => showAboutDialog(
                      context: context,
                      applicationName: 'PocketFlow',
                      applicationVersion:
                          '${_updates.installed?.versionName ?? '0.3.0'} · 个人测试版',
                      children: [
                        const Text('离线管理生活费。Markdown 用于分析，JSON 用于完整备份。'),
                      ],
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

  Future<void> _reports(
    BuildContext context, {
    String? start,
    String? end,
  }) async {
    final port = ref.read(planningPortProvider);
    if (port == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReportsPage(
          port: port,
          clock: ref.read(clockProvider),
          initialStart: start,
          initialEnd: end,
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _dataPage(
          data.month,
          (route, live) => CategoryBudgetsPage(
            data: live,
            port: port,
            today: ref.read(clockProvider).now(),
            onTotalBudget: () => _budget(route, live),
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
              title: const Text('上周收支回顾已准备好'),
              content: Text(
                '${range.$1} — ${range.$2}\n支出 ${report.expense.yuan} · 收入 ${report.income.yuan}\n${report.categories.isEmpty ? '暂无支出记录' : '最高支出分类：${report.categories.first.name} ${report.categories.first.amount.yuan}'}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('稍后再看'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('查看周报'),
                ),
              ],
            ),
          );
          if (view == true && context.mounted) {
            await _reports(context, start: range.$1, end: range.$2);
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
            title: const Text('预算进度提醒'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kind == BudgetNoticeKind.zero
                        ? '本月预算设为0，按已记录账目已支出 ${current.spent.yuan}。'
                        : '按已记录账目，本月预算已用 ${current.spent.yuan}，还剩 ${current.remaining!.yuan}。最近使用得稍快，可以看看接下来的安排。',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('本月不再提醒'),
                    value: mute,
                    onChanged: (v) => set(() => mute = v ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('知道了'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('看看预算'),
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
      if (_promptReady) {
        _sessionPromptUsed = true;
        _message(_promptContext!, '暂时无法读取提醒或报告，可进入报告页重试。');
      }
    } finally {
      _promptChecking = false;
    }
  }
}
