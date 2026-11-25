import '../../../contracts/contracts.dart';
import '../../statistics/domain/report_arithmetic.dart';

/// Protect text cells that spreadsheet software could interpret as formulas.
String _text(String value) {
  if (RegExp(r'^(?:[\t\r\n]|[\s\uFEFF]*[=+\-@])').hasMatch(value)) {
    return "'$value";
  }
  return value;
}

String _cell(Object value) {
  final text = value.toString();
  return RegExp(r'[",\r\n]').hasMatch(text)
      ? '"${text.replaceAll('"', '""')}"'
      : text;
}

String _csv(Iterable<List<Object>> rows) =>
    '\uFEFF${rows.map((row) => row.map(_cell).join(',')).join('\r\n')}\r\n';

final class CsvReportExporter {
  const CsvReportExporter();

  String entries(LedgerRangeData data) {
    final catalog = {
      for (final category in data.categories) category.id: category,
    };
    final records = data.entries.toList()
      ..sort((a, b) {
        final instant = b.occurredAtUtcMs.compareTo(a.occurredAtUtcMs);
        return instant == 0 ? a.id.compareTo(b.id) : instant;
      });
    return _csv([
      [
        '日期',
        '发生时间(UTC)',
        '类型',
        '一级分类',
        '二级分类',
        '分类ID',
        '金额(元)',
        '金额(分)',
        '备注',
        '记录ID',
      ],
      for (final entry in records) _record(entry, catalog),
    ]);
  }

  List<Object> _record(LedgerEntry entry, Map<String, Category> catalog) {
    final category = catalog[entry.categoryId];
    final parent = category?.parentId;
    final root = parent == null ? category?.name : catalog[parent]?.name;
    return [
      entry.localDate,
      DateTime.fromMillisecondsSinceEpoch(
        entry.occurredAtUtcMs,
        isUtc: true,
      ).toIso8601String(),
      entry.kind == EntryKind.expense ? '支出' : '收入',
      _text(root ?? entry.categoryId),
      parent == null ? '' : _text(category!.name),
      _text(entry.categoryId),
      entry.amount.decimal,
      entry.amount.fen,
      _text(entry.note),
      _text(entry.id),
    ];
  }

  String summary(WeeklyReport report) {
    List<Object> row(
      String group,
      String key,
      Money amount, [
      String percent = '',
    ]) => [group, _text(key), amount.decimal, amount.fen, percent];

    return _csv([
      ['区块', '键', '金额(元)', '金额(分)', '占比'],
      row('总览', '支出', report.expense),
      row('总览', '收入', report.income),
      row('总览', '净收支', report.net),
      row('总览', '日均支出', report.averageDailyExpense),
      for (final day in report.daily) ...[
        row('逐日支出', day.localDate, day.expense),
        row('逐日收入', day.localDate, day.income),
      ],
      for (final category in report.categories)
        row(
          '支出分类',
          category.name,
          category.amount,
          reportPercent(category.amount.fen, report.expense.fen) ?? '',
        ),
    ]);
  }
}
