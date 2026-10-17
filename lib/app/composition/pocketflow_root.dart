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
import '../../features/settings/presentation/settings_page.dart';
import '../../features/statistics/domain/monthly_report_service.dart';
import '../../features/statistics/presentation/statistics_page.dart';
import '../../shared/widgets/presentation_errors.dart';
import '../../shared/widgets/status_panel.dart';
import '../pocketflow_app.dart';
import '../routing/pocketflow_shell.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => throw StateError('Production repository must be injected'),
);
final backupStoreProvider = Provider<BackupStore>(
  (ref) => throw StateError('Production backup store must be injected'),
);
final clockProvider = Provider<Clock>((ref) => const SystemClock());
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
  ThemeMode _themeMode = ThemeMode.system;
  Timer? _midnight;
  bool _fileBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  CalendarMonth get _month =>
      _selectedMonth ?? CalendarMonth.fromDate(ref.read(clockProvider).now());

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = ref.read(clockProvider).now();
    final next = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      if (mounted) {
        setState(() {});
        _scheduleMidnight();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      ref.invalidate(monthDataProvider(_month));
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _message(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 148),
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
    LedgerMonthData data, [
    LedgerEntry? initial,
  ]) async {
    final repository = ref.read(ledgerRepositoryProvider);
    final entry = await Navigator.of(context).push<LedgerEntry>(
      MaterialPageRoute(
        builder: (_) => QuickEntryPage(
          categories: data.categories,
          clock: ref.read(clockProvider),
          initialEntry: initial,
          onSave: (draft) => initial == null
              ? repository.createExpense(draft)
              : repository.updateExpense(initial.id, draft),
        ),
      ),
    );
    if (entry != null && context.mounted) {
      _message(context, initial == null ? '已保存支出' : '账单已更新');
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
        onEdit: entry.kind == EntryKind.expense
            ? () {
                Navigator.pop(detailContext);
                _edit(context, data, entry);
              }
            : null,
        onDelete: () => _delete(detailContext, entry),
      ),
    ),
  );

  Future<void> _delete(BuildContext context, LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('删除这笔账单？'),
        content: Text('${entry.amount.yuan} · ${entry.localDate}\n删除后将重新计算预算。'),
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

  Future<void> _ledger(BuildContext context, CalendarMonth month) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Consumer(
            builder: (routeContext, ref, _) => ref
                .watch(monthDataProvider(month))
                .when(
                  data: (data) => LedgerListPage(
                    data: data,
                    onEntryTap: (entry) => _details(routeContext, data, entry),
                  ),
                  loading: () => const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Scaffold(
                    appBar: AppBar(title: const Text('账单')),
                    body: StatusPanel(
                      title: '无法读取账单',
                      message: presentationError(error),
                      actionLabel: '重试',
                      onAction: () => ref.invalidate(monthDataProvider(month)),
                    ),
                  ),
                ),
          ),
        ),
      );

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
                      '将完整替换手机现有数据，不是合并。恢复前会保留本地恢复点。'
                      '${document.entries.isEmpty ? '\n此备份没有账单，恢复后账单将为空。' : ''}',
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
      themeMode: _themeMode,
      home: Builder(
        builder: (context) => PopScope(
          canPop: !_fileBusy,
          child: Stack(
            children: [
              PocketFlowShell(
                home: HomePage(
                  month: month,
                  state: pair,
                  onAddExpense: current == null
                      ? null
                      : () => _edit(context, current),
                  onSetBudget: () => _budget(context, current),
                  onOpenLedger: () => _ledger(context, month),
                  onEntryTap: current == null
                      ? null
                      : (entry) => _details(context, current, entry),
                  onChooseMonth: () => _chooseMonth(context),
                  onRefresh: () async {
                    ref.invalidate(monthDataProvider(month));
                  },
                ),
                statistics: StatisticsPage(
                  month: month,
                  state: state,
                  clock: ref.read(clockProvider),
                  onChooseMonth: () => _chooseMonth(context),
                ),
                settings: SettingsPage(
                  themeMode: _themeMode,
                  onThemeChanged: (theme) => setState(() => _themeMode = theme),
                  onBudget: () => _budget(context, current),
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
                    applicationVersion: '0.1.1 · 个人测试版',
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
                      child: Center(child: Icon(Icons.hourglass_top, size: 40)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
