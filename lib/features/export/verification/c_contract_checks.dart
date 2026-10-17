// Standalone C checks, no test/ ownership or third-party test dependency.
// Run after Dart is provisioned:
// dart lib/features/export/verification/c_contract_checks.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../contracts/contracts.dart';
import '../../backup/application/backup_transfer_service.dart';
import '../../backup/domain/json_backup_codec.dart';
import '../../statistics/domain/monthly_chart_data.dart';
import '../../statistics/domain/monthly_report_service.dart';
import '../../statistics/domain/report_insights.dart';
import '../../statistics/domain/report_arithmetic.dart';
import '../application/report_export_service.dart';
import '../domain/markdown_exporter.dart';

final class FixedClock implements Clock {
  const FixedClock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}

void check(bool condition, String name) {
  if (!condition) throw StateError('FAILED: $name');
}

void rejects(void Function() action, PocketFlowErrorCode code) {
  try {
    action();
  } on PocketFlowException catch (error) {
    check(error.code == code, 'error code $code');
    return;
  }
  throw StateError('Expected rejection: $code');
}

Future<void> rejectsAsync(Future<void> Function() action,
    PocketFlowErrorCode code) async {
  try {
    await action();
  } on PocketFlowException catch (error) {
    check(error.code == code, 'async error code $code');
    return;
  }
  throw StateError('Expected async rejection: $code');
}

final class CheckFiles implements FileTransferPort {
  SelectedTextFile? selected;
  bool accepted = true;
  String? name;
  String? mime;
  String? text;
  @override
  Future<SelectedTextFile?> pickJsonText() async => selected;
  @override
  Future<bool> saveText({required String suggestedName, required String mimeType,
    required String content}) async {
    name = suggestedName;
    mime = mimeType;
    text = content;
    return accepted;
  }
  @override
  Future<bool> shareTextFile({required String suggestedName,
    required String mimeType, required String content}) => saveText(
      suggestedName: suggestedName, mimeType: mimeType, content: content);
}

final class CheckStore implements BackupStore {
  CheckStore(this.current);
  BackupDocument current;
  int writes = 0;
  bool fail = false;
  @override
  Future<BackupDocument> readAll() async => current;
  @override
  Future<RestoreResult> replaceAll(BackupDocument document) async {
    if (fail) throw const PocketFlowException(PocketFlowErrorCode.restoreFailed);
    writes++;
    current = document;
    return RestoreResult(entryCount: document.entries.length,
      budgetCount: document.budgets.length,
      categoryCount: document.categories.length, recoveryBackupId: 'check-recovery');
  }
}

