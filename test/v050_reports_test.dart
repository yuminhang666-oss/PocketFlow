import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/features/export/application/report_export_service.dart';
import 'package:pocketflow/features/export/domain/csv_exporter.dart';
import 'package:pocketflow/features/export/domain/markdown_exporter.dart';
import 'package:pocketflow/features/reports/domain/range_report_service.dart';
import 'package:pocketflow/features/reports/domain/range_trend.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';

final now = DateTime(2026, 11, 25);
final categories = [
  Category(id: 'food', name: '餐饮', sortOrder: 0),
  Category(id: 'breakfast', name: '早餐', parentId: 'food', sortOrder: 1),
  Category(id: 'lunch', name: '午餐', parentId: 'food', sortOrder: 2),
  Category(id: 'travel', name: '交通', sortOrder: 3),
  Category(id: 'drinks', name: '饮品', sortOrder: 4),
  Category(id: 'other', name: '其他', sortOrder: 5),
  Category(id: 'work', name: '兼职', sortOrder: 6),
];

LedgerEntry entry(
  String id,
  String localDate,
  String category,
  int fen, {
  EntryKind kind = EntryKind.expense,
  String note = '',
}) => LedgerEntry(
  id: id,
  amount: Money.fromFen(fen),
  localDate: localDate,
  categoryId: category,
  kind: kind,
  note: note,
  occurredAtUtcMs: parseCalendarDay(localDate).millisecondsSinceEpoch,
  createdAtUtcMs: 0,
  updatedAtUtcMs: 0,
);

final fixture = [
  entry('e01', '2026-10-31', 'breakfast', 1250, note: '豆浆,包子'),
  entry('e02', '2026-10-31', 'travel', 600),
  entry('i01', '2026-11-01', 'work', 60000, kind: EntryKind.income),
  entry('e03', '2026-11-01', 'lunch', 2000, note: '=SUM(A1:A2)'),
  entry('e04', '2026-11-01', 'drinks', 950, note: '一行"\r\n二行'),
  entry('e05', '2026-11-02', 'other', 1),
];

LedgerRangeData snapshot(Iterable<LedgerEntry> entries) => LedgerRangeData(
  start: '2026-10-31',
  end: '2026-11-02',
  entries: entries,
  categories: categories,
  revision: 'fixture-revision',
);

class _Files implements FileTransferPort {
  ReportFile? saved;
  ReportFile? shared;
  @override
  Future<bool> saveText({
    required String suggestedName,
    required String mimeType,
    required String content,
  }) async {
    saved = (name: suggestedName, mime: mimeType, content: content);
    return true;
  }

  @override
  Future<bool> shareTextFile({
    required String suggestedName,
    required String mimeType,
    required String content,
  }) async {
    shared = (name: suggestedName, mime: mimeType, content: content);
    return true;
  }

  @override
  Future<SelectedTextFile?> pickJsonText() async => null;
}

void main() {
  test(
    'inclusive custom ranges respect local dates, leap day and the maximum',
    () {
      expect(ReportDateRange('2024-01-01', '2024-12-31', now: now).days, 366);
      expect(ReportDateRange('2024-02-29', '2024-02-29', now: now).days, 1);
      expect(ReportDateRange('2025-12-31', '2026-01-01', now: now).days, 2);
      expect(ReportDateRange.recent(30, now: now).startKey, '2026-10-27');
      expect(ReportDateRange.recent(90, now: now).days, 90);
      expect(
        () => ReportDateRange('2024-01-01', '2025-01-01', now: now),
        throwsFormatException,
      );
      expect(
        () => ReportDateRange('2026-11-26', '2026-11-26', now: now),
        throwsFormatException,
      );
      expect(
        () => ReportDateRange('2026-11-25', '2026-11-24', now: now),
        throwsFormatException,
      );
    },
  );

  test('cross-month aggregation and all trend scales agree in integer fen', () {
    final report = const RangeReportService().build(
      snapshot(fixture),
      now: now,
    );
    expect(
      (
        report.expense.fen,
        report.income.fen,
        report.net.fen,
        report.averageDailyExpense.fen,
      ),
      (4801, 60000, 55199, 1600),
    );
    expect(report.daily.map((day) => day.expense.fen), [1850, 2950, 1]);
    expect(
      report.categories
          .firstWhere((category) => category.categoryId == 'food')
          .amount
          .fen,
      3250,
    );
    for (final scale in RangeTrendScale.values) {
      final buckets = groupRangeTrend(report.daily, scale);
      expect(buckets.fold<int>(0, (sum, b) => sum + b.expense.fen), 4801);
      expect(buckets.fold<int>(0, (sum, b) => sum + b.income.fen), 60000);
      expect(
        (buckets.first.start, buckets.last.end),
        ('2026-10-31', '2026-11-02'),
      );
    }
    expect(
      groupRangeTrend(
        report.daily,
        RangeTrendScale.month,
      ).map((b) => b.expense.fen),
      [1850, 2951],
    );
  });

  test(
    'preview snapshot stays fixed across ledger changes and both transfers',
    () async {
      final live = fixture.toList();
      final report = const RangeReportService().build(snapshot(live), now: now);
      live.clear();
      final files = _Files();
      final service = ReportExportService(
        files: files,
        markdown: const DefaultMarkdownExporter(),
      );
      final csv = service.render(report, ReportFileFormat.entriesCsv);
      await service.transfer(csv);
      await service.transfer(csv, share: true);
      expect(files.saved, files.shared);
      expect(files.saved?.mime, 'text/csv');
      expect(
        files.saved?.name,
        'pocketflow-2026-10-31_to_2026-11-02-entries.csv',
      );
      expect(
        csv.content,
        startsWith(
          '\uFEFF日期,发生时间(UTC),类型,一级分类,二级分类,分类ID,金额(元),金额(分),备注,记录ID\r\n',
        ),
      );
      expect(csv.content, contains('12.50,1250,"豆浆,包子",e01\r\n'));
      expect(csv.content, contains('20.00,2000,\'=SUM(A1:A2),e03\r\n'));
      expect(csv.content, contains('9.50,950,"一行""\r\n二行",e04\r\n'));
      expect(report.data.entries.length, 6);
      expect(report.data.entries[3].note, '=SUM(A1:A2)');
      expect(
        service.render(report, ReportFileFormat.summaryCsv).content,
        contains('总览,支出,48.01,4801,\r\n'),
      );
      final md = service.render(report, ReportFileFormat.markdown);
      expect(md.content, contains('2026-10-31 至 2026-11-02'));
      expect(md.content, contains('支出 48.01 · 收入 600.00 · 净收支 551.99'));
    },
  );

  test(
    'filtered CSV reuses the ledger filter results and child classifications',
    () {
      final month = CalendarMonth(2026, 11);
      final data = LedgerMonthData(
        month: month,
        budget: null,
        categories: categories,
        entries: fixture.where((e) => e.localDate.startsWith(month.key)),
      );
      final view = const DefaultLedgerQueryService().filter(
        data,
        const LedgerFilter(categoryId: 'food'),
        asOfLocalDate: '2026-11-25',
      );
      final filtered = LedgerRangeData(
        start: '2026-11-01',
        end: '2026-11-25',
        entries: view.entries,
        categories: data.categories,
        revision: 'filtered-fixture',
      );
      expect(view.expense.fen, 2000);
      final csv = const CsvReportExporter().entries(filtered);
      expect(csv, contains('餐饮,午餐,lunch,20.00,2000'));
      expect(csv, isNot(contains('兼职')));
    },
  );
}