Future<void> main(List<String> arguments) async {
  final clock = FixedClock(DateTime.utc(2026, 10, 17, 12));
  final service = DefaultMonthlyReportService(clock: clock);
  const codec = JsonBackupCodec();
  final month = CalendarMonth(2026, 10);
  final categories = [Category(id: 'food', name: '餐饮', sortOrder: 0),
    Category(id: 'study', name: '学习', sortOrder: 1, isArchived: true)];
  LedgerEntry entry(String id, int fen, String date,
      {String category = 'food', EntryKind kind = EntryKind.expense,
      String note = ''}) => LedgerEntry(id: id, amount: Money.fromFen(fen),
        localDate: date, categoryId: category, kind: kind, note: note,
        occurredAtUtcMs: parseCalendarDay(date).millisecondsSinceEpoch,
        createdAtUtcMs: 0, updatedAtUtcMs: 1);
  final records = [
    entry('a', 60000, '2026-10-01'),
    entry('b', 1800, '2026-10-17', category: 'study',
      note: '测试夹具 | \\ `备注`\n<script> [链接](https://example.com)'),
    entry('c', 20000, '2026-10-02', kind: EntryKind.income),
    entry('future', 9999, '2026-10-18'),
  ];
  LedgerMonthData data(Iterable<LedgerEntry> entries, {int? budget = 150000}) =>
      LedgerMonthData(month: month, budget: budget == null ? null :
        MonthlyBudget(month: month, amount: Money.fromFen(budget),
          updatedAtUtcMs: 1), entries: entries, categories: categories);
  final report = service.build(data(records), asOfLocalDate: '2026-10-17');
  check(report.totalExpense.fen == 61800 && report.remaining!.fen == 88200,
      'expense, income exclusion, cutoff, remaining');
  check(report.daily.length == 17 && report.daily[1].amount.fen == 0,
      'calendar zero filling');
  check(report.categoryTotals[1].amount.fen == 1800, 'archived category');
  check(report.daily.fold<int>(0, (s, d) => s + d.amount.fen) == 61800 &&
    report.categoryTotals.fold<int>(0, (s, c) => s + c.amount.fen) == 61800,
      'aggregation consistency');
  check(report.entries.length == 3 && report.expenseCount == 2 &&
    report.incomeCount == 1, 'complete cutoff transaction table');
  check(report.averageDailyExpense.fen == 3635 &&
    report.highestDailyExpense.fen == 60000 &&
    report.highestExpenseDays.single.localDate == '2026-10-01', 'metrics');
  check(report.budgetUsagePercent == '41.20%', 'budget ratio');
  check(sumReportFen([1, 2]) == 3 && reportPercent(1, 3) == '33.33%',
      'integer fen and rational rounding');
  rejects(() => checkedReportInt(BigInt.parse('9223372036854775808')),
      PocketFlowErrorCode.dataCorrupted);
  final points = monthlyChartData(report);
  check(points.length == 31 && points[16].remaining!.fen == 88200 &&
    points[17].expense == null && points[17].remaining == null &&
    points.last.referenceRemaining!.fen == 0 &&
    points[16].referenceRemaining!.fen == 67742, 'balance/reference chart');

  final empty = service.build(data([]), asOfLocalDate: '2026-10-17');
  check(empty.totalExpense.fen == 0 && empty.highestExpenseDays.isEmpty &&
    empty.categoryPercent(empty.categoryTotals.first) == null, 'empty report');
  check(service.build(data(records, budget: null), asOfLocalDate: '2026-10-17')
    .remaining == null, 'unset budget');
  final zero = service.build(data(records, budget: 0), asOfLocalDate: '2026-10-17');
  check(zero.remaining!.fen == -61800 && zero.budgetUsagePercent == null,
      'explicit zero budget');
  check(service.build(data(records, budget: 10000), asOfLocalDate: '2026-10-17')
    .budgetUsagePercent == '618.00%', 'unclipped over-budget ratio');
  check(service.build(data(records.where((e) => e.id != 'a')),
    asOfLocalDate: '2026-10-17').totalExpense.fen == 1800, 'deletion rebuild');
  check(service.defaultCutoff(CalendarMonth(2024, 2)) == '2024-02-29',
      'past month and leap year');
  for (final year in [1900, 2000, 2024]) {
    final february = CalendarMonth(year, 2);
    final historical = service.build(LedgerMonthData(month: february,
      budget: null, entries: [], categories: categories),
      asOfLocalDate: service.defaultCutoff(february));
    check(historical.daily.length == (year == 1900 ? 28 : 29),
        'February $year');
  }
  rejects(() => service.defaultCutoff(CalendarMonth(2026, 11)),
      PocketFlowErrorCode.invalidDate);
  rejects(() => service.build(data(records), asOfLocalDate: '2026-10-18'),
      PocketFlowErrorCode.invalidDate);
  rejects(() => service.build(data(records), asOfLocalDate: '2026-09-30'),
      PocketFlowErrorCode.invalidDate);
  rejects(() => service.build(data([records.first, records.first]),
    asOfLocalDate: '2026-10-17'), PocketFlowErrorCode.dataCorrupted);
  rejects(() => service.build(data([entry('bad', 100, '2026-10-01',
    category: 'missing')]), asOfLocalDate: '2026-10-17'),
    PocketFlowErrorCode.dataCorrupted);
  final tied = service.build(data([entry('z', 100, '2026-10-02'),
    entry('b', 100, '2026-10-01'), entry('a', 100, '2026-10-01'),
    entry('y', 100, '2026-10-02')]), asOfLocalDate: '2026-10-17');
  check(tied.highestExpenseDays.length == 2 && tied.entries[2].id == 'a',
      'ties and stable sorting');

  final exporter = DefaultMarkdownExporter(clock: clock);
  final markdown = exporter.render(report);
  check(markdown.contains('618.00') && markdown.contains('36.35') &&
    markdown.contains('&#124;') && markdown.contains('&lt;script&gt;') &&
    markdown.contains('<br>') && !markdown.contains('| future |'),
      'Markdown precision, cutoff and escaping');
  check(utf8.decode(utf8.encode(markdown)) == markdown, 'UTF-8 round trip');
  check(!DefaultMarkdownExporter(clock: clock, includeAiPrompt: false)
    .render(report).contains('## 可选 AI 分析提示词'), 'optional prompt');

  final backup = BackupDocument(exportedAtUtcMs: clock.now().millisecondsSinceEpoch,
    budgets: [data(records).budget!], categories: categories, entries: records);
  final encoded = codec.encode(backup);
  final decoded = codec.decode(encoded);
  check(codec.encode(decoded) == encoded && decoded.entries.length == 4 &&
    decoded.entries[1].note == records[1].note &&
    decoded.entries[2].kind == EntryKind.income, 'all fields backup round trip');
  final root = jsonDecode(encoded) as Map<String, dynamic>;
  String modified(void Function(Map<String, dynamic>) mutate) {
    final copy = jsonDecode(encoded) as Map<String, dynamic>;
    mutate(copy);
    return jsonEncode(copy);
  }
  for (final bad in <String>['{', '[]', 'null',
    modified((r) => r.remove('entries')),
    modified((r) => r['entries'] = null),
    modified((r) => r['currency'] = 'USD'),
    modified((r) => r['formatVersion'] = 1.0),
    modified((r) => (r['entries'] as List).add(r['entries'][0])),
    modified((r) => (r['categories'] as List).add(r['categories'][0])),
    modified((r) => (r['budgets'] as List).add(r['budgets'][0])),
    modified((r) => r['entries'][0]['categoryId'] = 'missing'),
    modified((r) => r['entries'][0]['localDate'] = '2026-02-30'),
    modified((r) => r['entries'][0]['amountFen'] = 0),
    modified((r) => r['entries'][0]['amountFen'] = 1.5),
    modified((r) => r['entries'][0]['amountFen'] = '60000'),
    modified((r) => r['entries'][0]['kind'] = 'refund'),
    modified((r) => r['entries'][0]['updatedAtUtcMs'] = -1),
    modified((r) => r['exportedAtUtcMs'] = 8640000000000001),
    modified((r) => r['categories'][0]['isArchived'] = 1),
  ]) {
    rejects(() => codec.decode(bad), PocketFlowErrorCode.invalidBackup);
  }
  rejects(() => codec.decode(modified((r) => r['formatVersion'] = 2)),
      PocketFlowErrorCode.unsupportedBackupVersion);
  check(codec.decode(modified((r) => r['extra'] = 'allowed')).entries.length == 4,
      'unknown extra fields');
  final emptyBackup = codec.decode(jsonEncode({...root,
    'budgets': [], 'categories': [], 'entries': []}));
  check(emptyBackup.entries.isEmpty, 'valid empty backup');

  final files = CheckFiles();
  final store = CheckStore(backup);
  final transfer = BackupTransferService(store: store, files: files,
    codec: codec, clock: clock);
  check(await transfer.restore(confirm: (_) async => true) == null &&
    store.writes == 0, 'picker cancelled, no writes');
  files.selected = SelectedTextFile(name: 'backup.json', content: encoded);
  check(await transfer.restore(confirm: (_) async => false) == null &&
    store.writes == 0, 'confirmation declined, no writes');
  files.selected = const SelectedTextFile(name: 'bad.json', content: '{}');
  await rejectsAsync(() async { await transfer.restore(confirm: (_) async => true); },
    PocketFlowErrorCode.invalidBackup);
  check(store.writes == 0, 'invalid backup never reaches store');
  files.selected = SelectedTextFile(name: 'backup.json', content: encoded);
  final restored = await transfer.restore(confirm: (document) async =>
    document.entries.length == 4);
  check(store.writes == 1 && restored!.recoveryBackupId == 'check-recovery',
      'one replace and recovery ID');
  store.fail = true;
  await rejectsAsync(() async { await transfer.restore(confirm: (_) async => true); },
    PocketFlowErrorCode.restoreFailed);
  check(store.writes == 1, 'store errors propagated without retry');
  store.fail = false;
  final gate = Completer<bool>();
  final preflightReady = Completer<void>();
  final pending = transfer.restore(confirm: (_) {
    preflightReady.complete();
    return gate.future;
  });
  await preflightReady.future;
  await rejectsAsync(() async { await transfer.restore(confirm: (_) async => true); },
    PocketFlowErrorCode.restoreFailed);
  gate.complete(false);
  check(await pending == null && store.writes == 1,
      'concurrent duplicate restore prevented');
  check(await transfer.save() && files.name!.endsWith('.json') &&
    files.mime == 'application/json', 'JSON export metadata');
  final reportTransfer = ReportExportService(files: files, markdown: exporter);
  files.accepted = false;
  check(!await reportTransfer.share(report) && files.name!.endsWith('.md') &&
    files.mime == 'text/markdown' && files.text == markdown,
      'Markdown export metadata and cancellation');

  // Examples are independent reference artifacts, not generated by unrun Dart.
  final expectedReport = File.fromUri(Platform.script.resolve(
      '../examples/fixture-report-2026-10.md'));
  final expectedBackup = File.fromUri(Platform.script.resolve(
      '../../backup/examples/fixture-backup-v1.json'));
  if (await expectedReport.exists() && await expectedBackup.exists()) {
    check(await expectedReport.readAsString(encoding: utf8) ==
      '> 虚构验证夹具，不是用户账单。\n\n$markdown', 'Markdown golden reference');
    check(await expectedBackup.readAsString(encoding: utf8) == encoded,
      'JSON golden reference');
  }

  if (arguments.length == 2 && arguments.first == '--write-examples') {
    final directory = Directory(arguments[1]);
    await directory.create(recursive: true);
    await File('${directory.path}/fixture-backup-v1.json')
      .writeAsString(encoded, encoding: utf8);
    await File('${directory.path}/fixture-report-2026-10.md')
      .writeAsString('> 虚构验证夹具，不是用户账单。\n\n$markdown', encoding: utf8);
  }
  stdout.writeln('C contract checks passed (Dart execution, not Android integration).');
}
